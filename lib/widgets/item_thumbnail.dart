import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

/// Shows a menu item image (network) or a consistent placeholder when URL is missing.
/// Use for cart, checkout, receipt, lists, etc.
class ItemThumbnail extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final BorderRadius? borderRadius;

  const ItemThumbnail({
    super.key,
    this.imageUrl,
    this.size = 56,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(8);
    final hasValidUrl = imageUrl != null && imageUrl!.trim().isNotEmpty;
    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: size,
        height: size,
        child: hasValidUrl
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder(context),
              )
            : _placeholder(context),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      color: AppColors.greyLight,
      child: Icon(Icons.fastfood, size: size * 0.5, color: AppColors.grey),
    );
  }
}
