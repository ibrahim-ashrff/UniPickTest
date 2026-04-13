import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/mock_menu.dart';
import '../models/menu_item.dart';
import '../state/cart_provider.dart';
import '../utils/app_colors.dart';
import 'item_thumbnail.dart';

/// Horizontal "You might also like…" strip: random-ish picks from the same truck menu
/// (excluding items already in the cart). Order is stable for a given truck + cart + menu snapshot.
List<MenuItem> pickCartSuggestions({
  required String truckId,
  required List<MenuItem> fullMenu,
  required Set<String> cartMenuItemIds,
  int maxItems = 12,
}) {
  final pool = fullMenu.where((m) => !cartMenuItemIds.contains(m.id)).toList();
  if (pool.isEmpty) return [];
  final ids = pool.map((m) => m.id).toList()..sort();
  final seedKey = '$truckId|${ids.join('|')}|${pool.length}';
  pool.shuffle(Random(seedKey.hashCode));
  return pool.take(maxItems).toList();
}

class CartSuggestionsSection extends StatelessWidget {
  final String truckId;
  final Set<String> cartMenuItemIds;

  const CartSuggestionsSection({
    super.key,
    required this.truckId,
    required this.cartMenuItemIds,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('food_trucks')
          .doc(truckId)
          .collection('menu_items')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const SizedBox.shrink();

        final all = docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return MenuItem(
            id: doc.id,
            name: data['name'] ?? '',
            description: data['description'] ?? '',
            price: (data['price'] ?? 0.0).toDouble(),
            imageUrl: ((data['imageUrl'] ?? '').toString().trim().isNotEmpty)
                ? data['imageUrl'] as String?
                : defaultMenuImageFor(
                    (data['name'] ?? '').toString(),
                    (data['category'] ?? 'Sides').toString(),
                  ),
            category: data['category'] ?? 'Sides',
          );
        }).toList();

        final suggestions = pickCartSuggestions(
          truckId: truckId,
          fullMenu: all,
          cartMenuItemIds: cartMenuItemIds,
        );
        if (suggestions.isEmpty) return const SizedBox.shrink();

        const panelColor = Color(0xFFF7F2EA);

        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: ColoredBox(
              color: panelColor,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 0, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'You might also like…',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 168,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(right: 16),
                        itemCount: suggestions.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          return _SuggestionTile(
                            item: suggestions[index],
                            truckId: truckId,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  final MenuItem item;
  final String truckId;

  const _SuggestionTile({
    required this.item,
    required this.truckId,
  });

  @override
  Widget build(BuildContext context) {
    const imageSize = 104.0;
    const cardWidth = 118.0;

    return SizedBox(
      width: cardWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ItemThumbnail(
                imageUrl: item.imageUrl,
                size: imageSize,
                borderRadius: BorderRadius.circular(14),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 2,
                  shadowColor: Colors.black26,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      final cart = context.read<CartProvider>();
                      final ok = cart.addItem(item, truckId: truckId);
                      if (!context.mounted) return;
                      if (!ok) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Clear your cart to add items from another truck.',
                            ),
                          ),
                        );
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.add,
                        size: 20,
                        color: AppColors.burgundy,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.2,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'EGP ${item.price.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
