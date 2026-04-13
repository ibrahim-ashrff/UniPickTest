import 'package:flutter/foundation.dart';
import '../models/cart_item.dart';
import '../models/menu_item.dart';

class CartProvider extends ChangeNotifier {
  /// Flat fee added at checkout (Fawry charge, receipts). Not included in [subtotal].
  static const double unipickFeeAmount = 8.0;

  final List<CartItem> _items = [];
  String? _currentTruckId; // Track which food truck the cart is for

  List<CartItem> get items => List.unmodifiable(_items);
  String? get currentTruckId => _currentTruckId;

  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  double get subtotal => _items.fold(0.0, (sum, item) => sum + item.total);

  double get unipickFees => unipickFeeAmount;

  /// Items subtotal + UniPick fee — use on checkout and payment only.
  double get checkoutTotal => subtotal + unipickFeeAmount;

  /// Returns true if item was added successfully, false if different truck detected
  bool addItem(MenuItem menuItem, {String? truckId}) {
    // If cart has items and trying to add from different truck
    if (_items.isNotEmpty && _currentTruckId != null && truckId != null && _currentTruckId != truckId) {
      return false; // Indicates different truck
    }
    
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
    return true; // Successfully added
  }
  
  /// Clear cart and add new item from different truck
  void replaceCartAndAddItem(MenuItem menuItem, String truckId) {
    _items.clear();
    _currentTruckId = truckId;
    _items.add(CartItem(menuItem: menuItem, quantity: 1));
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

