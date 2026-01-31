import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../state/cart_provider.dart';
import '../payments/fawry_payment.dart';
import '../utils/app_colors.dart';
import 'home_screen.dart';
import 'payment_status_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final TextEditingController _notesController = TextEditingController();
  bool _isProcessing = false;
  String? _currentMerchantRefNum; // Store merchantRefNum from pay() call

  @override
  void initState() {
    super.initState();
    _setupPaymentListener();
  }

  void _setupPaymentListener() {
    FawryPayment.listen(
      context,
      onPaymentComplete: (response) {
        // IMPORTANT: show message + status
        final msg = "Fawry: ${response.status} ${response.message ?? ''}";
        debugPrint(msg);
        debugPrint("FAWRY FULL RAW STATUS: ${response.status} | message: ${response.message ?? ''}");
        debugPrint("FAWRY DATA: ${response.data ?? ''}"); // Log the data field
        debugPrint("FAWRY ERROR: ${response.error ?? ''}"); // Log error field
        
        // Check payment status - prioritize success checks first
        final statusStr = (response.status ?? '').toString().toUpperCase();
        final isPaid = statusStr == 'PAID' || statusStr == 'SUCCESS' || statusStr == '200';
        
        // Only mark as failed if NOT paid and matches failure conditions
        // Don't check error field alone - it might be present even for successful payments
        final isFailed = !isPaid && (
                        statusStr == '101' || 
                        statusStr == '102' || 
                        statusStr == 'FAILED' || 
                        statusStr == 'CANCELLED');
        
        debugPrint("🔍 Payment Status Check:");
        debugPrint("   - Status String: $statusStr");
        debugPrint("   - Is Paid: $isPaid");
        debugPrint("   - Is Failed: $isFailed");
        debugPrint("   - Error Field: ${response.error ?? 'null'}");
        
        // Extract reference number from data field
        String? referenceNumber;
        if (response.data != null) {
          try {
            // Try parsing as JSON first
            final dataJson = jsonDecode(response.data!);
            if (dataJson is Map) {
              // Try common field names for reference number
              referenceNumber = dataJson['referenceNumber'] ?? 
                               dataJson['merchantRefNum'] ?? 
                               dataJson['fawryRefNumber'] ??
                               dataJson['orderRefNumber'] ??
                               dataJson['refNumber'] ??
                               dataJson['fawryRefNum'] ??
                               dataJson['chargeResponse']['merchantRefNumber'] ??
                               dataJson['chargeResponse']['referenceNumber'];
            }
          } catch (e) {
            // If data is not JSON, it might be the reference number itself
            referenceNumber = response.data;
            debugPrint("FAWRY DATA is not JSON, using as-is: $referenceNumber");
          }
        }
        
        // If failed and no reference number, generate a placeholder
        if (isFailed && (referenceNumber == null || referenceNumber.isEmpty)) {
          referenceNumber = 'FAILED_${DateTime.now().millisecondsSinceEpoch}';
          debugPrint("⚠️ Payment failed without reference number, using placeholder: $referenceNumber");
        }
        
        if (referenceNumber != null && referenceNumber.isNotEmpty) {
          debugPrint("✅✅✅ FAWRY REFERENCE NUMBER: $referenceNumber ✅✅✅");
          
          // Navigate to payment status screen with reference number
          if (mounted) {
            setState(() => _isProcessing = false);
            
            // Get the amount from cart
            final cart = Provider.of<CartProvider>(context, listen: false);
            final amount = cart.total;
            
            // Use the stored merchantRefNum from pay() call, or try to extract from response
            String merchantRefNumToUse = _currentMerchantRefNum ?? '';
            
            if (merchantRefNumToUse.isEmpty && response.data != null) {
              try {
                final dataJson = jsonDecode(response.data!);
                if (dataJson is Map) {
                  merchantRefNumToUse = dataJson['merchantRefNum'] ?? 
                                      dataJson['merchantRefNumber'] ?? 
                                      '';
                }
              } catch (e) {
                // If parsing fails, merchantRefNumToUse stays empty
              }
            }
            
            // Fallback to referenceNumber if merchantRefNum is still empty
            if (merchantRefNumToUse.isEmpty) {
              merchantRefNumToUse = referenceNumber!;
              debugPrint("⚠️ Using referenceNumber as fallback for merchantRefNum");
            }
            
            // Get notes from checkout screen
            final notes = _notesController.text.trim().isEmpty 
                ? null 
                : _notesController.text.trim();
            
            // Check if payment failed and pass status (only if actually failed, not if paid)
            String? initialStatus;
            if (isFailed && !isPaid) {
              initialStatus = statusStr;
              debugPrint("⚠️ Payment failed - passing status to PaymentStatusScreen: $statusStr");
            } else if (isPaid) {
              debugPrint("✅ Payment successful - will be handled by PaymentStatusScreen");
            }
            
            // Navigate to payment status screen (referenceNumber is guaranteed non-null here)
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => PaymentStatusScreen(
                  referenceNumber: referenceNumber!, // Fawry reference number (for display)
                  amount: amount,
                  merchantRefNum: merchantRefNumToUse, // Merchant ref number (for status API)
                  notes: notes, // Pass notes from checkout
                  initialStatus: initialStatus, // Pass status if failed
                ),
              ),
            );
            
            // Don't process further here - let payment status screen handle it
            return;
          }
        } else {
          debugPrint("⚠️ FAWRY REFERENCE NUMBER NOT FOUND in response");
          debugPrint("   Check FAWRY DATA field above for the actual structure");
          
          // Even without reference number, if we know it failed, handle it
          if (isFailed && mounted) {
            debugPrint("❌ Payment failed - handling failure without reference number");
            debugPrint("   Status: $statusStr");
            debugPrint("   Error: ${response.error ?? ''}");
            setState(() => _isProcessing = false);
            
            final cart = Provider.of<CartProvider>(context, listen: false);
            final amount = cart.total;
            
            // Generate placeholder reference number for failed payment
            final failedRef = 'FAILED_${DateTime.now().millisecondsSinceEpoch}';
            final merchantRefNum = _currentMerchantRefNum ?? failedRef;
            
            final notes = _notesController.text.trim().isEmpty 
                ? null 
                : _notesController.text.trim();
            
            // Navigate to payment status screen to handle the failure
            // Pass the status so it knows it's already failed
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => PaymentStatusScreen(
                  referenceNumber: failedRef,
                  amount: amount,
                  merchantRefNum: merchantRefNum,
                  notes: notes,
                  initialStatus: statusStr, // Pass the failed status
                ),
              ),
            );
          }
        }

        if (!mounted) return;

        // Always stop loading on any callback
        setState(() => _isProcessing = false);

        // If we have a status but no reference number, show message
        final status = (response.status ?? "").toUpperCase();
        if (status == "PAID" || status == "SUCCESS") {
          // If paid but no reference number, complete order anyway
          _placeOrder(context, null);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      },
      onError: (e) {
        debugPrint("Fawry callback error: $e");
        if (!mounted) return;
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Fawry callback error: $e")),
        );
      },
    );
  }


  @override
  void dispose() {
    _notesController.dispose();
    // Cancel payment listener when checkout screen is disposed
    FawryPayment.cancel(context);
    super.dispose();
  }

  Future<void> _processPayment(BuildContext context) async {
    final cart = Provider.of<CartProvider>(context, listen: false);

    if (cart.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart is empty')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // Get user info
      final user = FirebaseAuth.instance.currentUser;
      final firebaseUser = user;
      if (firebaseUser == null) {
        throw Exception('User not logged in');
      }
      
      final userEmail = firebaseUser.email ?? 'test@test.com';
      final userName = firebaseUser.email ?? "UNIPICK User";
      final userId = firebaseUser.uid;
      
      // Calculate total amount
      final totalAmount = cart.total;

      // Process payment with Fawry
      // IMPORTANT: Use STAGING credentials (merchantCode + secureHashKey) for testing
      
      // Use Firebase UID as customerProfileId for consistent card saving
      // This ensures cards are saved to the same customer profile
      final customerProfileId = firebaseUser.uid;
      final customerName = firebaseUser.displayName ?? firebaseUser.email ?? "UNIPICK User";
      final customerEmail = firebaseUser.email ?? "test@test.com";
      
      // IMPORTANT: use the exact merchant code you were given
      final merchantRefNum = await FawryPayment.pay(
        merchantCode: "770000021908",
        secureHashKey: "b4afb94e0a554815a17ed505de2f9e67", // "Security Key / Hash code" from Fawry
        customerProfileId: customerProfileId,
        customerName: customerName,
        customerEmail: customerEmail,
        customerMobile: "01012345678", // No +20 prefix for test
        amountEgp: cart.total.toDouble(),
      );
      
      // Store merchantRefNum for later use (we'll need it for status checks)
      _currentMerchantRefNum = merchantRefNum;
      debugPrint("Generated merchantRefNum: $merchantRefNum");

      // Safety: if no callback arrives within 20s, unlock UI
      Future.delayed(const Duration(seconds: 20), () {
        if (!mounted) return;
        if (_isProcessing) {
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No response from Fawry yet. Check logcat.")),
          );
        }
      });

      // Note: The actual order completion will be handled in the FawryPayment.listen callback
      // when payment is successful. You can call _placeOrder() in the callback.
    } catch (e) {
      if (!mounted) return;
      
      setState(() => _isProcessing = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _placeOrder(BuildContext context, String? fawryReferenceNumber) async {
    final cart = Provider.of<CartProvider>(context, listen: false);

    if (cart.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart is empty')),
      );
      return;
    }

    // Log the reference number for backend
    if (fawryReferenceNumber != null) {
      debugPrint("📦 PLACING ORDER WITH FAWRY REFERENCE NUMBER: $fawryReferenceNumber");
      // TODO: Send order to your backend with the Fawry reference number
      // Example with Firestore:
      // final user = FirebaseAuth.instance.currentUser;
      // if (user != null) {
      //   await FirebaseFirestore.instance.collection('orders').add({
      //     'userId': user.uid,
      //     'items': cart.items.map((item) => {
      //       'name': item.name,
      //       'quantity': item.quantity,
      //       'price': item.price,
      //     }).toList(),
      //     'total': cart.total,
      //     'fawryReferenceNumber': fawryReferenceNumber, // ← Save the reference number
      //     'status': 'paid',
      //     'createdAt': FieldValue.serverTimestamp(),
      //   });
      // }
    } else {
      debugPrint("⚠️ WARNING: Order placed but no Fawry reference number available");
    }

    // Clear cart after successful order
    cart.clear();

    if (!mounted) return;

    setState(() => _isProcessing = false);

    // Show success message with reference number and navigate back to home
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(fawryReferenceNumber != null
          ? 'Order placed successfully! ✅\nRef: $fawryReferenceNumber'
          : 'Order placed successfully! ✅'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );

    // Navigate back to home
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
      ),
      body: cart.items.isEmpty
          ? const Center(child: Text('Cart is empty'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Order Summary
                  const Text(
                    'Order Summary',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...cart.items.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${item.quantity}x ${item.menuItem.name}',
                                style: const TextStyle(fontSize: 14),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              'EGP ${item.total.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      )),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Subtotal',
                        style: TextStyle(fontSize: 16),
                      ),
                      Text(
                        'EGP ${cart.subtotal.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Notes Section
                  const Text(
                    'Order Notes (Optional)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Add any special instructions...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Total
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'EGP ${cart.total.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Pay with Fawry Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : () => _processPayment(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.burgundy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        disabledBackgroundColor: Colors.grey,
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Pay with Fawry',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

