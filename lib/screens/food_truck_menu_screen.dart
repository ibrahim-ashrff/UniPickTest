import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/mock_food_trucks.dart';
import '../data/mock_menu.dart';
import '../models/food_truck.dart';
import '../models/menu_item.dart';
import '../state/cart_provider.dart';
import '../state/favorites_provider.dart';
import '../utils/app_colors.dart';
import '../utils/page_transitions.dart';
import 'cart_screen.dart';
import 'menu_item_detail_screen.dart';

const String _kMenuAllCategory = 'All';

/// Food truck menu screen with hero layout, category tabs, menu items with hearts, and favourites
class FoodTruckMenuScreen extends StatefulWidget {
  final FoodTruck truck;

  const FoodTruckMenuScreen({
    super.key,
    required this.truck,
  });

  @override
  State<FoodTruckMenuScreen> createState() => _FoodTruckMenuScreenState();
}

class _FoodTruckMenuScreenState extends State<FoodTruckMenuScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  final Map<String, GlobalKey> _sectionKeys = {};
  final ScrollController _scrollController = ScrollController();
  /// Scroll [ensureVisible] target for the top of the menu body (used by "All" chip).
  final GlobalKey _menuBodyAnchorKey = GlobalKey();
  /// Tracks mini-cart visibility so we only run the slide animation when it toggles, not on every cart line change.
  bool? _prevMiniCartVisible;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<String> _getTruckCategories(Map<String, dynamic>? truckData) {
    final list = truckData?['categories'];
    if (list is List) {
      return list.map((e) => e.toString()).toList();
    }
    return menuCategories;
  }

  void _scrollToCategory(String category) {
    final key = _sectionKeys[category];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        // Place section top (category title) a little below viewport top — clears overlap with transparent app bar.
        alignment: 0.12,
      );
    }
  }

  void _onMenuCategoryNav(String category) {
    if (category == _kMenuAllCategory) {
      final ctx = _menuBodyAnchorKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.02,
        );
      }
    } else {
      _scrollToCategory(category);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shouldShowMiniCart = context.select<CartProvider, bool>(
      (c) => c.items.isNotEmpty && c.currentTruckId == widget.truck.id,
    );

    if (_prevMiniCartVisible != shouldShowMiniCart) {
      _prevMiniCartVisible = shouldShowMiniCart;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (shouldShowMiniCart) {
          if (_animationController.status != AnimationStatus.completed) {
            _animationController.forward();
          }
        } else {
          if (_animationController.status != AnimationStatus.dismissed) {
            _animationController.reverse();
          }
        }
      });
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(child: _HeroSection(truck: widget.truck)),
              SliverToBoxAdapter(
                child: KeyedSubtree(
                  key: _menuBodyAnchorKey,
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('food_trucks')
                        .doc(widget.truck.id)
                        .snapshots(),
                    builder: (context, truckSnapshot) {
                    final truckData = truckSnapshot.data?.data() as Map<String, dynamic>?;
                    final truckCategoryOrder = _getTruckCategories(truckData);

                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('food_trucks')
                          .doc(widget.truck.id)
                          .collection('menu_items')
                          .snapshots(),
                      builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Error loading menu: ${snapshot.error}',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      );
                    }

                    final items = (snapshot.data?.docs ?? []).map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return MenuItem(
                        id: doc.id,
                        name: data['name'] ?? '',
                        description: data['description'] ?? '',
                        price: (data['price'] ?? 0.0).toDouble(),
                        imageUrl: ((data['imageUrl'] ?? '').toString().trim().isNotEmpty)
                            ? data['imageUrl']
                            : defaultMenuImageFor(
                                (data['name'] ?? '').toString(),
                                (data['category'] ?? 'Sides').toString(),
                              ),
                        category: data['category'] ?? 'Sides',
                      );
                    }).toList();

                    if (items.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.restaurant_menu, size: 64, color: AppColors.grey),
                              const SizedBox(height: 16),
                              Text(
                                'No menu items available',
                                style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    // Group by category
                    final grouped = <String, List<MenuItem>>{};
                    for (final item in items) {
                      final cat = item.category;
                      grouped.putIfAbsent(cat, () => []).add(item);
                    }
                    // Order: truck's categories first, then any others from items
                    final orderedCats = <String>[];
                    for (final c in truckCategoryOrder) {
                      if (grouped.containsKey(c)) orderedCats.add(c);
                    }
                    for (final k in grouped.keys) {
                      if (!orderedCats.contains(k)) orderedCats.add(k);
                    }
                    // Ensure section keys exist for scroll-to
                    for (final c in orderedCats) {
                      _sectionKeys.putIfAbsent(c, () => GlobalKey());
                    }

                    return _MenuWithTabs(
                      categories: orderedCats,
                      groupedItems: grouped,
                      truck: widget.truck,
                      sectionKeys: _sectionKeys,
                      onCategoryNav: _onMenuCategoryNav,
                    );
                      },
                    );
                  },
                ),
              ),
            ),
              SliverToBoxAdapter(
                child: Consumer<FavoritesProvider>(
                  builder: (context, favorites, _) {
                    final favs = favorites.items;
                    if (favs.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Favourites',
                                style: GoogleFonts.inter(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.favorite, size: 20, color: Colors.red.shade400),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 140,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: favs.length,
                              itemBuilder: (context, index) {
                                final fav = favs[index];
                                final found = mockFoodTrucks.where((t) => t.id == fav.truckId).toList();
                                final truck = found.isNotEmpty
                                    ? found.first
                                    : FoodTruck(
                                        id: fav.truckId,
                                        name: fav.truckName,
                                        cuisine: '',
                                        rating: 0,
                                        imageUrl: '',
                                        isOpen: true,
                                      );
                                return _FavoriteItemCard(
                                  favorite: fav,
                                  onTap: () {
                                    context.slideTo(
                                      FoodTruckMenuScreen(truck: truck),
                                      direction: SlideDirection.right,
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          if (shouldShowMiniCart)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: _StickyMiniCart(truckId: widget.truck.id),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Two-column menu grid without [GridView.shrinkWrap], which can reserve extra vertical space
/// under section headers. Rows use a fixed cell height from [childAspectRatio].
Widget _menuCategoryItemGrid({
  required List<MenuItem> items,
  required FoodTruck truck,
}) {
  const crossAxisCount = 2;
  const crossSpacing = 12.0;
  const mainSpacing = 12.0;
  const childAspectRatio = 0.72;

  return LayoutBuilder(
    builder: (context, constraints) {
      final maxW = constraints.maxWidth;
      if (maxW <= 0) return const SizedBox.shrink();

      final cellW = (maxW - crossSpacing * (crossAxisCount - 1)) / crossAxisCount;
      final cellH = cellW / childAspectRatio;
      final rowCount = (items.length + crossAxisCount - 1) ~/ crossAxisCount;

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var row = 0; row < rowCount; row++)
            Padding(
              padding: EdgeInsets.only(bottom: row < rowCount - 1 ? mainSpacing : 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: cellW,
                    height: row * 2 < items.length ? cellH : 0,
                    child: row * 2 < items.length
                        ? _MenuItemCard(item: items[row * 2], truck: truck)
                        : null,
                  ),
                  SizedBox(width: crossSpacing),
                  SizedBox(
                    width: cellW,
                    height: row * 2 + 1 < items.length ? cellH : 0,
                    child: row * 2 + 1 < items.length
                        ? _MenuItemCard(item: items[row * 2 + 1], truck: truck)
                        : null,
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );
}

/// Pill chip: white when unselected; selected state is slightly dimmed (grey).
class _CategoryFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: const BoxConstraints(minHeight: 40),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFE6E6E6) : Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: selected ? const Color(0xFFC4C4C4) : const Color(0xFFD8D8D8),
              ),
              boxShadow: selected
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
            ),
            child: Center(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                  color: selected ? const Color(0xFF6E6E6E) : AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
                softWrap: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Menu content with category tabs and sections; [_kMenuAllCategory] shows every section.
class _MenuWithTabs extends StatefulWidget {
  final List<String> categories;
  final Map<String, List<MenuItem>> groupedItems;
  final FoodTruck truck;
  final Map<String, GlobalKey> sectionKeys;
  final void Function(String category) onCategoryNav;

  const _MenuWithTabs({
    required this.categories,
    required this.groupedItems,
    required this.truck,
    required this.sectionKeys,
    required this.onCategoryNav,
  });

  @override
  State<_MenuWithTabs> createState() => _MenuWithTabsState();
}

class _MenuWithTabsState extends State<_MenuWithTabs> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = _kMenuAllCategory;
  }

  @override
  void didUpdateWidget(covariant _MenuWithTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    final valid = {_kMenuAllCategory, ...widget.categories};
    if (!valid.contains(_selected)) {
      setState(() => _selected = _kMenuAllCategory);
    }
  }

  void _onChipTap(String label) {
    setState(() => _selected = label);
    widget.onCategoryNav(label);
  }

  @override
  Widget build(BuildContext context) {
    final tabLabels = [
      _kMenuAllCategory,
      ...widget.categories.where((c) => c != _kMenuAllCategory),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Menu',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              height: 1.2,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: tabLabels
                  .map(
                    (label) => _CategoryFilterChip(
                      label: label,
                      selected: _selected == label,
                      onTap: () => _onChipTap(label),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),
          ...widget.categories.map((cat) {
            final items = widget.groupedItems[cat] ?? [];
            if (items.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  key: widget.sectionKeys[cat],
                  cat,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                _menuCategoryItemGrid(items: items, truck: widget.truck),
                const SizedBox(height: 12),
              ],
            );
          }),
        ],
      ),
    );
  }
}

/// Hero section: large image, name, address, Open/Closed
class _HeroSection extends StatelessWidget {
  final FoodTruck truck;

  const _HeroSection({required this.truck});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final heroHeight = screenHeight * 0.36;

    return SizedBox(
      height: heroHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          truck.imageUrl.isNotEmpty
              ? Image.network(
                  truck.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppColors.burgundy,
                    child: const Icon(Icons.restaurant, size: 80, color: Colors.white54),
                  ),
                )
              : Container(
                  color: AppColors.burgundy,
                  child: const Icon(Icons.restaurant, size: 80, color: Colors.white54),
                ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.6),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                Text(
                  truck.name,
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  truck.description ?? '832 Spadina Blvd.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 16),
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('food_trucks')
                      .doc(truck.id)
                      .snapshots(),
                  builder: (context, snapshot) {
                    final isOpen = (snapshot.data?.data() as Map<String, dynamic>?)?['isOpen'] ?? truck.isOpen;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: isOpen ? Colors.black : Colors.grey.shade700,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        isOpen ? 'Open Now' : 'Closed',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Menu item card - uses Consumer for heart only to avoid full rebuild
class _MenuItemCard extends StatelessWidget {
  final MenuItem item;
  final FoodTruck truck;

  const _MenuItemCard({required this.item, required this.truck});

  void _openDetail(BuildContext context) {
    context.slideTo(
      MenuItemDetailScreen(item: item, truck: truck),
      direction: SlideDirection.right,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: InkWell(
              onTap: () => _openDetail(context),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  item.imageUrl != null && item.imageUrl!.isNotEmpty
                      ? Image.network(
                          item.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildPlaceholder(context),
                        )
                      : _buildPlaceholder(context),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Consumer<FavoritesProvider>(
                      builder: (context, favorites, _) {
                        final isFav = favorites.isFavorite(truck.id, item.id);
                        return GestureDetector(
                          onTap: () => favorites.toggle(item, truck.id, truck.name),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isFav ? Icons.favorite : Icons.favorite_border,
                              size: 20,
                              color: isFav ? Colors.red : Colors.grey.shade600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () => _openDetail(context),
                    child: Text(
                      item.name,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _openDetail(context),
                          child: Text(
                            'EGP ${item.price.toStringAsFixed(0)}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.burgundy,
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () async {
                          final cart = context.read<CartProvider>();
                          final success = cart.addItem(item, truckId: truck.id);
                          if (!success) {
                            final shouldReplace =
                                await _showDifferentTruckDialog(context, item.name);
                            if (shouldReplace == true && context.mounted) {
                              cart.replaceCartAndAddItem(item, truck.id);
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: AppColors.burgundy,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add, color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      color: AppColors.greyLight,
      child: Icon(Icons.fastfood, size: 40, color: AppColors.grey),
    );
  }
}

class _FavoriteItemCard extends StatelessWidget {
  final FavoriteMenuItem favorite;
  final VoidCallback onTap;

  const _FavoriteItemCard({required this.favorite, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final item = favorite.menuItem;
    final imageUrl = item.imageUrl;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 130,
        margin: const EdgeInsets.only(right: 12),
        child: Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_, __, ___) => _placeholder(context),
                      )
                    : _placeholder(context),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      favorite.truckName,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      color: AppColors.greyLight,
      child: Center(child: Icon(Icons.fastfood, size: 32, color: AppColors.grey)),
    );
  }
}

Future<bool?> _showDifferentTruckDialog(BuildContext context, String itemName) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Different Food Truck', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
      content: Text(
        'Your cart contains items from another food truck.\n\n'
        'Would you like to delete the old cart and add "$itemName"?',
        style: GoogleFonts.inter(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text('Keep Old Cart', style: GoogleFonts.inter(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.burgundy, foregroundColor: Colors.white),
          child: Text('Delete Old Cart & Add New Item', style: GoogleFonts.inter()),
        ),
      ],
    ),
  );
}

class _StickyMiniCart extends StatefulWidget {
  final String truckId;

  const _StickyMiniCart({required this.truckId});

  @override
  State<_StickyMiniCart> createState() => _StickyMiniCartState();
}

class _StickyMiniCartState extends State<_StickyMiniCart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _scaleAnimation;
  /// Total quantity last time we built; -1 = hidden / reset. Bump runs when qty increases while already showing.
  int _prevTotalQty = -1;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.07).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOutCubic),
    );
    _pulseController.addStatusListener(_onPulseStatus);
  }

  void _onPulseStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      _pulseController.reverse();
    }
  }

  @override
  void dispose() {
    _pulseController.removeStatusListener(_onPulseStatus);
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cart, _) {
        if (cart.items.isEmpty || cart.currentTruckId != widget.truckId) {
          _prevTotalQty = -1;
          return const SizedBox.shrink();
        }

        final qty = cart.itemCount;
        if (qty > _prevTotalQty && _prevTotalQty >= 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _pulseController.forward(from: 0);
            }
          });
        }
        _prevTotalQty = qty;

        return ScaleTransition(
          scale: _scaleAnimation,
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            top: false,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.burgundy.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.shopping_cart, color: AppColors.burgundy, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${cart.itemCount} ${cart.itemCount == 1 ? 'item' : 'items'} • EGP ${cart.subtotal.toStringAsFixed(0)}',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          cart.items.length <= 3
                              ? cart.items.map((i) => '${i.quantity}x ${i.menuItem.name}').join(', ')
                              : '${cart.items.take(2).map((i) => '${i.quantity}x ${i.menuItem.name}').join(', ')}, +${cart.items.length - 2} more',
                          style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => context.slideTo(const CartScreen(), direction: SlideDirection.right),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.burgundy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: Text('View Cart', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
