import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'cart.dart';
import 'main.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

class ProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;
  List<dynamic> _reviews = [];
  bool _isLoadingReviews = true;
  bool _isWishlisted = false;

  @override
  void initState() {
    super.initState();
    _fetchReviews();
    _checkWishlistStatus();
  }

  Future<void> _checkWishlistStatus() async {
    final user = supabase.auth.currentUser;
    if (user?.email == null) return;
    
    try {
      final data = await supabase
          .from('wishlists')
          .select('id')
          .eq('user_email', user!.email!)
          .eq('product_id', widget.product['id'])
          .maybeSingle();
      
      if (data != null && mounted) {
        setState(() => _isWishlisted = true);
      }
    } catch (e) {
      debugPrint("Error checking wishlist: $e");
    }
  }

  Future<void> _toggleWishlist() async {
    final user = supabase.auth.currentUser;
    if (user?.email == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please log in to add to wishlist")));
      return;
    }

    final wasWishlisted = _isWishlisted;
    setState(() => _isWishlisted = !_isWishlisted);

    try {
      if (wasWishlisted) {
        await supabase.from('wishlists').delete().eq('user_email', user!.email!).eq('product_id', widget.product['id']);
      } else {
        await supabase.from('wishlists').insert({
          'user_email': user!.email!,
          'product_id': widget.product['id'],
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Added to wishlist! ❤️")));
        }
      }
    } catch (e) {
      setState(() => _isWishlisted = wasWishlisted); // Revert on failure
      debugPrint("Error toggling wishlist: $e");
    }
  }

  Future<void> _fetchReviews() async {
    try {
      final data = await supabase
          .from('reviews')
          .select('*')
          .eq('product_id', widget.product['id'])
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _reviews = data;
          _isLoadingReviews = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingReviews = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final images = product['images'] as List<dynamic>? ?? [];
    final mainImage = images.isNotEmpty ? images[0] : null;
    
    final int inventory = product['stock'] ?? 0;
    final double price = double.tryParse(product['price'].toString()) ?? 0.0;
    final double? compareAt = product['mrp'] != null ? double.tryParse(product['mrp'].toString()) : null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: Icon(
              _isWishlisted ? Icons.favorite : LucideIcons.heart,
              color: _isWishlisted ? Colors.red : Colors.black,
            ),
            onPressed: _toggleWishlist,
          ),
          IconButton(icon: const Icon(LucideIcons.share2), onPressed: () {}),
          ListenableBuilder(
            listenable: CartService(),
            builder: (context, _) {
              final count = CartService().items.fold<int>(0, (sum, item) => sum + item.quantity);
              return Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(LucideIcons.shoppingBag),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const CartScreen()));
                    },
                  ),
                  if (count > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          '$count',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            Container(
              width: double.infinity,
              height: 400,
              color: Colors.grey.shade100,
              child: mainImage != null
                  ? Image.network(mainImage, fit: BoxFit.cover)
                  : const Icon(LucideIcons.imageOff, size: 64, color: Colors.grey),
            ),
            
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Breadcrumbs
                  Text(
                    "HOME  /  ${(product['category'] ?? 'PRODUCT').toString().toUpperCase()}  /  ${(product['name'] ?? '').toString().toUpperCase()}",
                    style: TextStyle(fontSize: 10, letterSpacing: 1.5, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 16),
                  
                  // Title
                  Text(
                    product['name'] ?? 'Unknown Product',
                    style: const TextStyle(fontSize: 28, fontFamily: 'serif'),
                  ),
                  const SizedBox(height: 4),
                  
                  // Brand
                  const Text("by Svaneya", style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.blueGrey)),
                  const SizedBox(height: 8),

                  // Reviews
                  if (!_isLoadingReviews && _reviews.isNotEmpty) ...[
                    Row(
                      children: [
                        ...List.generate(5, (index) {
                          final avgRating = _reviews.map((r) => (r['rating'] as num).toDouble()).reduce((a, b) => a + b) / _reviews.length;
                          if (index < avgRating.floor()) {
                            return const Icon(Icons.star, size: 16, color: Colors.orange);
                          } else if (index < avgRating && avgRating % 1 != 0) {
                            return const Icon(Icons.star_half, size: 16, color: Colors.orange);
                          } else {
                            return Icon(Icons.star_border, size: 16, color: Colors.grey.shade400);
                          }
                        }),
                        const SizedBox(width: 8),
                        Text(
                          "(${_reviews.length} ${_reviews.length == 1 ? 'review' : 'reviews'})",
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  
                  // Price
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("₹${price.toInt()}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500)),
                      if (compareAt != null && compareAt > price) ...[
                        const SizedBox(width: 12),
                        Text(
                          "₹${compareAt.toInt()}",
                          style: TextStyle(fontSize: 18, decoration: TextDecoration.lineThrough, color: Colors.grey.shade400),
                        ),
                      ]
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Low Stock Chip
                  if (inventory > 0 && inventory <= 10)
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.orange.shade200),
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        "Only $inventory left in stock",
                        style: TextStyle(color: Colors.deepOrange.shade700, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                    
                  // Quantity & Add to Cart
                  Row(
                    children: [
                      Container(
                        height: 48,
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(4)),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 20),
                              onPressed: () {
                                if (_quantity > 1) setState(() => _quantity--);
                              },
                            ),
                            SizedBox(
                              width: 30,
                              child: Text("$_quantity", textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, size: 20),
                              onPressed: () {
                                if (_quantity < inventory) setState(() => _quantity++);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              for(int i = 0; i < _quantity; i++){
                                CartService().addItem(product);
                              }
                              
                              // Schedule Abandoned Cart Reminder
                              try {
                                await flutterLocalNotificationsPlugin.cancel(id: 1001); // Cancel any existing cart reminder
                                await flutterLocalNotificationsPlugin.zonedSchedule(
                                    id: 1001,
                                    title: "Did you forget something? 🤔",
                                    body: "Your cart is feeling lonely! Check out now before someone else snags your items.",
                                    scheduledDate: tz.TZDateTime.now(tz.local).add(const Duration(minutes: 60)), // 1 hour from now
                                    notificationDetails: const NotificationDetails(
                                        android: AndroidNotificationDetails(
                                            'abandoned_cart_channel',
                                            'Abandoned Cart Reminders',
                                            channelDescription: 'Reminds you when you leave items in your cart',
                                            importance: Importance.max,
                                            priority: Priority.high,
                                            color: Colors.pink,
                                        )),
                                    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle);
                              } catch(e) {
                                debugPrint("Failed to schedule abandoned cart reminder: $e");
                              }

                              if (context.mounted) {
                                showModalBottomSheet(
                                  context: context,
                                  backgroundColor: Colors.white,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                  ),
                                  builder: (context) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.check_circle, color: Colors.green, size: 48),
                                          const SizedBox(height: 16),
                                          const Text(
                                            "Item added to your cart",
                                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 24),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: OutlinedButton.icon(
                                                  onPressed: () {
                                                    Navigator.pop(context);
                                                    Navigator.push(context, MaterialPageRoute(builder: (context) => const CartScreen()));
                                                  },
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor: Colors.purple.shade700,
                                                    side: BorderSide(color: Colors.purple.shade700),
                                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                                  ),
                                                  icon: const Icon(LucideIcons.shoppingCart, size: 18),
                                                  label: const Text("Go to Cart", style: TextStyle(fontWeight: FontWeight.bold)),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: ElevatedButton.icon(
                                                  onPressed: () {
                                                    Navigator.pop(context);
                                                    Navigator.push(context, MaterialPageRoute(builder: (context) => const CartScreen()));
                                                    // Navigate to checkout directly if they had a checkout screen
                                                  },
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.purple.shade700,
                                                    foregroundColor: Colors.white,
                                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                                  ),
                                                  icon: const Icon(LucideIcons.chevronsRight, size: 18),
                                                  label: const Text("Buy Now", style: TextStyle(fontWeight: FontWeight.bold)),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 16),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            ),
                            icon: const Icon(LucideIcons.shoppingCart, size: 18),
                            label: const Text("ADD TO CART", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 12),
                  
                  // Shipping Banner
                  const Text(
                    "FREE SHIPPING ON ORDERS OVER ₹999. SHIPS IN 24HRS.",
                    style: TextStyle(fontSize: 11, letterSpacing: 1, color: Colors.blueGrey, height: 1.5),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Specifications Section
                  const Center(child: Text("Product Details", style: TextStyle(fontSize: 22, fontFamily: 'serif'))),
                  const SizedBox(height: 20),
                  
                  _buildExpansionTile("PRODUCT DESCRIPTION", product['description'] ?? "No description available.", initiallyExpanded: true),
                  
                  const SizedBox(height: 40),
                  const Divider(),
                  const SizedBox(height: 20),
                  
                  // Customer Reviews Section
                  const Text("Customer Reviews", style: TextStyle(fontSize: 22, fontFamily: 'serif')),
                  const SizedBox(height: 16),
                  
                  if (_isLoadingReviews)
                    const Center(child: CircularProgressIndicator())
                  else if (_reviews.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
                      child: const Center(
                        child: Text("No reviews yet. Be the first to review this product!", style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
                      ),
                    )
                  else
                    ..._reviews.map((review) {
                      final rating = (review['rating'] as num).toInt();
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                ...List.generate(5, (i) => Icon(
                                  i < rating ? Icons.star : Icons.star_border,
                                  size: 14, color: Colors.orange,
                                )),
                                const Spacer(),
                                Text(
                                  DateTime.parse(review['created_at']).toLocal().toString().split(' ')[0],
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(review['title'] ?? 'Review', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 4),
                            Text(review['comment'] ?? '', style: TextStyle(color: Colors.grey.shade700, fontSize: 14, height: 1.4)),
                            const SizedBox(height: 8),
                            Text("- ${review['reviewer_name'] ?? 'Anonymous'}", style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      );
                    }).toList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildExpansionTile(String title, String content, {bool initiallyExpanded = false}) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        tilePadding: EdgeInsets.zero,
        title: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
        iconColor: Colors.black,
        collapsedIconColor: Colors.black,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: HtmlWidget(
                content,
                textStyle: TextStyle(
                  color: Colors.grey.shade700,
                  height: 1.5,
                  fontSize: 14.0,
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
