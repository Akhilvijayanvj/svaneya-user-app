import 'package:flutter/material.dart';
import 'main.dart'; // contains supabase instance

class OrderDetailScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const OrderDetailScreen({super.key, required this.order});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Map<String, dynamic> _currentOrder;
  List<dynamic> _orderItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
    _fetchOrderItems();
  }

  Future<void> _fetchOrderItems() async {
    try {
      // Join order_items with products
      final data = await supabase
          .from('order_items')
          .select('*, products(*)')
          .eq('order_id', _currentOrder['id']);
          
      if (mounted) {
        setState(() {
          _orderItems = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to load order items: $e")));
      }
    }
  }

  Future<void> _cancelOrder() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cancel Order"),
        content: const Text("Are you sure you want to cancel this order? This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("No")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text("Yes, Cancel", style: TextStyle(color: Colors.red))
          ),
        ],
      )
    );

    if (confirm != true) return;

    try {
      await supabase.from('orders').update({'status': 'cancelled'}).eq('id', _currentOrder['id']);
      if (mounted) {
        setState(() {
          _currentOrder['status'] = 'cancelled';
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Order cancelled successfully.")));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to cancel order: $e")));
    }
  }

  Future<void> _editAddress() async {
    final addressObj = _currentOrder['shipping_address'] ?? {};
    final addressCtrl = TextEditingController(text: addressObj['address'] ?? '');
    final cityCtrl = TextEditingController(text: addressObj['city'] ?? '');
    final pinCtrl = TextEditingController(text: addressObj['pincode'] ?? '');

    final Map<String, String>? result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Shipping Address"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: "Address")),
            TextField(controller: cityCtrl, decoration: const InputDecoration(labelText: "City")),
            TextField(controller: pinCtrl, decoration: const InputDecoration(labelText: "PIN Code")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx, {
                'address': addressCtrl.text,
                'city': cityCtrl.text,
                'pincode': pinCtrl.text,
              });
            }, 
            child: const Text("Save")
          ),
        ],
      )
    );

    if (result == null) return;

    try {
      await supabase.from('orders').update({'shipping_address': result}).eq('id', _currentOrder['id']);
      if (mounted) {
        setState(() {
          _currentOrder['shipping_address'] = result;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Address updated successfully.")));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to update address: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderId = (_currentOrder['id'] as String).substring(0, 8).toUpperCase();
    final status = (_currentOrder['status'] as String).toLowerCase();
    
    // Only allow edit/cancel if order is 'paid' (or basically not shipped/delivered/cancelled)
    final bool canModify = status == 'paid' || status == 'pending';

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('ORDER DETAILS', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Order #$orderId", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: status == 'delivered' ? Colors.green.shade50 : (status == 'cancelled' ? Colors.red.shade50 : Colors.orange.shade50),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            color: status == 'delivered' ? Colors.green.shade700 : (status == 'cancelled' ? Colors.red.shade700 : Colors.orange.shade700),
                            fontWeight: FontWeight.bold,
                            fontSize: 12
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text("Placed on: ${DateTime.parse(_currentOrder['created_at']).toLocal().toString().split('.')[0]}", style: TextStyle(color: Colors.grey.shade600)),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Total Amount", style: TextStyle(fontSize: 16, color: Colors.grey)),
                      Text("₹${_currentOrder['total_amount']}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Shipping Address
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Shipping Address", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      if (canModify)
                        TextButton(
                          onPressed: _editAddress, 
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                          child: const Text("Edit", style: TextStyle(fontWeight: FontWeight.bold))
                        )
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(_currentOrder['customer_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  if (_currentOrder['shipping_address'] != null) ...[
                    Text(_currentOrder['shipping_address']['address'] ?? '', style: TextStyle(color: Colors.grey.shade700)),
                    Text("${_currentOrder['shipping_address']['city'] ?? ''} - ${_currentOrder['shipping_address']['pincode'] ?? ''}", style: TextStyle(color: Colors.grey.shade700)),
                  ],
                  const SizedBox(height: 4),
                  Text("Phone: ${_currentOrder['customer_phone'] ?? ''}", style: TextStyle(color: Colors.grey.shade700)),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Items
            const Text("Order Items", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              ..._orderItems.map((item) {
                final product = item['products'] ?? {};
                final images = product['images'] as List<dynamic>? ?? [];
                final imageUrl = images.isNotEmpty ? images[0] : null;
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                        clipBehavior: Clip.antiAlias,
                        child: imageUrl != null ? Image.network(imageUrl, fit: BoxFit.cover) : const Icon(Icons.image, color: Colors.grey),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(product['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Text("Qty: ${item['quantity']}", style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                          ],
                        ),
                      ),
                      Text("₹${item['price']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                );
              }).toList(),
              
            const SizedBox(height: 32),
            
            // Actions
            if (canModify)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: _cancelOrder,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("CANCEL ORDER", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
