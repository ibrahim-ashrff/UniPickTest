import '../models/menu_item.dart';

// Placeholder images (Unsplash) so menu items always show a picture
const _burger = 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=400';
const _chicken = 'https://images.unsplash.com/photo-1606755962773-d324e0a13086?w=400';
const _fries = 'https://images.unsplash.com/photo-1573080496219-bb080dd4f877?w=400';
const _drink = 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?w=400';
const _pizza = 'https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=400';
const _salad = 'https://images.unsplash.com/photo-1546793665-c74683f339c1?w=400';
const _coffee = 'https://images.unsplash.com/photo-1572442388796-11668a67e53d?w=400';
const _cake = 'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=400';

String defaultMenuImageFor(String name, String category) {
  final n = name.toLowerCase();
  final c = category.toLowerCase();

  if (n.contains('burger')) return _burger;
  if (n.contains('chicken')) return _chicken;
  if (n.contains('fries') || n.contains('potato')) return _fries;
  if (n.contains('pizza')) return _pizza;
  if (n.contains('salad')) return _salad;
  if (n.contains('coffee') || n.contains('latte') || n.contains('cappuccino')) {
    return _coffee;
  }
  if (n.contains('cake') || n.contains('dessert') || n.contains('chocolate')) {
    return _cake;
  }
  if (c.contains('beverage') || c.contains('drink')) return _drink;
  if (c.contains('sandwich')) return _burger;
  if (c.contains('side')) return _fries;

  return _burger;
}

final List<MenuItem> mockMenuItems = [
  MenuItem(id: '1', name: 'Classic Burger', description: 'Beef patty with lettuce, tomato, and special sauce', price: 45.0, category: 'Sandwiches', imageUrl: _burger),
  MenuItem(id: '2', name: 'Chicken Burger', description: 'Grilled chicken with mayo and pickles', price: 40.0, category: 'Sandwiches', imageUrl: _chicken),
  MenuItem(id: '3', name: 'French Fries', description: 'Crispy golden fries', price: 15.0, category: 'Sides', imageUrl: _fries),
  MenuItem(id: '4', name: 'Soft Drink', description: 'Coca Cola, Pepsi, or Sprite', price: 10.0, category: 'Beverages', imageUrl: _drink),
  MenuItem(id: '5', name: 'Pizza Margherita', description: 'Classic tomato, mozzarella, and basil', price: 60.0, category: 'Sandwiches', imageUrl: _pizza),
  MenuItem(id: '6', name: 'Caesar Salad', description: 'Romaine lettuce, croutons, parmesan, caesar dressing', price: 35.0, category: 'Sides', imageUrl: _salad),
  MenuItem(id: '7', name: 'Cappuccino', description: 'Rich espresso with steamed milk', price: 25.0, category: 'Beverages', imageUrl: _coffee),
  MenuItem(id: '8', name: 'Chocolate Cake', description: 'Decadent chocolate layer cake', price: 35.0, category: 'Sides', imageUrl: _cake),
];




