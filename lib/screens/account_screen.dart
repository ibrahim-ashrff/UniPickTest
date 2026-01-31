import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_colors.dart';
import '../state/orders_provider.dart';
import '../state/cart_provider.dart';
import '../utils/page_transitions.dart';
import 'login_page.dart';
import 'settings_screen.dart';
import 'about_screen.dart';
import 'help_support_screen.dart';

/// Account screen showing user information and settings
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Account',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Profile section
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    // Profile icon with initials
                    CircleAvatar(
                      radius: 100,
                      backgroundColor: AppColors.burgundy,
                      child: Text(
                        _getInitials(user?.displayName ?? user?.email ?? 'U'),
                        style: GoogleFonts.inter(
                          fontSize: 80,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // User name (on top, bold)
                    Text(
                      user?.displayName ?? 'User',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // User email (below, grey)
                    Text(
                      user?.email ?? 'Guest',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Settings section
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.settings),
                    title: Text(
                      'Settings',
                      style: GoogleFonts.inter(),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      context.slideTo(
                        const SettingsScreen(),
                        direction: SlideDirection.right,
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.help_outline),
                    title: Text(
                      'Help & Support',
                      style: GoogleFonts.inter(),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      context.slideTo(
                        const HelpSupportScreen(),
                        direction: SlideDirection.right,
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: Text(
                      'About',
                      style: GoogleFonts.inter(),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      context.slideTo(
                        const AboutScreen(),
                        direction: SlideDirection.right,
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Logout button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  // Clear orders and cart before signing out
                  if (context.mounted) {
                    Provider.of<OrdersProvider>(context, listen: false).clearOrders();
                    Provider.of<CartProvider>(context, listen: false).clear();
                  }
                  
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const LoginPage(),
                      ),
                      (route) => false,
                    );
                  }
                },
                icon: const Icon(Icons.logout),
                label: const Text('Log Out'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.burgundy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Get initials from name (first letter of first name and first letter of last name)
  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    
    // Split by space to get first and last name
    final parts = name.trim().split(' ');
    
    if (parts.length >= 2) {
      // First letter of first name + first letter of last name
      final firstInitial = parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '';
      final lastInitial = parts[1].isNotEmpty ? parts[1][0].toUpperCase() : '';
      return '$firstInitial$lastInitial';
    } else if (parts.length == 1 && parts[0].isNotEmpty) {
      // Only one name, use first two letters or just first letter
      final namePart = parts[0];
      if (namePart.length >= 2) {
        return namePart.substring(0, 2).toUpperCase();
      }
      return namePart[0].toUpperCase();
    }
    
    // Fallback: use first letter of email if it's an email
    if (name.contains('@')) {
      return name[0].toUpperCase();
    }
    
    return name[0].toUpperCase();
  }
}

