import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../utils/app_colors.dart';
import '../utils/platform_utils_stub.dart' if (dart.library.io) '../utils/platform_utils_io.dart' as platform_utils;
import '../state/theme_provider.dart';
import '../state/orders_provider.dart';
import '../state/cart_provider.dart';
import '../services/auth_service.dart';
import '../utils/app_navigator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login_page.dart';

/// Settings screen
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDeleting = false;

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
    if (!mounted) return;
    setState(() => _isDeleting = true);

    Provider.of<OrdersProvider>(context, listen: false).clearOrders();
    Provider.of<CartProvider>(context, listen: false).clear();

    // Redirect to login (main) screen immediately
    if (!mounted) return;
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginPage(),
      ),
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
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final showDeleteAccount = platform_utils.isIOSOrAndroid;

    return Stack(
      children: [
        Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
          ),
        ),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: Text(
                    'Notifications',
                    style: GoogleFonts.inter(),
                  ),
                  trailing: Switch(
                    value: true,
                    onChanged: (value) {},
                    activeColor: AppColors.burgundy,
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.language_outlined),
                  title: Text(
                    'Language',
                    style: GoogleFonts.inter(),
                  ),
                    trailing: Text(
                    'English',
                    style: GoogleFonts.inter(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  onTap: () {
                    // Language selection
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.dark_mode_outlined),
                  title: Text(
                    'Dark Mode',
                    style: GoogleFonts.inter(),
                  ),
                  trailing: Switch(
                    value: themeProvider.isDarkMode,
                    onChanged: (value) {
                      themeProvider.toggleTheme();
                    },
                    activeColor: AppColors.burgundy,
                  ),
                ),
              ],
            ),
          ),
          if (showDeleteAccount) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isDeleting ? null : () => _showDeleteAccountDialog(context),
                icon: const Icon(Icons.delete_forever),
                label: const Text('Delete account'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD50000),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
        if (_isDeleting)
          Container(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.5),
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}

