import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:marquee/marquee.dart';
import 'product_detail.dart';
import 'cart.dart';
import 'categories.dart';
import 'account.dart';
import 'wishlist.dart';
import 'search.dart';
import 'collection.dart';
import 'orders.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:badges/badges.dart' as badges;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:carousel_slider/carousel_slider.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  tz.initializeTimeZones();
  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(settings: initializationSettings);
  
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase init error: $e");
  }
  
  await Supabase.initialize(
    url: 'https://bubutwlfitvwcqxczeoe.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ1YnV0d2xmaXR2d2NxeGN6ZW9lIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc0NzQwNzIsImV4cCI6MjEwMzA1MDA3Mn0.ZqWk48L6fsuaegWvmV5pulcmMhLJ4tmlqzHzeWAjxZo',
  );

  runApp(const SvaneyaApp());
}

final supabase = Supabase.instance.client;

class SvaneyaApp extends StatelessWidget {
  const SvaneyaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Svaneya',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF8F5F2),
          primary: Colors.black,
        ),
        scaffoldBackgroundColor: const Color(0xFFFDFBF9),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _setupPushNotifications();
    
    // Listen for logins/logouts to ensure the token gets tied to the user immediately
    supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn) {
        _setupPushNotifications(); // Re-fetch and upload token now that user is logged in
      }
    });
  }

  Future<void> _setupPushNotifications() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      
      // Get token and save to DB
      final token = await messaging.getToken();
      if (token != null) {
        debugPrint("FCM Token: $token");
        final user = supabase.auth.currentUser;
        if (user != null && user.email != null) {
          await supabase.from('fcm_tokens').upsert({
            'email': user.email,
            'token': token,
            'updated_at': DateTime.now().toIso8601String()
          });
        }
      }

      // Listen for foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (message.notification != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  if (message.notification!.android?.imageUrl != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(message.notification!.android!.imageUrl!, width: 40, height: 40, fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(message.notification!.title ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(message.notification!.body ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.pink.shade700,
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
            )
          );
        }
      });
    } catch (e) {
      debugPrint("FCM Setup error: $e");
    }
  }

  List<Widget> get _screens => [
    const HomeScreen(),
    const CategoriesScreen(),
    const WishlistScreen(),
    const OrdersScreen(),
    const AccountScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: Colors.white,
        elevation: 10,
        indicatorColor: Colors.grey.shade200,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(icon: Icon(LucideIcons.home), selectedIcon: Icon(LucideIcons.home), label: 'Home'),
          NavigationDestination(icon: Icon(LucideIcons.layoutGrid), selectedIcon: Icon(LucideIcons.layoutGrid), label: 'Categories'),
          NavigationDestination(icon: Icon(LucideIcons.heart), selectedIcon: Icon(LucideIcons.heart), label: 'Wishlist'),
          NavigationDestination(icon: Icon(LucideIcons.fileText), selectedIcon: Icon(LucideIcons.fileText), label: 'Orders'),
          NavigationDestination(icon: Icon(LucideIcons.user), selectedIcon: Icon(LucideIcons.user), label: 'Profile'),
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> _products = [];
  List<dynamic> _specialEditions = [];
  List<dynamic> _newArrivals = [];
  List<dynamic> _bestSellers = [];
  List<dynamic> _categories = [];
  List<dynamic> _mobileBanners = [];
  Map<String, dynamic>? _storeSettings;
  Set<String> _wishlistProductIds = {};
  bool _isLoading = true;
  int _currentBannerIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final productsData = await supabase.from('products').select('*').eq('is_archived', false).order('created_at', ascending: false);
      final categoriesData = await supabase.from('categories').select('*').order('name');
      final settingsData = await supabase.from('store_settings').select('*').eq('id', 'global').maybeSingle();
      final bannersData = await supabase.from('mobile_banners').select('*').order('sort_order', ascending: true);
      
      final user = supabase.auth.currentUser;
      Set<String> wishlistIds = {};
      if (user != null && user.email != null) {
        final wishlistData = await supabase.from('wishlists').select('product_id').eq('user_email', user.email!);
        wishlistIds = wishlistData.map((w) => w['product_id'].toString()).toSet();
      }
          
      setState(() {
        _products = productsData;
        _specialEditions = productsData.where((p) => p['is_special_edition'] == true).toList();
        _newArrivals = productsData.where((p) => p['is_new_arrival'] == true).toList();
        _bestSellers = productsData.where((p) => p['is_best_seller'] == true).toList();
        _categories = categoriesData;
        _storeSettings = settingsData;
        _mobileBanners = bannersData;
        _wishlistProductIds = wishlistIds;
        _isLoading = false;
      });
    } catch (e) {
      print("Error fetching data: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleWishlist(dynamic product) async {
    final user = supabase.auth.currentUser;
    if (user == null || user.email == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please login to use wishlist")));
       return;
    }
    
    final productId = product['id'].toString();
    final isWishlisted = _wishlistProductIds.contains(productId);
    
    setState(() {
      if (isWishlisted) {
        _wishlistProductIds.remove(productId);
      } else {
        _wishlistProductIds.add(productId);
      }
    });
    
    if (isWishlisted) {
      await supabase.from('wishlists').delete().eq('user_email', user.email!).eq('product_id', product['id']);
    } else {
      await supabase.from('wishlists').insert({'user_email': user.email!, 'product_id': product['id']});
    }
  }

  @override
  Widget build(BuildContext context) {
    String? heroImage;
    if (_storeSettings != null && _storeSettings!['hero_image_1'] != null && _storeSettings!['hero_image_1'].toString().isNotEmpty) {
      heroImage = _storeSettings!['hero_image_1'];
    } else if (_products.isNotEmpty) {
      final images = _products[0]['images'] as List<dynamic>?;
      if (images != null && images.isNotEmpty) {
        heroImage = images[0];
      }
    }
    
    final bool saleActive = _storeSettings?['sale_active'] == true;
    final String saleText = _storeSettings?['sale_text'] ?? "Special Sale Event!";

    return Scaffold(
      body: SafeArea(
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : RefreshIndicator(
              onRefresh: _fetchData,
              color: Colors.black,
              backgroundColor: Colors.white,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 10),
                          // Top Bar
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: const Icon(LucideIcons.menu, size: 28),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {},
                              ),
                              const Text(
                                "SVANEYA",
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 3.0, fontFamily: 'serif'),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(LucideIcons.bell, size: 28),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () {},
                                  ),
                                  const SizedBox(width: 12),
                                  ListenableBuilder(
                                    listenable: CartService(),
                                    builder: (context, _) {
                                      final count = CartService().items.fold<int>(0, (sum, item) => sum + item.quantity);
                                      return Stack(
                                        alignment: Alignment.center,
                                        clipBehavior: Clip.none,
                                        children: [
                                          IconButton(
                                            icon: const Icon(LucideIcons.shoppingBag, size: 26),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: () {
                                              Navigator.push(context, MaterialPageRoute(builder: (context) => const CartScreen()));
                                            },
                                          ),
                                          if (count > 0)
                                            Positioned(
                                              top: -4,
                                              right: -4,
                                              child: Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                                                child: Text(
                                                  '$count',
                                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              )
                            ],
                          ),
                          const SizedBox(height: 24),
                          
                          // Search Bar
                          GestureDetector(
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const SearchScreen()));
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                              child: TextField(
                                enabled: false,
                                decoration: InputDecoration(
                                  hintText: "Search for rings, earrings, necklaces...",
                                  hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                                  prefixIcon: const Icon(LucideIcons.search, color: Colors.grey),
                                  suffixIcon: const Icon(LucideIcons.slidersHorizontal, color: Colors.grey),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          // Sale Banner (Marquee)
                          if (saleActive)
                            Container(
                              width: double.infinity,
                              height: 44,
                              margin: const EdgeInsets.only(bottom: 24),
                              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)),
                              child: Row(
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(left: 16.0, right: 12.0),
                                    child: Icon(LucideIcons.tag, color: Colors.white, size: 16),
                                  ),
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.only(topRight: Radius.circular(8), bottomRight: Radius.circular(8)),
                                      child: Marquee(
                                        text: saleText.isNotEmpty ? saleText : "Special Sale Event! Shop Now",
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13, letterSpacing: 1.5),
                                        scrollAxis: Axis.horizontal,
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        blankSpace: 60.0,
                                        velocity: 35.0,
                                        startPadding: 10.0,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          
                          // Mobile Banners Carousel
                          if (_mobileBanners.isNotEmpty)
                            Stack(
                              children: [
                                CarouselSlider(
                                  options: CarouselOptions(
                                    height: 180.0,
                                    autoPlay: true,
                                    autoPlayInterval: const Duration(seconds: 4),
                                    viewportFraction: 1.0,
                                    enlargeCenterPage: false,
                                    onPageChanged: (index, reason) {
                                      setState(() {
                                        _currentBannerIndex = index;
                                      });
                                    },
                                  ),
                                  items: _mobileBanners.map((banner) {
                                    return Builder(
                                      builder: (BuildContext context) {
                                        return Container(
                                          width: MediaQuery.of(context).size.width,
                                          margin: const EdgeInsets.symmetric(horizontal: 0.0), // Full bleed
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(16),
                                            color: Colors.grey.shade200,
                                          ),
                                          clipBehavior: Clip.antiAlias,
                                          child: Image.network(
                                            banner['image_url'],
                                            fit: BoxFit.cover,
                                          ),
                                        );
                                      },
                                    );
                                  }).toList(),
                                ),
                                Positioned(
                                  bottom: 12,
                                  left: 0,
                                  right: 0,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: _mobileBanners.asMap().entries.map((entry) {
                                      return AnimatedContainer(
                                        duration: const Duration(milliseconds: 300),
                                        width: _currentBannerIndex == entry.key ? 16.0 : 4.0,
                                        height: 3.5,
                                        margin: const EdgeInsets.symmetric(horizontal: 3.0),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(10.0),
                                          color: _currentBannerIndex == entry.key ? Colors.white : Colors.white.withOpacity(0.5),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            )
                          else if (_isLoading)
                            Container(
                              width: double.infinity,
                              height: 180,
                              decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(16)),
                              child: const Center(child: CircularProgressIndicator(color: Colors.black)),
                            ),
                          const SizedBox(height: 32),
                          
                          // Categories
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Shop by Categories", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              Text("See all", style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 90,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              itemCount: _categories.length,
                              itemBuilder: (context, index) {
                                final category = _categories[index];
                                String title = category['name'] ?? 'Unknown';
                                String? displayImage = category['image_url'];
                                
                                if (displayImage == null || displayImage.isEmpty) {
                                  dynamic matchingProduct;
                                  for (var p in _products) {
                                    if (p['category'] == title) {
                                      matchingProduct = p;
                                      break;
                                    }
                                  }
                                  if (matchingProduct != null) {
                                    final imgs = matchingProduct['images'] as List<dynamic>?;
                                    if (imgs != null && imgs.isNotEmpty) {
                                      displayImage = imgs[0];
                                    }
                                  }
                                }
                                return _buildCategoryItem(title, displayImage);
                              },
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                    
                    // Product Sections
                    _buildProductGrid("Special Editions", _specialEditions, isDark: true),
                    _buildProductGrid("New Arrivals", _newArrivals),
                    _buildProductGrid("Best Sellers", _bestSellers),
                    _buildProductGrid("All Products", _products, isHorizontal: false),
                    
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
      ),
    );
  }

  Widget _buildProductGrid(String title, List<dynamic> products, {bool isHorizontal = true, bool isDark = false}) {
    if (products.isEmpty) return const SizedBox.shrink();
    
    return Container(
      color: isDark ? const Color(0xFF0A0A0A) : Colors.transparent,
      padding: EdgeInsets.only(top: isDark ? 40 : 0, bottom: isDark ? 40 : 0),
      margin: EdgeInsets.only(bottom: isDark ? 24 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'serif', color: isDark ? Colors.white : Colors.black)),
                GestureDetector(
                  onTap: () {
                    String filter = 'all';
                    if (title == "Special Editions") filter = 'special_editions';
                    if (title == "New Arrivals") filter = 'new_arrivals';
                    if (title == "Best Sellers") filter = 'best_sellers';
                    Navigator.push(context, MaterialPageRoute(builder: (context) => CollectionScreen(title: title, filterType: filter)));
                  },
                  child: Text("See all", style: TextStyle(color: isDark ? Colors.white70 : Colors.grey.shade600, fontSize: 14)),
                ),
              ],
            ),
          ),
          if (isDark && title == "Special Editions")
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
              child: Text("Exclusive and rare collections.", style: TextStyle(color: Colors.white54, fontSize: 13)),
            ),
          const SizedBox(height: 16),
          if (isHorizontal)
            SizedBox(
              height: 250,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  return Container(
                    width: 150,
                    margin: const EdgeInsets.only(right: 16),
                    child: _buildProductCard(products[index], isDark: isDark),
                  );
                },
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.65,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 24,
                ),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  return _buildProductCard(products[index], isDark: isDark);
                },
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Color _parseColor(String? hexString, Color fallback) {
    if (hexString == null || hexString.isEmpty) return fallback;
    try {
      final buffer = StringBuffer();
      if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
      buffer.write(hexString.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (e) {
      return fallback;
    }
  }

  Widget _buildProductCard(dynamic product, {bool isDark = false}) {
    final images = product['images'] as List<dynamic>?;
    final imageUrl = (images != null && images.isNotEmpty) ? images[0] : null;
    final productId = product['id'].toString();
    final isWishlisted = _wishlistProductIds.contains(productId);
    
    // Custom Badge Logic
    final String? badgeText = product['badge_text'];
    final Color badgeBg = _parseColor(product['badge_bg'], Colors.black);
    final Color badgeTextColor = _parseColor(product['badge_text_color'], Colors.white);
    
    // Pricing logic
    final double price = double.tryParse(product['price'].toString()) ?? 0.0;
    final double? compareAt = product['mrp'] != null ? double.tryParse(product['mrp'].toString()) : null;
    int savePercentage = 0;
    if (compareAt != null && compareAt > price) {
      savePercentage = (((compareAt - price) / compareAt) * 100).round();
    }
    
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
              decoration: BoxDecoration(color: const Color(0xFFF8F5F2), borderRadius: BorderRadius.circular(16)),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  imageUrl != null ? Image.network(imageUrl, fit: BoxFit.cover) : const Icon(LucideIcons.imageOff, color: Colors.grey),
                  
                  // Top Left Badges
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (savePercentage > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            margin: const EdgeInsets.only(bottom: 6),
                            color: Colors.white,
                            child: Text("$savePercentage% OFF", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.black)),
                          ),
                        if (badgeText != null && badgeText.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            color: badgeBg,
                            child: Text(badgeText.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1, color: badgeTextColor)),
                          ),
                      ],
                    ),
                  ),
                  
                  // Bottom Left Rating
                  Positioned(
                    bottom: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
                      child: Row(
                        children: [
                          const Text("4.5", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black)),
                          const SizedBox(width: 2),
                          Icon(Icons.star, size: 10, color: Colors.amber.shade600),
                          const SizedBox(width: 2),
                          const Text("(124)", style: TextStyle(fontSize: 10, color: Colors.black54)),
                        ],
                      ),
                    ),
                  ),
                  
                  // Wishlist Heart (Top Right)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: GestureDetector(
                      onTap: () => _toggleWishlist(product),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isWishlisted ? Colors.red.shade50 : Colors.white, 
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isWishlisted ? Icons.favorite : LucideIcons.heart, 
                          size: 16, 
                          color: isWishlisted ? Colors.red : Colors.black54,
                        ),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(product['name'] ?? '', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isDark ? Colors.white : Colors.black), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Row(
            children: [
              Text("₹${price.toInt()}", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: isDark ? Colors.white : Colors.black)),
              if (compareAt != null && compareAt > price) ...[
                const SizedBox(width: 6),
                Text("₹${compareAt.toInt()}", style: TextStyle(fontWeight: FontWeight.w400, fontSize: 12, color: isDark ? Colors.white54 : Colors.grey.shade500, decoration: TextDecoration.lineThrough)),
              ]
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(String title, String? imageUrl) {
    return Padding(
      padding: const EdgeInsets.only(right: 20.0),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: const Color(0xFFF8F5F2), borderRadius: BorderRadius.circular(16)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: imageUrl != null && imageUrl.isNotEmpty ? Image.network(imageUrl, fit: BoxFit.cover) : const Icon(LucideIcons.imageOff, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
        ],
      ),
    );
  }
}
