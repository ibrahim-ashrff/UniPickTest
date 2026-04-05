import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../state/cart_provider.dart';
import '../state/guest_provider.dart';
import 'package:fawry_sdk/model/payment_methods.dart';
import '../payments/fawry_payment.dart';
import '../utils/app_colors.dart';
import '../widgets/item_thumbnail.dart';
import 'home_screen.dart';
import 'login_page.dart';
import 'payment_status_screen.dart';

/// Egyptian mobile for Fawry (digits; many flows expect 01xxxxxxxxx).
String _fawryCustomerMobile(User? user) {
  final raw = user?.phoneNumber?.trim();
  if (raw == null || raw.isEmpty) {
    // Fawry staging often validates Egyptian MSISDN shape; use a common test pattern if user has no phone on the account
    return '01012345678';
  }
  var s = raw.replaceAll(RegExp(r'\s'), '');
  if (s.startsWith('+20')) {
    s = s.substring(3);
  } else if (s.startsWith('0020')) {
    s = s.substring(4);
  } else if (s.startsWith('20') && s.length >= 12) {
    s = s.substring(2);
  }
  if (s.length == 10 && !s.startsWith('0')) {
    s = '0$s';
  }
  return s;
}

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final TextEditingController _notesController = TextEditingController();
  /// True while Fawry pay() is in progress — blocks double submit until callback, timeout, or error.
  bool _fawryPayInFlight = false;
  /// Pay button spinner only; cleared when native handoff returns. Payment state still follows _fawryPayInFlight until callback/timeout.
  bool _showPayButtonSpinner = false;
  String? _currentMerchantRefNum; // Store merchantRefNum from pay() call
  String? _lastListenerUserId; // Track which user the Fawry listener is for (re-setup on account change)

  @override
  void initState() {
    super.initState();
    _lastListenerUserId = FirebaseAuth.instance.currentUser?.uid;
    _setupPaymentListener();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid != _lastListenerUserId) {
      FawryPayment.cancel(context);
      _lastListenerUserId = currentUid;
      _currentMerchantRefNum = null;
      _setupPaymentListener();
    }
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
        
        // Parse orderStatus from data first — 102 + PAID means card/charge succeeded (not only 100).
        String? orderStatusFromData;
        if (response.data != null) {
          try {
            final dataJson = jsonDecode(response.data!);
            if (dataJson is Map) {
              orderStatusFromData = (dataJson['orderStatus'] ?? '').toString().toUpperCase();
            }
          } catch (_) {}
        }

        final statusStr = (response.status ?? '').toString();
        final statusStrUpper = statusStr.toUpperCase();
        final isPaid = statusStr == '100' ||
            statusStrUpper == 'PAID' ||
            statusStrUpper == 'SUCCESS' ||
            statusStrUpper == '200' ||
            (statusStrUpper == '102' &&
                (orderStatusFromData == 'PAID' || orderStatusFromData == 'SUCCESS'));
        
        // Duplicate request: 101 with "Request already processed" = same merchantRefNum sent twice.
        // On Fawry dashboard the order shows as UNPAID (pending), not failed. Don't register as failed.
        final message = (response.message ?? '').toString();
        final isDuplicateRequest = statusStrUpper == '101' &&
            (message.contains('Request already processed') ||
             message.contains('merchantRefNum value should be changed'));
        if (isDuplicateRequest && mounted) {
          FawryPayment.clearAwaitingReturnFromFawry();
          setState(() {
            _fawryPayInFlight = false;
            _showPayButtonSpinner = false;
          });
          _currentMerchantRefNum = null; // Next tap will generate a fresh merchantRefNum
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'This payment was already submitted. Tap "Pay with Fawry" again to start a new payment.',
              ),
              duration: Duration(seconds: 5),
            ),
          );
          debugPrint("🔄 Duplicate Fawry request - staying on checkout for retry");
          return;
        }

        // Only mark as failed if orderStatus is explicitly failed/declined, or status is 101/CANCELLED (Fawry guide: 101 = error)
        // 102 with UNPAID = pending (user got reference number, awaiting payment at Fawry); 102 + FAILED/DECLINED = card/charge failed
        final isFailed = !isPaid && (
                        statusStrUpper == '101' ||
                        statusStrUpper == 'FAILED' ||
                        statusStrUpper == 'CANCELLED' ||
                        orderStatusFromData == 'FAILED' ||
                        orderStatusFromData == 'DECLINED' ||
                        orderStatusFromData == 'REJECTED');
        
        debugPrint("🔍 Payment Status Check:");
        debugPrint("   - Status String: $statusStr ($statusStrUpper)");
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
                  dataJson['fawryRefNum'];
              if ((referenceNumber == null || referenceNumber.toString().isEmpty)) {
                final cr = dataJson['chargeResponse'];
                if (cr is Map) {
                  referenceNumber = cr['merchantRefNumber'] ?? cr['referenceNumber'];
                }
              }
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
            setState(() {
              _fawryPayInFlight = false;
              _showPayButtonSpinner = false;
            });

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
            
            // Check if payment failed and pass status (only if actually failed, not if paid).
            // Do not pass raw "102" — PaymentStatusScreen treats 102 as pending (Pay at Fawry); map failed 102 to FAILED.
            String? initialStatus;
            if (isFailed && !isPaid) {
              initialStatus = statusStrUpper == '102'
                  ? 'FAILED'
                  : (statusStrUpper.isNotEmpty ? statusStrUpper : 'FAILED');
              debugPrint("⚠️ Payment failed - passing status to PaymentStatusScreen: $initialStatus (Fawry status=$statusStr)");
            } else if (isPaid) {
              debugPrint("✅ Payment successful - will be handled by PaymentStatusScreen");
            }
            
            // Navigate to payment status screen (referenceNumber is guaranteed non-null here)
            FawryPayment.clearAwaitingReturnFromFawry();
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
            setState(() {
              _fawryPayInFlight = false;
              _showPayButtonSpinner = false;
            });

            final cart = Provider.of<CartProvider>(context, listen: false);
            final amount = cart.total;

            // Generate placeholder reference number for failed payment
            final failedRef = 'FAILED_${DateTime.now().millisecondsSinceEpoch}';
            final merchantRefNum = _currentMerchantRefNum ?? failedRef;
            
            final notes = _notesController.text.trim().isEmpty 
                ? null 
                : _notesController.text.trim();
            
            // Navigate to payment status screen to handle the failure
            final failedInitialStatus = statusStrUpper == '102'
                ? 'FAILED'
                : (statusStrUpper.isNotEmpty ? statusStr : 'FAILED');
            FawryPayment.clearAwaitingReturnFromFawry();
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => PaymentStatusScreen(
                  referenceNumber: failedRef,
                  amount: amount,
                  merchantRefNum: merchantRefNum,
                  notes: notes,
                  initialStatus: failedInitialStatus,
                ),
              ),
            );
          }
        }

        if (!mounted) return;

        // Always stop loading on any callback
        FawryPayment.clearAwaitingReturnFromFawry();
        setState(() {
          _fawryPayInFlight = false;
          _showPayButtonSpinner = false;
        });

        // If we have a status but no reference number, show message
        final status = (response.status ?? "").toString();
        final statusUpper = status.toUpperCase();
        if (status == "100" || statusUpper == "PAID" || statusUpper == "SUCCESS") {
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
        FawryPayment.clearAwaitingReturnFromFawry();
        if (!mounted) return;
        setState(() {
          _fawryPayInFlight = false;
          _showPayButtonSpinner = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Fawry callback error: $e")),
        );
      },
    );
  }


  void _showGuestPayDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Account required'),
        content: const Text(
          'You need to create an account to use this feature.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.burgundy,
              foregroundColor: Colors.white,
            ),
            child: const Text('Create account'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    FawryPayment.clearAwaitingReturnFromFawry();
    // Cancel payment listener when checkout screen is disposed
    FawryPayment.cancel(context);
    super.dispose();
  }

  Future<void> _processPayment(BuildContext context) async {
    // Prevent double-tap: block immediately so a second tap before redirect does not send another request
    if (_fawryPayInFlight) return;
    setState(() {
      _fawryPayInFlight = true;
      _showPayButtonSpinner = true;
    });

    final cart = Provider.of<CartProvider>(context, listen: false);
    final isGuest = Provider.of<GuestProvider>(context, listen: false).isGuest;

    if (isGuest) {
      setState(() {
        _fawryPayInFlight = false;
        _showPayButtonSpinner = false;
      });
      _showGuestPayDialog(context);
      return;
    }

    if (cart.items.isEmpty) {
      setState(() {
        _fawryPayInFlight = false;
        _showPayButtonSpinner = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart is empty')),
      );
      return;
    }

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

      // Alphanumeric ref per Fawry guide (underscore/UID refs often fail card auth; Pay-at-Fawry may still work).
      final merchantRefNum = FawryPayment.generateMerchantRefNum();

      // Store before calling pay so status screen can use it
      _currentMerchantRefNum = merchantRefNum;
      debugPrint("Generated merchantRefNum: $merchantRefNum");

      // So that if user presses back in Fawry and lands on home, we redirect to checkout on app resume
      FawryPayment.setAwaitingReturnFromFawry(true);

      // IMPORTANT: use the exact merchant code you were given
      final payFuture = FawryPayment.pay(
        merchantCode: "770000021908",
        secureHashKey: "b4afb94e0a554815a17ed505de2f9e67", // "Security Key / Hash code" from Fawry
        merchantRefNum: merchantRefNum,
        customerProfileId: customerProfileId,
        customerName: customerName,
        customerEmail: customerEmail,
        customerMobile: _fawryCustomerMobile(firebaseUser),
        amountEgp: cart.total.toDouble(),
        // ALL = card + Pay at Fawry (reference number at outlet) + wallet where enabled
        paymentMethods: PaymentMethods.ALL,
        payWithCardToken: true,
      );

      await payFuture;

      if (!mounted) return;

      // Stop button spinner when Fawry UI has taken over (SDK update handles timing). Pay stays disabled until callback or timeout.
      setState(() => _showPayButtonSpinner = false);

      // Safety: if no callback arrives within 20s, unlock UI
      Future.delayed(const Duration(seconds: 20), () {
        if (!mounted) return;
        FawryPayment.clearAwaitingReturnFromFawry();
        if (_fawryPayInFlight) {
          setState(() {
            _fawryPayInFlight = false;
            _showPayButtonSpinner = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No response from Fawry yet. Check logcat.")),
          );
        }
      });

      // Note: The actual order completion will be handled in the FawryPayment.listen callback
      // when payment is successful. You can call _placeOrder() in the callback.
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _fawryPayInFlight = false;
        _showPayButtonSpinner = false;
      });
      
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

    setState(() {
      _fawryPayInFlight = false;
      _showPayButtonSpinner = false;
    });

    // Show success message and navigate back to home
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Order placed successfully! ✅'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
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
                          children: [
                            ItemThumbnail(
                              imageUrl: item.menuItem.imageUrl,
                              size: 48,
                            ),
                            const SizedBox(width: 12),
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
                  // Pay with Fawry Button - disabled and shows loading as soon as tapped until redirect
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _fawryPayInFlight ? null : () => _processPayment(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.burgundy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        disabledBackgroundColor: AppColors.burgundy.withOpacity(0.7),
                      ),
                      child: _showPayButtonSpinner
                          ? const SizedBox(
                              height: 22,
                              width: 22,
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

