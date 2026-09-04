import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'product_detail.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  final supabase = Supabase.instance.client;
  List<dynamic> _wishlistedProducts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchWishlist();
  }

  Future<void> _fetchWishlist() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null || user.email == null) {
        setState(() => _isLoading = false);
        return;
      }
      
      final response = await supabase
          .from('wishlists')
          .select('*, products(*)')
          .eq('user_email', user.email!);
          
      final products = response
          .map((w) => w['products'])
          .where((p) => p != null && p['is_archived'] != true)
          .toList();
          
      setState(() {
        _wishlistedProducts = products;
        _isLoading = false;
      });
    } catch (e) {
      print("Error fetching wishlist: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _removeFromWishlist(dynamic product) async {
    final user = supabase.auth.currentUser;
    if (user == null || user.email == null) return;
    
    setState(() {
      _wishlistedProducts.removeWhere((p) => p['id'] == product['id']);
    });
    
    await supabase.from('wishlists').delete().eq('user_email', user.email!).eq('product_id', product['id']);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Wishlist", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, fontFamily: 'serif')),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.black))
        : _wishlistedProducts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.heart, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text("Your wishlist is empty", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'serif')),
                  const SizedBox(height: 8),
                  Text("Save items you love to your wishlist\nto keep track of them.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(20),
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.65,
                crossAxisSpacing: 16,
                mainAxisSpacing: 20,
              ),
              itemCount: _wishlistedProducts.length,
              itemBuilder: (context, index) {
                final product = _wishlistedProducts[index];
                final images = product['images'] as List<dynamic>?;
                final imageUrl = (images != null && images.isNotEmpty) ? images[0] : null;
                
                return GestureDetector(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => ProductDetailScreen(product: product)));
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Container(
                              decoration: BoxDecoration(color: const Color(0xFFF8F5F2), borderRadius: BorderRadius.circular(16)),
                              clipBehavior: Clip.antiAlias,
                              child: imageUrl != null ? Image.network(imageUrl, fit: BoxFit.cover) : const Icon(LucideIcons.imageOff, color: Colors.grey),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: () => _removeFromWishlist(product),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
                                  child: const Icon(Icons.favorite, size: 16, color: Colors.red),
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(product['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text("₹${product['price']}", style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13), overflow: TextOverflow.ellipsis),
                          ),
                          Row(
                            children: [
                              Icon(LucideIcons.star, size: 12, color: Colors.amber.shade600),
                              const SizedBox(width: 2),
                              Text("4.8", style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
