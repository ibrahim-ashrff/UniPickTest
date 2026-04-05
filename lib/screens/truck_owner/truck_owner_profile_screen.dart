import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/app_colors.dart';
import '../../state/orders_provider.dart';
import '../../state/cart_provider.dart';
import '../login_page.dart';

/// Profile Screen for Truck Owners
class TruckOwnerProfileScreen extends StatelessWidget {
  final String? truckId;
  final String? truckName;

  const TruckOwnerProfileScreen({
    super.key,
    this.truckId,
    this.truckName,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Truck Information',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow('Truck Name', truckName ?? 'Not assigned'),
                    _buildInfoRow('Truck ID', truckId ?? 'Not assigned'),
                    const SizedBox(height: 16),
                    if (truckId != null) _OpenClosedSwitch(truckId: truckId!),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Account Information',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow('Email', user?.email ?? 'Not available'),
                    _buildInfoRow('User ID', user?.uid ?? 'Not available'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('Sign Out', style: GoogleFonts.inter()),
                      content: Text(
                        'Are you sure you want to sign out?',
                        style: GoogleFonts.inter(),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text('Cancel', style: GoogleFonts.inter()),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.burgundy,
                            foregroundColor: Colors.white,
                          ),
                          child: Text('Sign Out', style: GoogleFonts.inter()),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    // Clear orders and cart before signing out
                    if (context.mounted) {
                      Provider.of<OrdersProvider>(context, listen: false).clearOrders();
                      Provider.of<CartProvider>(context, listen: false).clear();
                    }
                    
                    await FirebaseAuth.instance.signOut();
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => const LoginPage(isTruckOwner: true),
                        ),
                        (route) => false,
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.burgundy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Sign Out',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Switch for truck owner to toggle open/closed status
class _OpenClosedSwitch extends StatelessWidget {
  final String truckId;

  const _OpenClosedSwitch({required this.truckId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('food_trucks')
          .doc(truckId)
          .snapshots(),
      builder: (context, snapshot) {
        final isOpen = (snapshot.data?.data() as Map<String, dynamic>?)?['isOpen'] ?? true;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Truck Status',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            Row(
              children: [
                Text(
                  isOpen ? 'Open' : 'Closed',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: isOpen ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: isOpen,
                  onChanged: (value) async {
                    try {
                      await FirebaseFirestore.instance
                          .collection('food_trucks')
                          .doc(truckId)
                          .set({'isOpen': value}, SetOptions(merge: true));
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  activeColor: AppColors.burgundy,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}