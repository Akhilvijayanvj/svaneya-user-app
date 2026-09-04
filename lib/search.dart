import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'product_detail.dart';
import 'cart.dart';

class SearchScreen extends StatefulWidget {
  final String initialQuery;
  const SearchScreen({super.key, this.initialQuery = ''});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final supabase = Supabase.instance.client;
  List<dynamic> _searchResults = [];
  List<dynamic> _categories = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    if (widget.initialQuery.isNotEmpty) {
      _searchController.text = widget.initialQuery;
      _performSearch(widget.initialQuery);
    } else {
      _fetchPopularProducts();
    }
  }

  Future<void> _fetchPopularProducts() async {
    setState(() => _isLoading = true);
    try {
      final data = await supabase
          .from('products')
          .select('*')
          .eq('is_archived', false)
          .order('created_at', ascending: false)
          .limit(10);
      if (mounted) {
        setState(() {
          _searchResults = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint("Failed to fetch popular products: $e");
    }
  }

  Future<void> _fetchCategories() async {
    try {
      final data = await supabase.from('categories').select('*').order('name');
      if (mounted) {
        setState(() {
          _categories = data;
        });
      }
    } catch (e) {
      debugPrint("Failed to fetch categories: $e");
    }
  }

  Future<void> _performSearch(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      final data = await supabase
          .from('products')
          .select('*')
          .eq('is_archived', false)
          .or('name.ilike."%$trimmedQuery%",description.ilike."%$trimmedQuery%"')
          .order('created_at', ascending: false);
          
      if (mounted) {
        setState(() {
          _searchResults = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Search failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFDFD),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header / Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: TextField(
                        controller: _searchController,
                        autofocus: widget.initialQuery.isEmpty,
                        textInputAction: TextInputAction.search,
                        onSubmitted: _performSearch,
                        decoration: InputDecoration(
                          hintText: "Search all",
                          hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                          prefixIcon: const Icon(LucideIcons.search, color: Colors.black, size: 20),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_searchController.text.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.close, color: Colors.grey, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    _performSearch('');
                                  },
                                ),
                              Container(
                                height: 24,
                                width: 1,
                                color: Colors.grey.shade300,
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                              ),
                              IconButton(
                                icon: const Icon(LucideIcons.slidersHorizontal, color: Colors.black, size: 18),
                                onPressed: () {},
                              ),
                              const SizedBox(width: 8),
                            ],
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onChanged: (val) {
                          setState(() {}); // to toggle close icon
                          _performSearch(val);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  if (!_hasSearched || _searchResults.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("All Categories", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 12,
                              children: _categories.map((c) => _buildCategoryChip(c['name'])).toList(),
                            ),
                            const SizedBox(height: 32),
                            if (!_hasSearched) ...[
                              const Text("Popular Products", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                              const SizedBox(height: 16),
                            ]
                          ],
                        ),
                      ),
                    ),
                  
                  if (_isLoading)
                    const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator(color: Colors.black)),
                    )
                  else if (_hasSearched && _searchResults.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.frown, size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            const Text("No results found.", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            return _buildProductListItem(_searchResults[index]);
                          },
                          childCount: _searchResults.length,
                        ),
                      ),
                    )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String label) {
    return GestureDetector(
      onTap: () {
        _searchController.text = label;
        _performSearch(label);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.black87),
        ),
      ),
    );
  }

  Widget _buildProductListItem(dynamic product) {
    final images = product['images'] as List<dynamic>? ?? [];
    final imageUrl = images.isNotEmpty ? images[0] : null;
    
    final double price = double.tryParse(product['price'].toString()) ?? 0;
    final double? mrp = product['mrp'] != null ? double.tryParse(product['mrp'].toString()) : null;

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => ProductDetailScreen(product: product)));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            // Image
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              clipBehavior: Clip.antiAlias,
              child: imageUrl != null
                  ? Image.network(imageUrl, fit: BoxFit.cover)
                  : const Icon(Icons.image, color: Colors.grey),
            ),
            const SizedBox(width: 16),
            
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['name'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text("₹$price", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                      if (mrp != null && mrp > price) ...[
                        const SizedBox(width: 6),
                        Text("₹$mrp", style: TextStyle(color: Colors.grey.shade500, decoration: TextDecoration.lineThrough, fontSize: 11, fontWeight: FontWeight.w500)),
                      ]
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Mock color dots
                  Row(
                    children: [
                      _buildColorDot(const Color(0xFFE8B6A2)),
                      const SizedBox(width: 4),
                      _buildColorDot(const Color(0xFFD3D3D3)),
                    ],
                  )
                ],
              ),
            ),
            
            // Add to Cart Button
            GestureDetector(
              onTap: () {
                CartService().addItem(product);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Added to cart!"), backgroundColor: Colors.black, duration: Duration(seconds: 1)),
                );
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(LucideIcons.shoppingBag, size: 20, color: Colors.black),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: const Icon(Icons.add, size: 10, color: Colors.black, weight: 800),
                      ),
                    )
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildColorDot(Color color) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
