class FoodTruck {
  final String id;
  final String name;
  final String cuisine;
  final double rating;
  final String imageUrl;
  final String? description;
  final bool isOpen;
  final String? ownerId; // ID of the truck owner user

  FoodTruck({
    required this.id,
    required this.name,
    required this.cuisine,
    required this.rating,
    required this.imageUrl,
    this.description,
    this.isOpen = true,
    this.ownerId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'cuisine': cuisine,
      'rating': rating,
      'imageUrl': imageUrl,
      'description': description,
      'isOpen': isOpen,
      'ownerId': ownerId,
    };
  }

  factory FoodTruck.fromJson(Map<String, dynamic> json) {
    return FoodTruck(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      cuisine: json['cuisine'] ?? '',
      rating: (json['rating'] ?? 0.0).toDouble(),
      imageUrl: json['imageUrl'] ?? '',
      description: json['description'],
      isOpen: json['isOpen'] ?? true,
      ownerId: json['ownerId'],
    );
  }
}

