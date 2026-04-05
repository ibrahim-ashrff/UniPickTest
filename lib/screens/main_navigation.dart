import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'home_screen.dart';
import 'orders_screen.dart';
import 'cart_screen.dart';
import 'account_screen.dart';
import 'guest_account_screen.dart';
import 'truck_owner/truck_owner_dashboard.dart';
import '../utils/app_colors.dart';
import '../state/cart_provider.dart';

/// Main navigation shell with bottom navigation bar
/// Manages navigation between Home, Food Trucks, Orders, and Account screens
/// Routes to truck owner dashboard if user has truck owner role
class MainNavigation extends StatefulWidget {
  final int initialIndex;
  final bool isGuest;

  const MainNavigation({super.key, this.initialIndex = 0, this.isGuest = false});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  late int _currentIndex;
  late PageController _pageController;
  String? _userRole;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    if (widget.isGuest) {
      setState(() {
        _userRole = null;
        _loading = false;
      });
    } else {
      _checkUserRole();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _checkUserRole() async {
    if (widget.isGuest) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _loading = false);
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
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Route to truck owner dashboard if user is a truck owner (not for guests)
    if (!widget.isGuest && _userRole == 'truck owner') {
      return const TruckOwnerDashboard();
    }

    // Guest: Home, Orders, Cart, Account (guest account = Sign In only). Logged-in: full Account.
    final bool isGuest = widget.isGuest;
    final List<Widget> screens = isGuest
        ? [
            const HomeScreen(),
            const OrdersScreen(),
            const CartScreen(),
            const GuestAccountScreen(),
          ]
        : [
            const HomeScreen(),
            const OrdersScreen(),
            const CartScreen(),
            const AccountScreen(),
          ];

    final navItems = <BottomNavigationBarItem>[
      const BottomNavigationBarItem(
        icon: Icon(Icons.home),
        label: 'Home',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.receipt_long),
        label: 'Orders',
      ),
      BottomNavigationBarItem(
        icon: Consumer<CartProvider>(
          builder: (context, cart, child) {
            return Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.shopping_cart),
                if (cart.itemCount > 0)
                  Positioned(
                    right: -8,
                    top: -8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.burgundy,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '${cart.itemCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        label: 'Cart',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.person),
        label: 'Account',
      ),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBody: true,
      body: PageView(
        controller: _pageController,
        physics: const BouncingScrollPhysics(),
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
        },
        children: screens,
      ),
      bottomNavigationBar: Container(
        color: Theme.of(context).colorScheme.surface,
        child: SafeArea(
          top: false,
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            selectedItemColor: AppColors.burgundy,
            unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant,
            selectedFontSize: 12,
            unselectedFontSize: 12,
            elevation: 0,
            items: navItems,
          ),
        ),
      ),
    );
  }
}

