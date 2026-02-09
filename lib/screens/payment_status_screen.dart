import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fawry_sdk/fawry_sdk.dart';
import 'package:fawry_sdk/model/response.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'orders_screen.dart';
import 'menu_screen.dart';
import 'main_navigation.dart';
import '../state/cart_provider.dart';
import '../state/orders_provider.dart';
import '../models/order.dart';
import '../models/cart_item.dart';
import '../utils/app_colors.dart';
import '../utils/order_number_generator.dart';
import 'package:provider/provider.dart';

/// Screen that displays payment status and reference number
/// Shows the reference number immediately after payment initiation
/// Updates status when payment is confirmed via Fawry callback
class PaymentStatusScreen extends StatefulWidget {
  final String referenceNumber; // Fawry reference number (for display)
  final double amount;
  final String merchantRefNum; // Merchant reference number (for status API calls)
  final String? notes; // Order notes from checkout
  final String? initialStatus; // Initial status if known (e.g., "FAILED", "101", "102")

  const PaymentStatusScreen({
    super.key,
    required this.referenceNumber,
    required this.amount,
    required this.merchantRefNum, // Make it required - we need this for status checks
    this.notes,
    this.initialStatus, // Optional initial status
  });

  @override
  State<PaymentStatusScreen> createState() => _PaymentStatusScreenState();
}

class _PaymentStatusScreenState extends State<PaymentStatusScreen> {
  String _status = 'Pending';
  String? _statusMessage;
  bool _isPaid = false;
  bool _isFailed = false;
  bool _isExpired = false;
  bool _orderHandled = false; // Flag to prevent duplicate order creation
  bool _failedOrderHandled = false; // Flag to prevent duplicate failed order creation
  bool _expiredOrderHandled = false; // Flag to prevent duplicate expired order creation
  StreamSubscription? _paymentStreamSubscription;
  Timer? _pollingTimer;
  bool _isPolling = false;
  
  // Fawry credentials (same as in checkout)
  static const String _merchantCode = "770000021908";
  static const String _secureHashKey = "b4afb94e0a554815a17ed505de2f9e67";

