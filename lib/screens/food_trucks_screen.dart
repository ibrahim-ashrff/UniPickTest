import 'package:flutter/material.dart';
import '../models/food_truck.dart';
import '../data/mock_food_trucks.dart';
import 'menu_screen.dart';

/// Food Trucks screen displaying all available food trucks
class FoodTrucksScreen extends StatelessWidget {
  const FoodTrucksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Food Trucks',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: mockFoodTrucks.length,
        itemBuilder: (context, index) {
          return _FoodTruckListItem(truck: mockFoodTrucks[index]);
        },
      ),
    );
  }
}

/// Food truck list item with horizontal layout
class _FoodTruckListItem extends StatelessWidget {
  final FoodTruck truck;

  const _FoodTruckListItem({required this.truck});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const MenuScreen(),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // Food truck image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 80,
                  height: 80,
                  color: Colors.grey[300],
                  child: truck.imageUrl.isNotEmpty
                      ? Image.network(
                          truck.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.restaurant,
                            color: Colors.grey,
                          ),
                        )
                      : const Icon(
                          Icons.restaurant,
                          size: 40,
                          color: Colors.grey,
                        ),
                ),
              ),
              const SizedBox(width: 16),
              // Food truck info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      truck.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      truck.cuisine,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              // Arrow icon
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

