import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/food_truck.dart';
import '../models/menu_item.dart' as app_models;
import '../models/popular_menu_slide.dart';
import '../services/popular_menu_service.dart';
import '../data/mock_food_trucks.dart';
import '../data/mock_menu.dart';
import '../state/favorites_provider.dart';
import '../utils/app_colors.dart';
import '../utils/page_transitions.dart';
import '../widgets/item_thumbnail.dart';
import 'food_truck_menu_screen.dart';
import 'menu_item_detail_screen.dart';

Widget _buildFavPlaceholder(BuildContext context) {
  return Container(
    color: Colors.grey.shade200,
    child: Center(
      child: Icon(Icons.fastfood, size: 32, color: Colors.grey.shade400),
    ),
  );
}

/// Home screen - editorial style with hero carousel and list
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  final PageController _heroPageController = PageController();
  int _heroPage = 0;
  Timer? _heroAutoScrollTimer;
  StreamSubscription<List<PopularMenuSlide>>? _popularSlidesSub;
  List<PopularMenuSlide> _popularSlides = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<({app_models.MenuItem item, String truckId, String truckLabel})> _searchResults = [];
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward();

    _popularSlides = PopularMenuService.syntheticSingleTruckFallback(4);
    PopularMenuService.loadSlidesFromActualMenus(limit: 4).then((menus) {
      if (!mounted || menus.isEmpty) return;
      setState(() => _popularSlides = menus);
    });
    _popularSlidesSub = PopularMenuService.watchTop(limit: 4).listen(
      (list) {
        if (!mounted) return;
        if (list.isEmpty) {
          PopularMenuService.loadSlidesFromActualMenus(limit: 4).then((menus) {
            if (!mounted) return;
            setState(() => _popularSlides = menus);
          });
          return;
        }
        setState(() {
          _popularSlides = list;
          if (_heroPage >= _popularSlides.length) {
            _heroPage = 0;
          }
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_heroPageController.hasClients) return;
          final n = _popularSlides.length;
          if (n == 0) return;
          if (_heroPageController.page != null &&
              _heroPageController.page!.round() >= n) {
            _heroPageController.jumpToPage(0);
          }
        });
      },
      onError: (Object e, StackTrace st) {
        debugPrint('Popular menu stream error: $e');
        if (mounted) {
          setState(() {
            _popularSlides = PopularMenuService.syntheticSingleTruckFallback(4);
          });
        }
      },
    );

    _heroAutoScrollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_heroPageController.hasClients) return;
      final n = _popularSlides.length;
      if (n <= 1) return;
      final next = (_heroPage + 1) % n;
      _heroPageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _heroAutoScrollTimer?.cancel();
    _popularSlidesSub?.cancel();
    _animController.dispose();
    _heroPageController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _searchResults = [];
    });
    FocusScope.of(context).unfocus();
  }

  void _onSearchChanged(String query) {
    if (query.trim().isEmpty) {
      _searchDebounce?.cancel();
      setState(() {
        _searchQuery = query;
        _searchResults = [];
      });
      return;
    }
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _runSearch(query);
    });
    setState(() => _searchQuery = query);
  }

  /// Returns true if every word in [queryWords] appears in [searchableText].
  static bool _matchesWords(List<String> queryWords, String searchableText) {
    final text = searchableText.toLowerCase();
    for (final word in queryWords) {
      if (word.isEmpty) continue;
      if (!text.contains(word)) return false;
    }
    return true;
  }

  Future<void> _runSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchQuery = query;
        _searchResults = [];
      });
      return;
    }
    try {
      final q = query.trim().toLowerCase();
      final queryWords = q.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
      final results = <({app_models.MenuItem item, String truckId, String truckLabel})>[];

      // Search Firestore: menu_items in ALL trucks by querying each truck's
      // subcollection (no collectionGroup index needed). Same item can exist in multiple trucks.
      try {
        final firestore = FirebaseFirestore.instance;
        List<String> truckIds = [];
        final truckDocs = <String, Map<String, dynamic>>{};
        try {
          final trucksSnapshot = await firestore.collection('food_trucks').get();
          truckIds = trucksSnapshot.docs.map((d) => d.id).toList();
          for (final d in trucksSnapshot.docs) {
            truckDocs[d.id] = d.data();
          }
        } catch (_) {
          truckIds = mockFoodTrucks.map((t) => t.id).toList();
        }
        if (truckIds.isEmpty) truckIds = mockFoodTrucks.map((t) => t.id).toList();

        for (final truckId in truckIds) {
          final snapshot = await firestore
              .collection('food_trucks')
              .doc(truckId)
              .collection('menu_items')
              .get();
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final name = (data['name'] ?? '').toString();
            final description = (data['description'] ?? '').toString();
            final category = (data['category'] ?? 'Sides').toString();
            final searchable = '$name $description $category';
            if (_matchesWords(queryWords, searchable)) {
              results.add((
                item: app_models.MenuItem(
                  id: doc.id,
                  name: name,
                  description: description,
                  price: (data['price'] ?? 0.0).toDouble(),
                  imageUrl: ((data['imageUrl'] ?? '').toString().trim().isNotEmpty)
                      ? data['imageUrl']
                      : defaultMenuImageFor(name, category),
                  category: category,
                ),
                truckId: truckId,
                truckLabel: PopularMenuService.resolvedDisplayName(truckId, truckDocs[truckId]),
              ));
            }
          }
        }
      } catch (_) {
        // Firestore error; fall back to mock below
      }

      // Only use mock when Firestore returned no results (empty DB or no matches)
      if (results.isEmpty) {
        final trucks = mockFoodTrucks;
        for (var i = 0; i < mockMenuItems.length; i++) {
          final item = mockMenuItems[i];
          final searchable = '${item.name} ${item.description} ${item.category}';
          if (_matchesWords(queryWords, searchable)) {
            final truck = trucks[i % trucks.length];
            results.add((
              item: app_models.MenuItem(
                id: item.id,
                name: item.name,
                description: item.description,
                price: item.price,
                imageUrl: item.imageUrl,
                category: item.category,
              ),
              truckId: truck.id,
              truckLabel: truck.name,
            ));
          }
        }
      }

      if (mounted) setState(() => _searchResults = results);
    } catch (e) {
      if (mounted) setState(() => _searchResults = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final featuredTrucks = mockFoodTrucks.take(4).toList();
    final surfaceColor = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

    final topPadding = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F4),
      body: SafeArea(
        top: false,
        bottom: false,
        child: CustomScrollView(
          slivers: [
            // Search bar - full width above Featured
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, topPadding + 8, 16, 12),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search for menu items',
                    hintStyle: TextStyle(
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w400,
                      fontSize: 15,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Colors.grey[700],
                      size: 22,
                    ),
                    suffixIcon: _searchQuery.trim().isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.close,
                              size: 20,
                              color: Colors.grey[700],
                            ),
                            tooltip: 'Clear search',
                            onPressed: _clearSearch,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 40,
                              minHeight: 40,
                            ),
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.grey[200],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: Colors.grey[400]!, width: 1),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: Colors.grey[400]!, width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: AppColors.burgundy, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ),

            // Search results or normal content
            if (_searchQuery.trim().isNotEmpty) ...[
              if (_searchResults.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'No menu items found',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final r = _searchResults[index];
                        FoodTruck foodTruck;
                        try {
                          foodTruck = mockFoodTrucks.firstWhere((t) => t.id == r.truckId);
                        } catch (_) {
                          foodTruck = FoodTruck(
                            id: r.truckId,
                            name: r.truckLabel,
                            cuisine: '',
                            rating: 0,
                            imageUrl: '',
                            isOpen: true,
                          );
                        }
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: ItemThumbnail(
                              imageUrl: r.item.imageUrl,
                              size: 48,
                            ),
                            title: Text(
                              r.item.name,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            subtitle: Text(
                              '${r.item.price.toStringAsFixed(2)} EGP',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            trailing: SizedBox(
                              width: 120,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Flexible(
                                    child: Text(
                                      r.truckLabel,
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey[700],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.end,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.chevron_right, size: 20),
                                ],
                              ),
                            ),
                            onTap: () {
                              context.slideTo(
                                MenuItemDetailScreen(
                                  item: r.item,
                                  truck: foodTruck,
                                ),
                                direction: SlideDirection.right,
                              );
                            },
                          ),
                        );
                      },
                      childCount: _searchResults.length,
                    ),
                  ),
                ),
            ] else ...[
            // Hero - single swipeable rectangle with page dots
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Featured',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Popular picks around your campus',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w400,
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: SizedBox(
                        height: 200,
                        child: PageView.builder(
                          controller: _heroPageController,
                          onPageChanged: (index) {
                            setState(() => _heroPage = index);
                          },
                          itemCount: _popularSlides.isEmpty
                              ? 1
                              : _popularSlides.length,
                          itemBuilder: (context, index) {
                            final slides = _popularSlides.isNotEmpty
                                ? _popularSlides
                                : PopularMenuService.syntheticSingleTruckFallback(4);
                            return _PopularMenuHeroCard(
                              slide: slides[index.clamp(0, slides.length - 1)],
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        (_popularSlides.isEmpty
                                ? 1
                                : _popularSlides.length)
                            .clamp(1, 8),
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _heroPage == index ? 20 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _heroPage == index
                                ? AppColors.burgundy
                                : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // Favourites section
            Consumer<FavoritesProvider>(
              builder: (context, favorites, _) {
                final favs = favorites.items;
                if (favs.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.favorite, size: 18, color: Colors.red.shade400),
                            const SizedBox(width: 6),
                            Text(
                              'Your Favourites',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: onSurface,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 100,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: favs.length,
                            itemBuilder: (context, index) {
                              final fav = favs[index];
                              final truckList = mockFoodTrucks.where((t) => t.id == fav.truckId).toList();
                              final t = truckList.isNotEmpty
                                  ? truckList.first
                                  : FoodTruck(
                                      id: fav.truckId,
                                      name: fav.truckName,
                                      cuisine: '',
                                      rating: 0,
                                      imageUrl: '',
                                      isOpen: true,
                                    );
                              return GestureDetector(
                                onTap: () {
                                  context.slideTo(
                                    FoodTruckMenuScreen(truck: t),
                                    direction: SlideDirection.right,
                                  );
                                },
                                child: Container(
                                  width: 100,
                                  margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    color: surfaceColor,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.burgundy.withOpacity(0.08),
                                        blurRadius: 14,
                                        offset: const Offset(0, 5),
                                      ),
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: (fav.menuItem.imageUrl != null &&
                                                fav.menuItem.imageUrl!.isNotEmpty)
                                            ? Image.network(
                                                fav.menuItem.imageUrl!,
                                                fit: BoxFit.cover,
                                                width: double.infinity,
                                                errorBuilder: (_, __, ___) => _buildFavPlaceholder(context),
                                              )
                                            : _buildFavPlaceholder(context),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Text(
                                          fav.menuItem.name,
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            // Section title
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                child: Text(
                  'All Food Trucks',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: onSurface,
                  ),
                ),
              ),
            ),

            // Vertical list of truck cards
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: Duration(milliseconds: 500 + (index * 80)),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) => Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 15 * (1 - value)),
                          child: child,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _ListTruckCard(truck: featuredTrucks[index]),
                      ),
                    );
                  },
                  childCount: featuredTrucks.length,
                ),
              ),
            ),

            // GIU logo at bottom, centered (extra bottom padding so it stays above nav bar)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(
                  top: 32,
                  bottom: 24 + MediaQuery.of(context).padding.bottom + 72,
                ),
                child: Center(
                  child: Image.asset(
                    'giu logo.png',
                    height: 36,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Hero carousel card: menu item image, dish + truck names, opens item detail.
class _PopularMenuHeroCard extends StatelessWidget {
  final PopularMenuSlide slide;

  const _PopularMenuHeroCard({required this.slide});

  @override
  Widget build(BuildContext context) {
    final truck = slide.truck;
    final item = slide.item;
    final imageUrl = (item.imageUrl ?? '').trim();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('food_trucks')
          .doc(truck.id)
          .snapshots(),
      builder: (context, snapshot) {
        final liveDoc = snapshot.data?.data() as Map<String, dynamic>?;
        final openRaw = liveDoc?['isOpen'];
        final isOpen = openRaw is bool ? openRaw : truck.isOpen;
        final truckLabel =
            PopularMenuService.displayTruckNameForHero(truck.id, liveDoc, truck.name);
        return GestureDetector(
          onTap: isOpen
              ? () {
                  context.slideTo(
                    MenuItemDetailScreen(item: item, truck: truck),
                    direction: SlideDirection.right,
                  );
                }
              : null,
          child: AnimatedOpacity(
            opacity: isOpen ? 1 : 0.72,
            duration: const Duration(milliseconds: 200),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _heroItemPlaceholder(context),
                        )
                      : _heroItemPlaceholder(context),
                ),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.78),
                      ],
                      stops: const [0.35, 1.0],
                    ),
                  ),
                ),
                if (slide.orderCount > 0)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${slide.orderCount} orders',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isOpen)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade600,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Open',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Closed',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        item.name,
                        style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        truckLabel,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withOpacity(0.92),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'EGP ${item.price.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _heroItemPlaceholder(BuildContext context) {
    return Container(
      color: Colors.grey.shade300,
      child: Icon(Icons.fastfood, size: 56, color: Colors.grey.shade500),
    );
  }
}

