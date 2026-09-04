import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cart.dart';
import 'main.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final cart = CartService();
  late Razorpay _razorpay;
  bool _isProcessing = false;

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();
  final TextEditingController _cityCtrl = TextEditingController();
  final TextEditingController _pinCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    final user = supabase.auth.currentUser;
    if (user != null) {
      _emailCtrl.text = user.email ?? '';
      _loadPreviousAddress();
    }
  }

  Future<void> _loadPreviousAddress() async {
    final user = supabase.auth.currentUser;
    if (user == null || user.email == null) return;
    try {
      final res = await supabase
          .from('orders')
          .select()
          .eq('customer_email', user.email!)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (res != null && mounted) {
        setState(() {
          if (_nameCtrl.text.isEmpty) _nameCtrl.text = res['customer_name'] ?? '';
          if (_phoneCtrl.text.isEmpty) _phoneCtrl.text = res['customer_phone'] ?? '';
          if (res['shipping_address'] != null) {
            final addr = res['shipping_address'];
            if (_addressCtrl.text.isEmpty) _addressCtrl.text = addr['address'] ?? '';
            if (_cityCtrl.text.isEmpty) _cityCtrl.text = addr['city'] ?? '';
            if (_pinCtrl.text.isEmpty) _pinCtrl.text = addr['pincode'] ?? '';
          }
        });
      }
    } catch (e) {
      debugPrint("Could not load previous address: $e");
    }
  }

  @override
  void dispose() {
    _razorpay.clear();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      // 1. Insert into orders table
      final orderRes = await supabase.from('orders').insert({
        'customer_name': _nameCtrl.text,
        'customer_email': _emailCtrl.text,
        'customer_phone': _phoneCtrl.text,
        'shipping_address': {
          'address': _addressCtrl.text,
          'city': _cityCtrl.text,
          'pincode': _pinCtrl.text,
        },
        'total_amount': cart.totalAmount,
        'status': 'paid',
        'payment_id': response.paymentId
      }).select().single();

      final orderId = orderRes['id'];

      // 2. Insert order items and update stock
      for (var item in cart.items) {
        await supabase.from('order_items').insert({
          'order_id': orderId,
          'product_id': item.product['id'],
          'quantity': item.quantity,
          'price': item.product['price']
        });

        // Update stock
        final currentStock = (item.product['stock'] as num?)?.toInt() ?? 0;
        final newStock = (currentStock - item.quantity) > 0 ? (currentStock - item.quantity) : 0;
        await supabase.from('products').update({'stock': newStock}).eq('id', item.product['id']);
      }

      // 3. Clear Cart
      cart.clearCart();
      try {
        await flutterLocalNotificationsPlugin.cancel(id: 1001); // Cancel abandoned cart reminder
      } catch (e) {
        debugPrint("Failed to cancel cart reminder: $e");
      }

      if (!mounted) return;
      setState(() => _isProcessing = false);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Order Successful! 🎉', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text(
            'Your order #${orderId.toString().substring(0, 8).toUpperCase()} has been placed successfully. You can track it in the Orders tab.',
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context); // Go back to cart/home
              },
              child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            )
          ],
        )
      );
    } catch (e) {
      setState(() => _isProcessing = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving order: $e')));
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    setState(() => _isProcessing = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment Failed: ${response.message}')));
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    setState(() => _isProcessing = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('External Wallet Selected: ${response.walletName}')));
  }

  Future<void> _startPayment() async {
    if (_nameCtrl.text.isEmpty || _emailCtrl.text.isEmpty || _phoneCtrl.text.isEmpty || _addressCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // 1. Create order on backend (Next.js server)
      final baseUrl = const bool.fromEnvironment('dart.vm.product') 
          ? 'https://svaneya.in/api/razorpay'
          : 'http://10.0.2.2:3000/api/razorpay';
          
      final res = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'amount': cart.totalAmount,
          'currency': 'INR'
        }),
      );

      if (res.statusCode != 200) {
        throw Exception('Failed to create order on server');
      }

      final data = jsonDecode(res.body);
      final rzpOrderId = data['id'];

      // 2. Open Razorpay
      var options = {
        'key': 'rzp_test_TTLcyDKmgd1p8C', // Same as NEXT_PUBLIC_RAZORPAY_KEY_ID
        'amount': (cart.totalAmount * 100).toInt(),
        'name': 'Svaneya Store',
        'description': 'Order Payment',
        'order_id': rzpOrderId,
        'prefill': {
          'contact': _phoneCtrl.text,
          'email': _emailCtrl.text
        }
      };

      _razorpay.open(options);
    } catch (e) {
      setState(() => _isProcessing = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error starting payment: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('CHECKOUT', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Contact Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: "Full Name", border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: "Email", border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Phone Number", border: OutlineInputBorder())),
            const SizedBox(height: 32),
            const Text("Shipping Address", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(controller: _addressCtrl, decoration: const InputDecoration(labelText: "Address", border: OutlineInputBorder())),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: TextField(controller: _cityCtrl, decoration: const InputDecoration(labelText: "City", border: OutlineInputBorder()))),
                const SizedBox(width: 16),
                Expanded(child: TextField(controller: _pinCtrl, decoration: const InputDecoration(labelText: "PIN Code", border: OutlineInputBorder()))),
              ],
            ),
            const SizedBox(height: 32),
            const Text("Order Summary", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Total Amount", style: TextStyle(fontSize: 16)),
                Text("₹${cart.totalAmount}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _startPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isProcessing
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("PAY NOW", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
