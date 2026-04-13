import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main_navigation.dart';
import '../widgets/animated_payment_success_header.dart';
import '../widgets/item_thumbnail.dart';
import '../state/cart_provider.dart';
import '../state/orders_provider.dart';
import '../models/order.dart';
import '../models/cart_item.dart';
import '../utils/app_colors.dart';
import '../utils/order_number_generator.dart';
import '../utils/order_receipt_pdf.dart';
import 'package:provider/provider.dart';

/// Screen that displays payment status (Pending / Paid / Failed).
/// Updates status when payment is confirmed via Fawry callback.
class PaymentStatusScreen extends StatefulWidget {
  final String referenceNumber; // Fawry reference for Pay at Fawry / tracking; shown when valid
  final double amount;
  final String merchantRefNum; // Merchant reference number (for status API calls)
  final String? notes; // Order notes from checkout
  final String? initialStatus; // Initial status if known (e.g., "FAILED", "101", "102")

  const PaymentStatusScreen({
    super.key,
    required this.referenceNumber,
    required this.amount,
    required this.merchantRefNum,
    this.notes,
    this.initialStatus,
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
  Timer? _pollingTimer;
  bool _isPolling = false;
  /// Set after payment succeeds and the order is built (used for PDF receipt).
  Order? _savedOrder;
  bool _receiptExportBusy = false;

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
    
    // Only checkout listens to Fawry stream; this screen relies on polling + initialStatus to avoid duplicate listeners
    _startPolling();
  }

  @override
  void dispose() {
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
          if (mounted) {
            setState(() {
              _status = 'Paid';
              _isPaid = true;
              _statusMessage = statusDescription.isNotEmpty ? statusDescription : 'Payment confirmed!';
            });
            _completeOrder(); // Gate inside _completeOrder prevents duplicate runs
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

  void _completeOrder() async {
    // Single gate: only one code path can run order creation (prevents race with polling/callbacks)
    if (_orderHandled) {
      debugPrint("⚠️ _completeOrder already handled, skipping duplicate");
      return;
    }
    _orderHandled = true;

    final cart = Provider.of<CartProvider>(context, listen: false);
    final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      debugPrint("❌ Cannot complete order - user not logged in");
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
      unipickFees: CartProvider.unipickFeeAmount,
      fawryFees: widget.amount > cart.checkoutTotal
          ? widget.amount - cart.checkoutTotal
          : null,
      createdAt: now,
      status: 'paid', // Mark as paid since payment was confirmed
      notes: widget.notes,
      truckId: cart.currentTruckId, // Include truck ID from cart
      displayOrderNumber: orderNumber, // Sequential order number per truck
    );

    if (mounted) {
      setState(() => _savedOrder = order);
    }

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
    }
    
    // Clear cart
    cart.clear();

    // Stay on this screen; user taps X in the app bar to open the Orders tab.
    if (!mounted) return;
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

      debugPrint('Payment failed — navigated home; user can retry from cart.');
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

      debugPrint('Payment expired — navigated home; user can retry from cart.');
    } catch (e) {
      debugPrint("⚠️ Error navigating after expired payment: $e");
    }
  }

