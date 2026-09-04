import 'package:flutter/material.dart';
import 'checkout.dart';


import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// Very simple global cart state for demonstration
class CartItem {
  final Map<String, dynamic> product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});

  Map<String, dynamic> toJson() => {
    'product': product,
    'quantity': quantity
  };

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      product: json['product'],
      quantity: json['quantity']
    );
  }
}

class CartService extends ChangeNotifier {
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  
  CartService._internal() {
    _loadCart();
  }

  final List<CartItem> _items = [];
  List<CartItem> get items => _items;

  double get totalAmount {
    return _items.fold(0, (total, item) => total + (item.product['price'] * item.quantity));
  }

  Future<void> _loadCart() async {
    final prefs = await SharedPreferences.getInstance();
    final cartStr = prefs.getString('cart_items');
    if (cartStr != null) {
      final List<dynamic> decoded = jsonDecode(cartStr);
      _items.clear();
      _items.addAll(decoded.map((e) => CartItem.fromJson(e)).toList());
      notifyListeners();
    }
  }

  Future<void> _saveCart() async {
    final prefs = await SharedPreferences.getInstance();
    final cartStr = jsonEncode(_items.map((e) => e.toJson()).toList());
    await prefs.setString('cart_items', cartStr);
  }

  void addItem(Map<String, dynamic> product) {
    final existingIndex = _items.indexWhere((item) => item.product['id'] == product['id']);
    if (existingIndex >= 0) {
      _items[existingIndex].quantity += 1;
    } else {
      _items.add(CartItem(product: product));
    }
    _saveCart();
    notifyListeners();
  }

  void removeItem(String productId) {
    _items.removeWhere((item) => item.product['id'] == productId);
    _saveCart();
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    _saveCart();
    notifyListeners();
  }

  void incrementQuantity(String productId) {
    final item = _items.firstWhere((item) => item.product['id'] == productId);
    item.quantity += 1;
    _saveCart();
    notifyListeners();
  }

  void decrementQuantity(String productId) {
    final item = _items.firstWhere((item) => item.product['id'] == productId);
    if (item.quantity > 1) {
      item.quantity -= 1;
    } else {
      _items.remove(item);
    }
    _saveCart();
    notifyListeners();
  }
}

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final cart = CartService();

  @override
  void initState() {
    super.initState();
    cart.addListener(_onCartChanged);
  }

  @override
  void dispose() {
    cart.removeListener(_onCartChanged);
    super.dispose();
  }

  void _onCartChanged() {
    setState(() {}); // Re-render when cart changes
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('YOUR CART', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        centerTitle: true,
      ),
      body: cart.items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_bag_outlined, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text("Your cart is empty", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Text("Looks like you haven't added anything yet.", style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: cart.items.length,
                    separatorBuilder: (context, index) => const Divider(height: 32),
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      final images = item.product['images'] as List<dynamic>? ?? [];
                      final imageUrl = images.isNotEmpty ? images[0] : null;

                      return Row(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: imageUrl != null 
                              ? Image.network(imageUrl, fit: BoxFit.cover)
                              : const Icon(Icons.image),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.product['name'] ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "₹${item.product['price']}",
                                  style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    _buildQtyBtn(Icons.remove, () => cart.decrementQuantity(item.product['id'])),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      child: Text("${item.quantity}", style: const TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                    _buildQtyBtn(Icons.add, () => cart.incrementQuantity(item.product['id'])),
                                    const Spacer(),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      onPressed: () => cart.removeItem(item.product['id']),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                
                // Checkout Bottom Bar
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5)),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Subtotal", style: TextStyle(fontSize: 16, color: Colors.grey)),
                            Text("₹${cart.totalAmount}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const CheckoutScreen()),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            ),
                            child: const Text("PROCEED TO CHECKOUT", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildQtyBtn(IconData icon, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 16),
      ),
    );
  }
}
