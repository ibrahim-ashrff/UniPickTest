import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen.dart';
import 'orders_screen.dart';
import 'account_screen.dart';
import 'truck_owner/truck_owner_dashboard.dart';
import '../utils/app_colors.dart';

/// Main navigation shell with bottom navigation bar
/// Manages navigation between Home, Food Trucks, Orders, and Account screens
/// Routes to truck owner dashboard if user has truck owner role
class MainNavigation extends StatefulWidget {
  final int initialIndex;
  
  const MainNavigation({super.key, this.initialIndex = 0});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  late int _currentIndex;
  String? _userRole;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _loading = false;
      });
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data();
        setState(() {
          _userRole = data?['role'] ?? 'customer';
          _loading = false;
        });
      } else {
        setState(() {
          _userRole = 'customer';
          _loading = false;
        });
      }
    } catch (e) {
      print('Error checking user role: $e');
      setState(() {
        _userRole = 'customer';
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

    // Route to truck owner dashboard if user is a truck owner
    if (_userRole == 'truck owner') {
      return const TruckOwnerDashboard();
    }

    // Regular customer navigation
    final List<Widget> _screens = [
      const HomeScreen(),
      const OrdersScreen(),
      const AccountScreen(),
    ];

    return Scaffold(
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
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long),
              label: 'Orders',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Account',
            ),
          ],
        ),
      ),
    );
  }
}

