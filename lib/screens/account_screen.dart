import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_colors.dart';
import '../state/orders_provider.dart';
import '../state/cart_provider.dart';
import '../utils/page_transitions.dart';
import '../utils/platform_utils_stub.dart' if (dart.library.io) '../utils/platform_utils_io.dart' as platform_utils;
import '../utils/app_navigator.dart';
import '../services/auth_service.dart';
import 'login_page.dart';
import 'about_screen.dart';
import 'help_support_screen.dart';
import 'terms_view_screen.dart';

/// Account screen showing user information and settings
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  /// Resolve display name: Firestore name (email/password signup) > displayName > email > fallback
  String _resolveName(User? user, DocumentSnapshot? userDoc) {
    if (user == null) return 'User';
    final firestoreName = userDoc?.get('name') as String?;
    if (firestoreName != null && firestoreName.trim().isNotEmpty) {
      return firestoreName.trim();
    }
    if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
      return user.displayName!.trim();
    }
    if (user.email != null && user.email!.isNotEmpty) {
      return user.email!;
    }
    return 'User';
  }

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
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + 72 + MediaQuery.of(context).padding.bottom,
        ),
        child: StreamBuilder<DocumentSnapshot>(
          stream: user != null
              ? FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots()
              : null,
          builder: (context, snapshot) {
            final userDoc = snapshot.hasData ? snapshot.data : null;
            final displayName = _resolveName(user, userDoc);
            final isAppleSignIn = user != null &&
                user.providerData.any((p) => p.providerId == 'apple.com');

            return Column(
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
                            _getInitials(displayName),
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
                          displayName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // For Apple sign-in, don't show email; for others show email
                        if (!isAppleSignIn) ...[
                          const SizedBox(height: 8),
                          Text(
                            user?.email ?? 'Guest',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
            // Options section
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
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
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: Text(
                      'Terms & Conditions',
                      style: GoogleFonts.inter(),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      context.slideTo(
                        const TermsViewScreen(),
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
            if (platform_utils.isIOSOrAndroid) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showDeleteAccountDialog(context),
                  icon: const Icon(Icons.delete_forever, size: 20),
                  label: const Text('Delete account'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD50000),
                    side: const BorderSide(color: Color(0xFFD50000)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
              ],
            );
          },
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account'),
        content: const Text(
          'Are you sure you want to delete your account? '
          'Your profile, orders, and all associated data will be permanently removed and cannot be restored.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _deleteAccount(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext context) async {
    Provider.of<OrdersProvider>(context, listen: false).clearOrders();
    Provider.of<CartProvider>(context, listen: false).clear();

    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );

    try {
      final authService = AuthService();
      await authService.deleteAccount();
    } on FirebaseAuthException catch (e) {
      final message = e.message ?? 'Could not delete account.';
      if (navigatorKey.currentContext != null && navigatorKey.currentContext!.mounted) {
        ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (navigatorKey.currentContext != null && navigatorKey.currentContext!.mounted) {
        ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
          SnackBar(content: Text('Something went wrong: $e')),
        );
      }
    }
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