  void _goToOrdersTab() {
    _pollingTimer?.cancel();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => const MainNavigation(initialIndex: 1),
      ),
      (route) => false,
    );
  }

  Future<void> _downloadReceipt() async {
    final order = _savedOrder;
    if (order == null) return;
    if (kIsWeb) {
      debugPrint('Receipt PDF share is not supported on web.');
      return;
    }
    setState(() => _receiptExportBusy = true);
    try {
      await shareOrderReceiptPdf(order);
    } catch (e, st) {
      debugPrint('Receipt PDF failed: $e\n$st');
    } finally {
      if (mounted) setState(() => _receiptExportBusy = false);
    }
  }

  /// Line items + subtotal / UniPick / processing / total — matches receipt when [Order] is saved;
  /// while payment is pending, uses the live [CartProvider] cart.
  Widget _buildPaymentSummarySection(BuildContext context) {
    final saved = _savedOrder;
    final cart = Provider.of<CartProvider>(context);

    final List<CartItem> lines;
    final double subtotal;
    final double? unipickFees;
    final double? processingFees;
    final double total;

    if (saved != null) {
      lines = saved.items;
      subtotal = saved.subtotal;
      unipickFees = saved.unipickFees;
      processingFees = saved.fawryFees;
      total = saved.total;
    } else if (cart.items.isNotEmpty) {
      lines = cart.items;
      subtotal = cart.subtotal;
      unipickFees = CartProvider.unipickFeeAmount;
      processingFees = widget.amount > cart.checkoutTotal + 1e-6
          ? widget.amount - cart.checkoutTotal
          : null;
      total = widget.amount;
    } else {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                '${widget.amount.toStringAsFixed(2)} EGP',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Items',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                ...lines.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ItemThumbnail(
                          imageUrl: item.menuItem.imageUrl,
                          size: 48,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.menuItem.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (item.menuItem.description.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  item.menuItem.description,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${item.quantity} × ${item.menuItem.price.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${item.total.toStringAsFixed(2)} EGP',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _paymentSummaryMoneyRow(context, 'Subtotal', subtotal),
                if (unipickFees != null && unipickFees > 0) ...[
                  const SizedBox(height: 8),
                  _paymentSummaryMoneyRow(context, 'UniPick fees', unipickFees),
                ],
                if (processingFees != null && processingFees > 0) ...[
                  const SizedBox(height: 8),
                  _paymentSummaryMoneyRow(
                    context,
                    'Processing fees',
                    processingFees,
                  ),
                ],
                const Divider(height: 24),
                _paymentSummaryMoneyRow(
                  context,
                  'Total',
                  total,
                  emphasized: true,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _paymentSummaryMoneyRow(
    BuildContext context,
    String label,
    double amount, {
    bool emphasized = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: emphasized ? 20 : 16,
            fontWeight: emphasized ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          '${amount.toStringAsFixed(2)} EGP',
          style: TextStyle(
            fontSize: emphasized ? 20 : 16,
            fontWeight: FontWeight.bold,
            color: emphasized ? Colors.red : null,
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptBottomBar(BuildContext context) {
    return Material(
      elevation: 12,
      shadowColor: Colors.black26,
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: _savedOrder == null
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.burgundy,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Preparing your receipt…',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[700],
                          ),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton(
                      onPressed: _goToOrdersTab,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.burgundy,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Continue to orders',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _receiptExportBusy ? null : _downloadReceipt,
                      icon: _receiptExportBusy
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.burgundy,
                              ),
                            )
                          : const Icon(Icons.download_rounded, size: 22),
                      label: Text(
                        _receiptExportBusy ? 'Creating PDF…' : 'Download receipt',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.burgundy,
                        side: const BorderSide(color: AppColors.burgundy, width: 1.2),
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Status'),
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.close, size: 22),
          tooltip: 'Orders',
          onPressed: _goToOrdersTab,
        ),
      ),
      bottomNavigationBar: _isPaid ? _buildReceiptBottomBar(context) : null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isPaid) ...[
                const AnimatedPaymentSuccessHeader(
                  subtitle: 'Payment confirmed!',
                ),
                const SizedBox(height: 28),
              ] else if (_isFailed || _isExpired) ...[
                Icon(
                  Icons.cancel,
                  size: 100,
                  color: _isFailed ? Colors.red : AppColors.burgundy,
                ),
                const SizedBox(height: 32),
                Text(
                  _status,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _isFailed ? Colors.red : AppColors.burgundy,
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
              ] else
                const SizedBox(height: 8),

              _buildPaymentSummarySection(context),
              const SizedBox(height: 16),

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
                          '• Pay with card: finish in the payment screen; status updates when payment is confirmed.\n'
                          '• Status refreshes automatically every few seconds.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

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

