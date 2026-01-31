import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/food_truck.dart';
import '../models/menu_item.dart';
import '../state/cart_provider.dart';
import '../utils/app_colors.dart';
import '../utils/page_transitions.dart';
import 'cart_screen.dart';

/// Food truck menu screen displaying menu items for a specific food truck
/// Follows burgundy + white theme with modern card UI
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.truck.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              widget.truck.cuisine,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.9),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: Consumer<CartProvider>(
        builder: (context, cart, child) {
          // Show/hide animation based on cart state
          final shouldShow = cart.items.isNotEmpty && cart.currentTruckId == widget.truck.id;
          
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (shouldShow && _animationController.status != AnimationStatus.completed) {
              _animationController.forward();
            } else if (!shouldShow && _animationController.status != AnimationStatus.dismissed) {
              _animationController.reverse();
            }
          });

          return Stack(
            children: [
              Column(
                children: [
                  // Food truck header card
                  Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Stack(
                        children: [
                          // Truck image
                          Container(
                            height: 150,
                            width: double.infinity,
                            color: AppColors.greyLight,
                            child: widget.truck.imageUrl.isNotEmpty
                                ? Image.network(
                                    widget.truck.imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.restaurant,
                                      size: 60,
                                      color: AppColors.grey,
                                    ),
                                  )
                                : const Icon(
                                    Icons.restaurant,
                                    size: 60,
                                    color: AppColors.grey,
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Menu items list - load from Firestore (real-time updates from truck owner)
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('food_trucks')
                          .doc(widget.truck.id)
                          .collection('menu_items')
                          .orderBy('name')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Error loading menu: ${snapshot.error}',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          );
                        }

                        // Always use Firestore data (truck owner's menu)
                        final itemsToShow = snapshot.data?.docs.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return MenuItem(
                            id: doc.id,
                            name: data['name'] ?? '',
                            description: data['description'] ?? '',
                            price: (data['price'] ?? 0.0).toDouble(),
                            imageUrl: data['imageUrl'],
                          );
                        }).toList() ?? [];
                        
                        if (itemsToShow.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.restaurant_menu,
                                  size: 64,
                                  color: AppColors.grey,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No menu items available',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        
                        return ListView.builder(
                          padding: EdgeInsets.only(
                            left: 16,
                            right: 16,
                            bottom: (cart.items.isNotEmpty && cart.currentTruckId == widget.truck.id) ? 90 : 16, // Add padding for mini cart
                          ),
                          itemCount: itemsToShow.length,
                          itemBuilder: (context, index) {
                            final item = itemsToShow[index];
                            return _MenuItemCard(item: item, truckId: widget.truck.id);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
              // Sticky Mini Cart - only show if cart has items for this truck
              if (shouldShow)
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
          );
        },
      ),
    );
  }
}

/// Menu item card widget
class _MenuItemCard extends StatelessWidget {
  final MenuItem item;
  final String truckId;

  const _MenuItemCard({required this.item, required this.truckId});

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item image placeholder
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.greyLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.fastfood,
                size: 40,
                color: AppColors.grey,
              ),
            ),
            const SizedBox(width: 16),
            // Item details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'EGP ${item.price.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.burgundy,
                    ),
                  ),
                ],
              ),
            ),
            // Add button
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.burgundy,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              onPressed: () async {
                final success = cart.addItem(item, truckId: truckId);
                if (!success) {
                  // Different truck detected, show dialog
                  final shouldReplace = await _showDifferentTruckDialog(context, item.name);
                  if (shouldReplace == true) {
                    cart.replaceCartAndAddItem(item, truckId);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${item.name} added to cart'),
                          duration: const Duration(seconds: 1),
                          backgroundColor: AppColors.burgundy,
                        ),
                      );
                    }
                  }
                  // If shouldReplace is false or null, user chose to keep old cart
                } else {
                  // Successfully added
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${item.name} added to cart'),
                        duration: const Duration(seconds: 1),
                        backgroundColor: AppColors.burgundy,
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows a dialog when user tries to add item from different food truck
Future<bool?> _showDifferentTruckDialog(BuildContext context, String itemName) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        'Different Food Truck',
        style: GoogleFonts.inter(
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Text(
        'You cannot add items from different food trucks.\n\n'
        'Your cart contains items from another food truck.\n\n'
        'Would you like to delete the old cart and add "$itemName"?',
        style: GoogleFonts.inter(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Keep Old Cart',
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.burgundy,
            foregroundColor: Colors.white,
          ),
          child: Text(
            'Delete Old Cart & Add New Item',
            style: GoogleFonts.inter(),
          ),
        ),
      ],
    ),
  );
}

/// Sticky mini cart widget that appears at the bottom of the menu screen
class _StickyMiniCart extends StatelessWidget {
  final String truckId;

  const _StickyMiniCart({required this.truckId});

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cart, child) {
        // Don't show if cart is empty
        if (cart.items.isEmpty) {
          return const SizedBox.shrink();
        }

        // Only show if cart is for this truck
        if (cart.currentTruckId != truckId) {
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
                // Cart icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.burgundy.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.shopping_cart,
                    color: AppColors.burgundy,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                // Cart summary
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${cart.itemCount} ${cart.itemCount == 1 ? 'item' : 'items'} • EGP ${cart.total.toStringAsFixed(0)}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Show latest added items
                      if (cart.items.length <= 3)
                        Text(
                          cart.items
                              .map((item) => '${item.quantity}x ${item.menuItem.name}')
                              .join(', '),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      else
                        Text(
                          '${cart.items.take(2).map((item) => '${item.quantity}x ${item.menuItem.name}').join(', ')}, +${cart.items.length - 2} more',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // View Cart button
                ElevatedButton(
                  onPressed: () {
                    context.slideTo(
                      const CartScreen(),
                      direction: SlideDirection.right,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.burgundy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'View Cart',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

