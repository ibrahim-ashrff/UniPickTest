import 'package:flutter/foundation.dart';
import '../models/cart_item.dart';
import '../models/menu_item.dart';

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];
  String? _currentTruckId; // Track which food truck the cart is for

  List<CartItem> get items => List.unmodifiable(_items);
  String? get currentTruckId => _currentTruckId;

  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  double get subtotal => _items.fold(0.0, (sum, item) => sum + item.total);

  double get total => subtotal; // Can add tax/service fee here later

  void addItem(MenuItem menuItem, {String? truckId}) {
    // Set truck ID if provided and cart is empty
    if (_items.isEmpty && truckId != null) {
      _currentTruckId = truckId;
    }
    
    final existingIndex = _items.indexWhere(
      (item) => item.menuItem.id == menuItem.id,
    );

    if (existingIndex >= 0) {
      _items[existingIndex].quantity++;
    } else {
      _items.add(CartItem(menuItem: menuItem, quantity: 1));
    }
    notifyListeners();
  }

  void removeItem(String menuItemId) {
    _items.removeWhere((item) => item.menuItem.id == menuItemId);
    notifyListeners();
  }

  void updateQuantity(String menuItemId, int quantity) {
    if (quantity <= 0) {
      removeItem(menuItemId);
      return;
    }

    final index = _items.indexWhere((item) => item.menuItem.id == menuItemId);
    if (index >= 0) {
      _items[index].quantity = quantity;
      notifyListeners();
    }
  }

  void clear() {
    _items.clear();
    _currentTruckId = null;
    notifyListeners();
  }
  
  void setTruckId(String truckId) {
    _currentTruckId = truckId;
    notifyListeners();
  }
}

