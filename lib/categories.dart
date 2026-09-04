import 'package:flutter/material.dart';
import 'main.dart'; // contains supabase instance
import 'collection.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    try {
      // Fetch products to extract unique categories and one representative image per category
      final data = await supabase
          .from('products')
          .select('category, images')
          .eq('is_archived', false)
          .order('created_at', ascending: false);

      final Map<String, String> categoryMap = {};

      for (var item in data) {
        final cat = (item['category'] ?? 'Other').toString().trim();
        final images = item['images'] as List<dynamic>? ?? [];
        
        if (cat.isNotEmpty) {
          // Only set the image if we haven't found one for this category yet
          if (!categoryMap.containsKey(cat.toLowerCase())) {
            if (images.isNotEmpty) {
              categoryMap[cat.toLowerCase()] = images[0].toString();
            } else {
              categoryMap[cat.toLowerCase()] = ''; // Fallback
            }
          }
        }
      }

      final List<Map<String, dynamic>> finalCategories = categoryMap.entries.map((e) {
        return {
          'name': e.key,
          'image': e.value,
        };
      }).toList();

      // Sort alphabetically
      finalCategories.sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));

      if (mounted) {
        setState(() {
          _categories = finalCategories;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to load categories: $e")));
      }
    }
  }

  String _capitalize(String s) => s.isEmpty ? '' : '${s[0].toUpperCase()}${s.substring(1)}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('EXPLORE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : _categories.isEmpty
              ? const Center(child: Text("No categories found."))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final name = _capitalize(cat['name']);
                    final imageUrl = cat['image'] as String;

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CollectionScreen(
                              title: name,
                              filterType: 'category_${cat['name']}',
                            ),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                          ]
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (imageUrl.isNotEmpty)
                              Image.network(imageUrl, fit: BoxFit.cover)
                            else
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.grey.shade300, Colors.grey.shade100],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: const Center(child: Icon(Icons.category, color: Colors.grey, size: 40)),
                              ),
                              
                            // Dark overlay for text readability
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                ),
                              ),
                            ),
                            
                            Positioned(
                              bottom: 16,
                              left: 16,
                              right: 16,
                              child: Text(
                                name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
