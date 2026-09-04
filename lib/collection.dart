import 'package:flutter/material.dart';
import 'main.dart'; // contains supabase instance
import 'product_detail.dart';

class CollectionScreen extends StatefulWidget {
  final String title;
  final String filterType;

  const CollectionScreen({super.key, required this.title, required this.filterType});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  List<dynamic> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCollection();
  }

  Future<void> _fetchCollection() async {
    try {
      dynamic query = supabase.from('products').select('*').eq('is_archived', false);

      if (widget.filterType == 'special_editions') {
        query = query.eq('is_special_edition', true);
      } else if (widget.filterType == 'new_arrivals') {
        query = query.order('created_at', ascending: false).limit(50);
      } else if (widget.filterType == 'best_sellers') {
        // Mock best sellers by selecting a specific subset, or just random
        // If there is no best_seller column, we can just sort by stock for demonstration
        query = query.order('stock', ascending: true).limit(50); 
      } else if (widget.filterType.startsWith('category_')) {
        final cat = widget.filterType.replaceAll('category_', '');
        // Using ilike for case-insensitive matching
        query = query.ilike('category', cat).order('created_at', ascending: false);
      } else {
        query = query.order('created_at', ascending: false);
      }

      final data = await query;

      if (mounted) {
        setState(() {
          _products = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load collection: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(widget.title, style: const TextStyle(color: Colors.black, fontFamily: 'serif', fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.black))
        : _products.isEmpty
          ? const Center(child: Text("No products found in this collection."))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.65,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: _products.length,
              itemBuilder: (context, index) {
                final product = _products[index];
                final images = product['images'] as List<dynamic>? ?? [];
                final imageUrl = images.isNotEmpty ? images[0] : null;
                
                final double price = double.tryParse(product['price'].toString()) ?? 0;
                final double? mrp = product['mrp'] != null ? double.tryParse(product['mrp'].toString()) : null;
                final int discount = mrp != null && mrp > price ? (((mrp - price) / mrp) * 100).round() : 0;
                
                final String? customBadge = product['badge_text'];
                final String badgeBg = product['badge_bg'] ?? '#000000';
                final String badgeColor = product['badge_text_color'] ?? '#ffffff';

                return GestureDetector(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => ProductDetailScreen(product: product)));
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (imageUrl != null)
                                Image.network(imageUrl, fit: BoxFit.cover)
                              else
                                const Icon(Icons.image, size: 50, color: Colors.grey),
                                
                              // Badges
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (discount > 0)
                                      Container(
                                        margin: const EdgeInsets.only(bottom: 4),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text("$discount% OFF", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                                      ),
                                    if (customBadge != null && customBadge.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Color(int.parse(badgeBg.replaceFirst('#', '0xff'))),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(customBadge.toUpperCase(), style: TextStyle(color: Color(int.parse(badgeColor.replaceFirst('#', '0xff'))), fontWeight: FontWeight.bold, fontSize: 10)),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        product['name'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text("₹$price", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          if (mrp != null && mrp > price) ...[
                            const SizedBox(width: 8),
                            Text("₹$mrp", style: TextStyle(color: Colors.grey.shade500, decoration: TextDecoration.lineThrough, fontSize: 12)),
                          ]
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
