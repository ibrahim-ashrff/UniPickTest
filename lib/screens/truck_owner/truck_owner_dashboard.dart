import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/app_colors.dart';
import '../../data/mock_food_trucks.dart';
import 'truck_owner_orders_screen.dart';
import 'truck_owner_menu_screen.dart';
import 'truck_owner_profile_screen.dart';

/// Truck Owner Dashboard
/// Main navigation for truck owners to manage their food truck
class TruckOwnerDashboard extends StatefulWidget {
  const TruckOwnerDashboard({super.key});

  @override
  State<TruckOwnerDashboard> createState() => _TruckOwnerDashboardState();
}

class _TruckOwnerDashboardState extends State<TruckOwnerDashboard> {
  int _currentIndex = 0;
  String? _truckId;
  String? _truckName;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTruckInfo();
  }

  Future<void> _loadTruckInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Get user document from Firestore to check role and ownerId
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        setState(() {
          _loading = false;
        });
        return;
      }

      final userData = userDoc.data();
      final userRole = userData?['role'] ?? '';
      final ownerId = userData?['ownerId'] as String?;

      // Only proceed if user is a truck owner and has an ownerId
      if (userRole != 'truck owner' || ownerId == null || ownerId.isEmpty) {
        setState(() {
          _truckName = 'No truck assigned';
          _loading = false;
        });
        return;
      }

      // Find the truck in mockFoodTrucks where id matches the user's ownerId
      final matchedTruck = mockFoodTrucks.firstWhere(
        (truck) => truck.id == ownerId,
        orElse: () => throw Exception('Truck not found'),
      );

      setState(() {
        _truckId = matchedTruck.id;
        _truckName = matchedTruck.name;
        _loading = false;
      });
    } catch (e) {
      print('Error loading truck info: $e');
      setState(() {
        _truckName = 'Truck not found';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final List<Widget> _screens = [
      TruckOwnerOrdersScreen(truckId: _truckId),
      TruckOwnerMenuScreen(truckId: _truckId),
      TruckOwnerProfileScreen(truckId: _truckId, truckName: _truckName),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_truckName ?? 'Truck Owner Dashboard'),
        backgroundColor: AppColors.burgundy,
        foregroundColor: Colors.white,
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.background,
          selectedItemColor: AppColors.burgundy,
          unselectedItemColor: AppColors.grey,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long),
              label: 'Orders',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.restaurant_menu),
              label: 'Menu',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

