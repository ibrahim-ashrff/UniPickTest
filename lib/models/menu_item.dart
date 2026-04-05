class MenuItem {
  final String id;
  final String name;
  final String description;
  final double price;
  final String? imageUrl;
  final String category;

  MenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.imageUrl,
    this.category = 'Sides',
  });
}

/// Predefined menu categories
const List<String> menuCategories = ['Beverages', 'Sandwiches', 'Sides'];




