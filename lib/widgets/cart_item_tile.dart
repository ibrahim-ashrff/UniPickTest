import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cart_item.dart';
import '../state/cart_provider.dart';
import 'item_thumbnail.dart';

class CartItemTile extends StatelessWidget {
  final CartItem cartItem;

  const CartItemTile({
    super.key,
    required this.cartItem,
  });

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: ItemThumbnail(
          imageUrl: cartItem.menuItem.imageUrl,
          size: 56,
        ),
        title: Text(
          cartItem.menuItem.name,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          'EGP ${cartItem.menuItem.price.toStringAsFixed(0)} each',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: () {
                cart.updateQuantity(
                  cartItem.menuItem.id,
                  cartItem.quantity - 1,
                );
              },
            ),
            Text(
              '${cartItem.quantity}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () {
                cart.updateQuantity(
                  cartItem.menuItem.id,
                  cartItem.quantity + 1,
                );
              },
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              color: Colors.red,
              onPressed: () {
                cart.removeItem(cartItem.menuItem.id);
              },
            ),
          ],
        ),
      ),
    );
  }
}




