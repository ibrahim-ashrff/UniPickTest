import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/mock_food_trucks.dart';
import '../models/food_truck.dart';
import '../models/menu_item.dart';
import '../state/cart_provider.dart';
import '../state/favorites_provider.dart';
import '../utils/app_colors.dart';
import '../utils/page_transitions.dart';
import 'cart_screen.dart';
import 'menu_item_detail_screen.dart';

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
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final shouldShowMiniCart = cart.items.isNotEmpty && cart.currentTruckId == widget.truck.id;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (shouldShowMiniCart && _animationController.status != AnimationStatus.completed) {
        _animationController.forward();
      } else if (!shouldShowMiniCart && _animationController.status != AnimationStatus.dismissed) {
        _animationController.reverse();
      }
    });

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
                        imageUrl: data['imageUrl'],
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
                      onCategoryTap: _scrollToCategory,
                    );
                  },
                );
              },
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

/// Menu content with category tabs and sections
class _MenuWithTabs extends StatelessWidget {
  final List<String> categories;
  final Map<String, List<MenuItem>> groupedItems;
  final FoodTruck truck;
  final Map<String, GlobalKey> sectionKeys;
  final void Function(String) onCategoryTap;

  const _MenuWithTabs({
    required this.categories,
    required this.groupedItems,
    required this.truck,
    required this.sectionKeys,
    required this.onCategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Menu',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          // Category tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: categories.map((cat) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(cat),
                    onPressed: () => onCategoryTap(cat),
                    backgroundColor: AppColors.burgundy.withOpacity(0.1),
                    labelStyle: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.burgundy,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          // Category sections
          ...categories.map((cat) {
            final items = groupedItems[cat] ?? [];
            if (items.isEmpty) return const SizedBox.shrink();
            return Column(
              key: sectionKeys[cat],
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cat,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    return _MenuItemCard(item: items[index], truck: truck);
                  },
                ),
                const SizedBox(height: 16),
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

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    return InkWell(
      onTap: () {
        context.slideTo(
          MenuItemDetailScreen(item: item, truck: truck),
          direction: SlideDirection.right,
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
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
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item.name,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'EGP ${item.price.toStringAsFixed(0)}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.burgundy,
                        ),
                      ),
                      GestureDetector(
                        onTap: () async {
                          final success = cart.addItem(item, truckId: truck.id);
                          if (!success) {
                            final shouldReplace = await _showDifferentTruckDialog(context, item.name);
                            if (shouldReplace == true) {
                              cart.replaceCartAndAddItem(item, truck.id);
                            }
                          }
                          // No snackbar: the view-cart bar at bottom shows automatically
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
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

class _StickyMiniCart extends StatelessWidget {
  final String truckId;

  const _StickyMiniCart({required this.truckId});

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cart, _) {
        if (cart.items.isEmpty || cart.currentTruckId != truckId) {
          return const SizedBox.shrink();
        }
        return SafeArea(
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
                        '${cart.itemCount} ${cart.itemCount == 1 ? 'item' : 'items'} • EGP ${cart.total.toStringAsFixed(0)}',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
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
        );
      },
    );
  }
}