  @override
  void initState() {
    super.initState();
    
    // Check initial status if provided (e.g., from checkout screen when payment fails immediately)
    // NOTE: 102 with UNPAID = pending (awaiting payment at Fawry), NOT failed - do not pass 102 as initialStatus
    if (widget.initialStatus != null) {
      final initialStatusStr = widget.initialStatus!.toUpperCase();
      debugPrint("PaymentStatusScreen: Initial status provided: $initialStatusStr");
      
      // Only 101, FAILED, CANCELLED = immediate failure. 102 = pending (user got ref number)
      if (initialStatusStr == '101' || 
          initialStatusStr == 'FAILED' || 
          initialStatusStr == 'CANCELLED') {
        debugPrint("❌ Payment already failed - handling immediately");
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_failedOrderHandled && !_orderHandled) {
            setState(() {
              _status = 'Failed';
              _isFailed = true;
              _statusMessage = 'Payment failed';
            });
            _handleFailedOrder();
          }
        });
        return; // Don't start listening/polling if already failed
      } else if (initialStatusStr == 'EXPIRED' || 
                 initialStatusStr == 'TIMEOUT' || 
                 initialStatusStr == 'EXPIRY') {
        debugPrint("⏰ Payment already expired - handling immediately");
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_expiredOrderHandled && !_orderHandled) {
            setState(() {
              _status = 'Expired';
              _isExpired = true;
              _statusMessage = 'Payment expired';
            });
            _handleExpiredOrder();
          }
        });
        return; // Don't start listening/polling if already expired
      }
    }
    
    _startListening();
    _startPolling(); // Start polling for payment status
  }

  @override
  void dispose() {
    _paymentStreamSubscription?.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    // Poll every 5 seconds to check payment status
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (_isPaid || _isPolling) return; // Stop polling if already paid or currently checking
      
      await _checkPaymentStatus();
    });
    
    // Also check immediately
    _checkPaymentStatus();
  }

  Future<void> _checkPaymentStatus() async {
    if (_isPolling || _isPaid) return;
    
    // Use merchantRefNum for status checks (not the Fawry reference number)
    if (widget.merchantRefNum.isEmpty) {
      debugPrint("⚠️ No merchantRefNum available for status check");
      return;
    }
    
    setState(() => _isPolling = true);
    
    try {
      // Generate signature: SHA-256(merchantCode + merchantRefNumber + secureKey)
      // IMPORTANT: Use merchantRefNum (the one we generated), not the Fawry reference number
      final signatureString = _merchantCode + widget.merchantRefNum + _secureHashKey;
      final signature = sha256.convert(utf8.encode(signatureString)).toString();
      
      // Build the API URL
      final uri = Uri.parse(
        'https://atfawry.fawrystaging.com/ECommerceWeb/Fawry/payments/status/v2'
      ).replace(queryParameters: {
        'merchantCode': _merchantCode,
        'merchantRefNumber': widget.merchantRefNum, // Use merchantRefNum, not referenceNumber
        'signature': signature,
      });

      debugPrint("Checking payment status for merchantRefNum: ${widget.merchantRefNum}");
      debugPrint("Status check URL: $uri");

      final response = await http.get(uri);

      debugPrint("Status check response: ${response.statusCode}");
      debugPrint("Status check body: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Fawry API returns 'orderStatus' field (not 'paymentStatus')
        // Convert to uppercase string for consistent comparison
        final orderStatusStr = (data['orderStatus'] ?? 
                               data['paymentStatus'] ?? 
                               data['status'] ?? 
                               data['statusCode']?.toString() ?? 
                               '').toString().toUpperCase();
        
        final statusDescription = data['statusDescription'] ?? 
                                 data['message'] ?? 
                                 data['description'] ?? 
                                 '';

        debugPrint("✅ Order status from API: $orderStatusStr");
        debugPrint("Status description: $statusDescription");

        // Check for PAID status (Fawry returns "PAID" in orderStatus field)
        if (orderStatusStr == 'PAID' || 
            orderStatusStr == 'SUCCESS' ||
            orderStatusStr == '200') {
          debugPrint("✅✅✅ PAYMENT CONFIRMED - Status is PAID! ✅✅✅");
          _pollingTimer?.cancel();
          if (mounted && !_orderHandled) {
            setState(() {
              _status = 'Paid';
              _isPaid = true;
              _statusMessage = statusDescription.isNotEmpty ? statusDescription : 'Payment confirmed!';
              _orderHandled = true; // Mark as handled to prevent duplicates
            });
            _completeOrder();
          }
        } else if (orderStatusStr == 'FAILED' || 
                   orderStatusStr == 'CANCELLED' ||
                   orderStatusStr == '101') {
          _pollingTimer?.cancel();
          if (mounted && !_failedOrderHandled && !_orderHandled) {
            setState(() {
              _status = 'Failed';
              _isFailed = true;
              _statusMessage = statusDescription.isNotEmpty ? statusDescription : 'Payment failed';
            });
            _handleFailedOrder();
          }
        } else if (orderStatusStr == 'EXPIRED' || 
                   orderStatusStr == 'TIMEOUT' ||
                   orderStatusStr == 'EXPIRY') {
          _pollingTimer?.cancel();
          if (mounted && !_expiredOrderHandled && !_orderHandled) {
            setState(() {
              _status = 'Expired';
              _isExpired = true;
              _statusMessage = statusDescription.isNotEmpty ? statusDescription : 'Payment expired';
            });
            _handleExpiredOrder();
          }
        } else if (orderStatusStr == 'UNPAID' ||
                   orderStatusStr == 'PENDING' ||
                   orderStatusStr == '') {
          // Keep as pending, continue polling
          debugPrint("⏳ Still waiting - Status: $orderStatusStr");
          if (mounted) {
            setState(() {
              _status = 'Pending';
              _statusMessage = statusDescription.isNotEmpty ? statusDescription : 'Waiting for payment...';
            });
          }
        } else {
          // Unknown status, log it but keep polling
          debugPrint("⚠️ Unknown order status: $orderStatusStr");
          if (mounted) {
            setState(() {
              _status = 'Pending';
              _statusMessage = 'Waiting for payment confirmation...';
            });
          }
        }
      } else {
        debugPrint("Status check failed with status code: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("PaymentStatusScreen: Polling error - $e");
      // Don't show error to user, just continue polling
    } finally {
      if (mounted) {
        setState(() => _isPolling = false);
      }
    }
  }

  void _startListening() {
    // Listen directly to FawrySDK stream to avoid conflicts with FawryPayment.listen
    _paymentStreamSubscription = FawrySDK.instance.callbackResultStream().listen(
      (event) {
        if (!mounted) return;

        debugPrint("PaymentStatusScreen: RAW EVENT - $event");

        try {
          final response = ResponseStatus.fromJson(jsonDecode(event));
          
          debugPrint("PaymentStatusScreen: Received callback - ${response.status}");
          debugPrint("PaymentStatusScreen: Message - ${response.message ?? ''}");
          debugPrint("PaymentStatusScreen: Error - ${response.error ?? ''}");

          final status = (response.status ?? "").toUpperCase();
          final message = response.message ?? '';
          final error = response.error ?? '';

          // Parse orderStatus from data - 102 with UNPAID = awaiting payment, NOT failed
          String? orderStatusFromData;
          if (response.data != null) {
            try {
              final dataJson = jsonDecode(response.data!);
              if (dataJson is Map) {
                orderStatusFromData = (dataJson['orderStatus'] ?? '').toString().toUpperCase();
              }
            } catch (_) {}
          }

          debugPrint("PaymentStatusScreen: Status=$status, orderStatus=$orderStatusFromData");

          setState(() {
            _statusMessage = message.isNotEmpty ? message : (error.isNotEmpty && status != "PAID" && status != "SUCCESS" ? error : '');
            
            // Check for PAID/SUCCESS first - prioritize success
            if (status == "PAID" || status == "SUCCESS" || status == "200" || orderStatusFromData == 'PAID') {
              _status = 'Paid';
              _isPaid = true;
              debugPrint("✅ Payment successful detected - Status: $status");
            } else if (status == "101" || 
                      status == "FAILED" || 
                      status == "CANCELLED" ||
                      orderStatusFromData == 'FAILED') {
              // 102 with UNPAID = pending (user got ref number, awaiting payment at Fawry)
              _status = 'Failed';
              _isFailed = true;
              debugPrint("❌ Payment failed detected - Status: $status");
            } else if (status == "102" && (orderStatusFromData == 'UNPAID' || orderStatusFromData == 'PENDING' || orderStatusFromData == '')) {
              // 102 + UNPAID = pending - user completed flow, awaiting payment
              _status = 'Pending';
              debugPrint("⏳ Payment pending - Status: 102, orderStatus: $orderStatusFromData");
            } else if (status == "EXPIRED" || status == "TIMEOUT" || status == "EXPIRY") {
              _status = 'Expired';
              _isExpired = true;
            } else if (status == "PENDING" || status == "102" || status == "") {
              _status = 'Pending';
            } else {
              _status = status;
            }
          });

          // Handle different statuses (only if not already handled)
          if (_isPaid && !_orderHandled && !_failedOrderHandled && !_expiredOrderHandled) {
            _orderHandled = true; // Mark as handled to prevent duplicates
            _completeOrder();
          } else if (_isFailed && !_failedOrderHandled && !_orderHandled) {
            debugPrint("🔄 Calling _handleFailedOrder() from callback listener");
            _handleFailedOrder();
          } else if (_isExpired && !_expiredOrderHandled && !_orderHandled) {
            _handleExpiredOrder();
          } else if (_orderHandled || _failedOrderHandled || _expiredOrderHandled) {
            debugPrint("⚠️ Order already handled, skipping duplicate processing");
          }
        } catch (e) {
          debugPrint("PaymentStatusScreen: Parse error - $e");
          if (!mounted) return;
          setState(() {
            _status = 'Error';
            _statusMessage = 'Payment error: $e';
          });
        }
      },
      onError: (e) {
        if (!mounted) return;
        debugPrint("PaymentStatusScreen: Stream error - $e");
        setState(() {
          _status = 'Error';
          _statusMessage = 'Payment error: $e';
        });
      },
    );
  }

  void _completeOrder() async {
    final cart = Provider.of<CartProvider>(context, listen: false);
    final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      debugPrint("❌ Cannot complete order - user not logged in");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: User not logged in')),
        );
      }
      return;
    }
    
    // Save cart items before clearing (properly typed)
    final cartItems = List<CartItem>.from(cart.items);
    
    if (cartItems.isEmpty) {
      debugPrint("❌ Cannot complete order - cart is empty");
      return;
    }
    
    // Get the next order number for this truck
    final orderNumber = await OrderNumberGenerator.getNextOrderNumber(cart.currentTruckId);
    
    // Create order with all details
    final now = DateTime.now();
    final order = Order(
      id: 'order_${now.millisecondsSinceEpoch}',
      fawryReferenceNumber: widget.referenceNumber,
      merchantRefNumber: widget.merchantRefNum,
      items: cartItems,
      total: widget.amount,
      subtotal: cart.subtotal,
      fawryFees: widget.amount > cart.subtotal ? widget.amount - cart.subtotal : null,
      createdAt: now,
      status: 'paid', // Mark as paid since payment was confirmed
      notes: widget.notes,
      truckId: cart.currentTruckId, // Include truck ID from cart
      displayOrderNumber: orderNumber, // Sequential order number per truck
    );
    
    debugPrint("📦 Creating order for user: ${user.email}");
    debugPrint("   - Order ID: ${order.id}");
    debugPrint("   - Items: ${cartItems.length}");
    debugPrint("   - Total: ${order.total} EGP");
    debugPrint("   - Subtotal: ${order.subtotal} EGP");
    debugPrint("   - Fawry Ref: ${order.fawryReferenceNumber}");
    debugPrint("   - Merchant Ref: ${order.merchantRefNumber}");
    debugPrint("   - Status: ${order.status}");
    debugPrint("   - Created At: ${order.createdAt}");
    
    // Save order to provider (which will save to Firestore 'orders' collection)
    debugPrint("🔄 Calling ordersProvider.addOrder()...");
    try {
      await ordersProvider.addOrder(order);
      debugPrint("✅ ordersProvider.addOrder() completed successfully");
    } catch (e, stackTrace) {
      debugPrint("❌❌❌ ERROR in ordersProvider.addOrder() ❌❌❌");
      debugPrint("   Error: $e");
      debugPrint("   Stack Trace: $stackTrace");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving order: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
    
    // Clear cart
    cart.clear();

    // Wait a moment to show success state
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Navigate to main navigation with orders tab selected (index 1)
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const MainNavigation(initialIndex: 1)),
      (route) => false,
    );

    // Show success snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment confirmed! ✅\nRef: ${widget.referenceNumber}'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _handleFailedOrder() async {
    // Prevent duplicate failed order handling
    if (_failedOrderHandled || _orderHandled) {
      debugPrint("⚠️ Failed order already handled, skipping duplicate handling");
      return;
    }
    
    // Mark as handled immediately to prevent race conditions
    _failedOrderHandled = true;
    
    debugPrint("❌ Payment failed - NOT creating order (only successful payments create orders)");
    debugPrint("   - Fawry Ref: ${widget.referenceNumber}");
    debugPrint("   - User can try again with the same cart");
    
    // Don't create an order for failed payments
    // Don't consume an order number
    // Don't clear cart - let user try again
    
    // Wait a moment to show failed state
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Navigate back to checkout or menu (not orders screen since no order was created)
    try {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const MainNavigation(initialIndex: 0)),
        (route) => false,
      );

      // Show failure snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Payment failed. Please try again.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint("⚠️ Error navigating after failed payment: $e");
    }
  }

  void _handleExpiredOrder() async {
    // Prevent duplicate expired order handling
    if (_expiredOrderHandled || _orderHandled) {
      debugPrint("⚠️ Expired order already handled, skipping duplicate handling");
      return;
    }
    
    // Mark as handled immediately to prevent race conditions
    _expiredOrderHandled = true;
    
    debugPrint("⏰ Payment expired - NOT creating order (only successful payments create orders)");
    debugPrint("   - Fawry Ref: ${widget.referenceNumber}");
    debugPrint("   - User can try again with the same cart");
    
    // Don't create an order for expired payments
    // Don't consume an order number
    // Don't clear cart - let user try again
    
    // Wait a moment to show expired state
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Navigate back to checkout or menu (not orders screen since no order was created)
    try {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const MainNavigation(initialIndex: 0)),
        (route) => false,
      );

      // Show expired snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Payment expired. Please try again.'),
            backgroundColor: AppColors.burgundy,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint("⚠️ Error navigating after expired payment: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Status'),
        automaticallyImplyLeading: false, // Prevent back button
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Status Icon
              Icon(
                _isPaid 
                  ? Icons.check_circle 
                  : _isFailed 
                    ? Icons.cancel 
                    : _isExpired
                      ? Icons.cancel
                      : Icons.pending,
                size: 100,
                color: _isPaid 
                  ? Colors.green 
                  : _isFailed 
                    ? Colors.red 
                    : _isExpired
                      ? AppColors.burgundy
                      : AppColors.burgundy,
              ),
              const SizedBox(height: 32),

              // Status Text
              Text(
                _status,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _isPaid 
                    ? Colors.green 
                    : _isFailed 
                      ? Colors.red 
                      : _isExpired
                        ? AppColors.burgundy
                        : AppColors.burgundy,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (_statusMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _statusMessage!,
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 48),

              // Reference Number Card
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Text(
                        'Reference Number',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SelectableText(
                        widget.referenceNumber,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Show this number at the POS machine',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Amount
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Amount',
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          '${widget.amount.toStringAsFixed(2)} EGP',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Instructions
              if (!_isPaid)
                Card(
                  color: Colors.blue[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue[700]),
                            const SizedBox(width: 8),
                            Text(
                              'Instructions',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '1. Go to the POS machine\n'
                          '2. Enter the reference number above\n'
                          '3. Complete your payment\n'
                          '4. Status will update automatically when payment is confirmed',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 13,
                          ),
                          maxLines: 6,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),

              if (_isPaid) ...[
                const SizedBox(height: 24),
                Card(
                  color: Colors.green[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Payment confirmed! Redirecting...',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.green[700],
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              
              if (_isFailed) ...[
                const SizedBox(height: 24),
                Card(
                  color: Colors.red[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(Icons.error, color: Colors.red[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Payment failed! Order saved to history. Redirecting...',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.red[700],
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              
              if (_isExpired) ...[
                const SizedBox(height: 24),
                Card(
                  color: AppColors.burgundy.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(Icons.schedule, color: AppColors.burgundy),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Payment expired! Order saved to history. Redirecting...',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppColors.burgundy,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Polling indicator
              if (_isPolling && !_isPaid)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Checking payment status...',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),

              // Loading indicator if pending
              if (!_isPaid && _status == 'Pending' && !_isPolling)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Waiting for payment confirmation...',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

