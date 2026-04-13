import 'food_truck.dart';
import 'menu_item.dart';

/// One slide in the home hero: a menu item, its truck, and global order count.
class PopularMenuSlide {
  final MenuItem item;
  final FoodTruck truck;
  final int orderCount;

  const PopularMenuSlide({
    required this.item,
    required this.truck,
    required this.orderCount,
  });
}
