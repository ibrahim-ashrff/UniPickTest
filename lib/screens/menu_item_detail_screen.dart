import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/menu_item.dart';
import '../models/food_truck.dart';
import '../state/cart_provider.dart';
import '../state/favorites_provider.dart';
import '../utils/app_colors.dart';
import '../utils/page_transitions.dart';
import 'cart_screen.dart';

/// Expanded view for a single menu item: large image, description, add to cart.
/// Opened when tapping a menu item card (not the plus) or a search result.
class MenuItemDetailScreen extends StatelessWidget {
  final MenuItem item;
  final FoodTruck truck;

  const MenuItemDetailScreen({
    super.key,
    required this.item,
    required this.truck,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              Consumer<FavoritesProvider>(
                builder: (context, favorites, _) {
                  final isFav = favorites.isFavorite(truck.id, item.id);
                  return IconButton(
                    icon: Icon(
                      isFav ? Icons.favorite : Icons.favorite_border,
                      color: isFav ? Colors.red : null,
                    ),
                    onPressed: () =>
                        favorites.toggle(item, truck.id, truck.name),
                  );
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _HeroImage(item: item),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    truck.name,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.description,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            height: 1.45,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.85),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Text(
                        'EGP ${item.price.toStringAsFixed(0)}',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.burgundy,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final cart = context.read<CartProvider>();
                        final success = cart.addItem(item, truckId: truck.id);
                        if (!success) {
                          final shouldReplace = await _showDifferentTruckDialog(
                              context, item.name);
                          if (shouldReplace == true && context.mounted) {
                            cart.replaceCartAndAddItem(item, truck.id);
                          }
                        }
                        if (context.mounted && cart.items.isNotEmpty) {
                          _showViewCartSheet(context, item.id);
                        }
                      },
                      icon: const Icon(Icons.add_shopping_cart, size: 22),
                      label: const Text('Add to cart'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.burgundy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Future<bool?> _showDifferentTruckDialog(
      BuildContext context, String itemName) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Different truck'),
        content: Text(
          'Your cart has items from another truck. Add "$itemName" and clear the cart?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Replace cart'),
          ),
        ],
      ),
    );
  }

  static void _showViewCartSheet(BuildContext context, String menuItemId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Consumer<CartProvider>(
        builder: (context, cart, _) {
          if (cart.items.isEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (sheetContext.mounted && Navigator.of(sheetContext).canPop()) {
                Navigator.of(sheetContext).pop();
              }
            });
            return const SizedBox.shrink();
          }
          final detailIdx = cart.items.indexWhere((e) => e.menuItem.id == menuItemId);
          final detailQty = detailIdx >= 0 ? cart.items[detailIdx].quantity : 0;
          return SafeArea(
            top: false,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${cart.itemCount} ${cart.itemCount == 1 ? 'item' : 'items'} • EGP ${cart.subtotal.toStringAsFixed(0)}',
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
                  if (detailQty > 0) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      icon: Icon(Icons.remove_circle_outline, color: AppColors.burgundy, size: 24),
                      onPressed: () {
                        final c = context.read<CartProvider>();
                        final idx = c.items.indexWhere((e) => e.menuItem.id == menuItemId);
                        if (idx < 0) return;
                        final q = c.items[idx].quantity;
                        if (q <= 1) {
                          c.removeItem(menuItemId);
                        } else {
                          c.updateQuantity(menuItemId, q - 1);
                        }
                      },
                    ),
                    SizedBox(
                      width: 22,
                      child: Text(
                        '$detailQty',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      icon: Icon(Icons.add_circle_outline, color: AppColors.burgundy, size: 24),
                      onPressed: () {
                        final c = context.read<CartProvider>();
                        final idx = c.items.indexWhere((e) => e.menuItem.id == menuItemId);
                        if (idx < 0) return;
                        c.updateQuantity(menuItemId, c.items[idx].quantity + 1);
                      },
                    ),
                  ],
                  const SizedBox(width: 4),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      sheetContext.slideTo(const CartScreen(), direction: SlideDirection.right);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.burgundy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
      ),
    );
  }
}

class _HeroImage extends StatelessWidget {
  final MenuItem item;

  const _HeroImage({required this.item});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
          Image.network(
            item.imageUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _placeholder(context),
          )
        else
          _placeholder(context),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withOpacity(0.3),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      color: AppColors.greyLight,
      child: Icon(Icons.fastfood, size: 64, color: AppColors.grey),
    );
  }
}
