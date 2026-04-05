import 'package:flutter/foundation.dart';
import '../models/menu_item.dart';

/// A favorited menu item with truck context for display
class FavoriteMenuItem {
  final MenuItem menuItem;
  final String truckId;
  final String truckName;

  FavoriteMenuItem({
    required this.menuItem,
    required this.truckId,
    required this.truckName,
  });

  String get key => '${truckId}_${menuItem.id}';
}

class FavoritesProvider extends ChangeNotifier {
  final Map<String, FavoriteMenuItem> _favorites = {};

  List<FavoriteMenuItem> get items => _favorites.values.toList();

  bool isFavorite(String truckId, String menuItemId) {
    return _favorites.containsKey('${truckId}_$menuItemId');
  }

  void toggle(MenuItem item, String truckId, String truckName) {
    final key = '${truckId}_${item.id}';
    if (_favorites.containsKey(key)) {
      _favorites.remove(key);
    } else {
      _favorites[key] = FavoriteMenuItem(
        menuItem: item,
        truckId: truckId,
        truckName: truckName,
      );
    }
    notifyListeners();
  }

  void remove(String truckId, String menuItemId) {
    _favorites.remove('${truckId}_$menuItemId');
    notifyListeners();
  }
}