/// Full-width list card for vertical scroll
class _ListTruckCard extends StatelessWidget {
  final FoodTruck truck;

  const _ListTruckCard({required this.truck});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('food_trucks')
          .doc(truck.id)
          .snapshots(),
      builder: (context, snapshot) {
        final isOpen = (snapshot.data?.data() as Map<String, dynamic>?)?['isOpen'] ?? truck.isOpen;
        return GestureDetector(
          onTap: isOpen
              ? () {
                  context.slideTo(
                    FoodTruckMenuScreen(truck: truck),
                    direction: SlideDirection.right,
                  );
                }
              : null,
          child: AnimatedOpacity(
            opacity: isOpen ? 1 : 0.65,
            duration: const Duration(milliseconds: 200),
            child: Container(
                decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.burgundy.withOpacity(0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Row(
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: truck.imageUrl.isNotEmpty
                        ? Image.network(
                            truck.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _placeholder(context),
                          )
                        : _placeholder(context),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  truck.name,
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isOpen
                                      ? Colors.green.shade50
                                      : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isOpen ? 'Open' : 'Closed',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isOpen
                                        ? Colors.green.shade700
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            truck.cuisine,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: Icon(Icons.chevron_right, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      color: Colors.grey.shade200,
      child: Icon(Icons.restaurant, size: 40, color: Colors.grey.shade400),
    );
  }
}
