import '../models/food_truck.dart';

// Mock data for food trucks - exactly 4 trucks for 2x2 grid
final List<FoodTruck> mockFoodTrucks = [
  FoodTruck(
    id: 'truck1',
    name: 'Burger Express',
    cuisine: 'American',
    rating: 4.5,
    imageUrl: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=400',
    description: 'Juicy burgers and crispy fries',
    isOpen: true,
  ),
  FoodTruck(
    id: 'truck2',
    name: 'Taco Fiesta',
    cuisine: 'Mexican',
    rating: 4.8,
    imageUrl: 'https://images.unsplash.com/photo-1551504734-5ee1c4a1479b?w=400',
    description: 'Authentic Mexican street tacos',
    isOpen: true,
  ),
  FoodTruck(
    id: 'truck3',
    name: 'Pizza Corner',
    cuisine: 'Italian',
    rating: 4.3,
    imageUrl: 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=400',
    description: 'Wood-fired pizzas made fresh',
    isOpen: true,
  ),
  FoodTruck(
    id: 'truck4',
    name: 'Sushi Roll',
    cuisine: 'Japanese',
    rating: 4.7,
    imageUrl: 'https://images.unsplash.com/photo-1579584425555-c3ce17fd4351?w=400',
    description: 'Fresh sushi and Japanese cuisine',
    isOpen: true,
  ),
];

