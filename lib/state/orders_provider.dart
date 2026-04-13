import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/order.dart' as app_models;
import '../models/cart_item.dart';
import '../models/menu_item.dart';
import '../services/notification_service.dart';
import '../services/popular_menu_service.dart';

class OrdersProvider extends ChangeNotifier {
  final List<app_models.Order> _orders = [];
  bool _isLoading = false;
  // Track previous order statuses to detect changes
  final Map<String, String> _previousStatuses = {};
  bool _isInitialLoad = true;

  List<app_models.Order> get orders => List.unmodifiable(_orders);
  bool get isLoading => _isLoading;

  // Get orders sorted by date (newest first)
  List<app_models.Order> get sortedOrders {
    final sorted = List<app_models.Order>.from(_orders);
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  // Clear all orders (useful when user logs out)
  void clearOrders() {
    _orders.clear();
    _previousStatuses.clear();
    _isInitialLoad = true;
    notifyListeners();
  }

  // Add a new order (saves to Firestore if status is 'paid', 'failed', 'expired', or 'pending'/'unpaid')
  // UNPAID orders are normalized to 'pending' - never stored as 'failed' until payment explicitly fails
  Future<void> addOrder(app_models.Order order) async {
    _orders.add(order);
    notifyListeners();

    // Normalize status: 'unpaid' -> 'pending' (never treat unpaid as failed)
    String status = order.status.toLowerCase();
    if (status == 'unpaid') {
      status = 'pending';
    }

    // Save to Firestore for paid, failed, expired, or pending (awaiting payment)
    if (status != 'paid' && status != 'failed' && status != 'expired' && status != 'pending') {
      debugPrint("Order not saved to Firestore - status is not 'paid', 'failed', 'expired', or 'pending': ${order.status}");
      return;
    }

    // Save to Firestore
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        debugPrint("🔄 Starting Firestore save process...");
        debugPrint("   - User ID: ${user.uid}");
        debugPrint("   - User Email: ${user.email}");
        debugPrint("   - Order ID: ${order.id}");
        debugPrint("   - Order Status: ${order.status}");
        
        final orderData = order.toFirestoreJson();
        // Store normalized status (unpaid -> pending)
        orderData['status'] = status;
        debugPrint("   - Order data prepared (${orderData.length} fields)");
        
        // Add user information
        orderData['userId'] = user.uid;
        orderData['userEmail'] = user.email ?? '';
        orderData['userName'] = user.displayName ?? user.email ?? 'Unknown';
        orderData['customerName'] = user.displayName ?? user.email ?? 'Unknown';
        
        // Add truck ID if available (from cart)
        if (order.truckId != null) {
          orderData['truckId'] = order.truckId;
        }
        
        // Add timestamp using Firestore Timestamp
        orderData['createdAt'] = Timestamp.fromDate(order.createdAt);
        
        // Add payment information
        orderData['paymentMethod'] = 'Fawry';
        orderData['paymentReference'] = order.fawryReferenceNumber;
        
        // Add status-specific timestamps
        if (status == 'paid') {
          orderData['paidAt'] = Timestamp.now();
        } else if (status == 'failed') {
          orderData['failedAt'] = Timestamp.now();
        } else if (status == 'expired') {
          orderData['expiredAt'] = Timestamp.now();
        }
        
        debugPrint("   - Attempting to write to Firestore...");
        debugPrint("   - Collection: 'orders'");
        debugPrint("   - Document ID: '${order.id}'");
        
        // Save to Firestore 'orders' collection
        await FirebaseFirestore.instance
            .collection('orders')
            .doc(order.id)
            .set(orderData, SetOptions(merge: false));
        
        debugPrint("✅✅✅ Order successfully saved to Firestore 'orders' collection! ✅✅✅");
        debugPrint("   - Order ID: ${order.id}");
        debugPrint("   - Order Number: #${order.displayOrderNumber ?? 'N/A'} (Truck: ${order.truckId ?? 'N/A'})");
        debugPrint("   - User: ${user.email} (${user.uid})");
        debugPrint("   - Amount: ${order.total} EGP");
        debugPrint("   - Status: ${order.status}");
        debugPrint("   - Created At: ${order.createdAt}");
        if (status == 'paid') {
          debugPrint("   - Paid At: ${DateTime.now()}");
        } else if (status == 'failed') {
          debugPrint("   - Failed At: ${DateTime.now()}");
        } else if (status == 'expired') {
          debugPrint("   - Expired At: ${DateTime.now()}");
        }
        debugPrint("   - Fawry Ref: ${order.fawryReferenceNumber}");
        debugPrint("   - Items Count: ${order.items.length}");
        
        // Verify the write by reading it back
        try {
          final doc = await FirebaseFirestore.instance
              .collection('orders')
              .doc(order.id)
              .get();
          if (doc.exists) {
            debugPrint("✅ Verification: Document exists in Firestore!");
          } else {
            debugPrint("⚠️ Warning: Document was written but doesn't exist on read-back");
          }
        } catch (verifyError) {
          debugPrint("⚠️ Could not verify write: $verifyError");
        }
        
        // Clean up duplicates after saving
        await _cleanupDuplicateOrders(order, user.uid);

        if (status == 'paid' && order.truckId != null && order.items.isNotEmpty) {
          try {
            await PopularMenuService.incrementFromPaidOrder(order.truckId!, order.items);
          } catch (popErr) {
            debugPrint('⚠️ menu_item_popularity increment (non-fatal): $popErr');
          }
        }
        
      } catch (e, stackTrace) {
        debugPrint("❌❌❌ ERROR saving order to Firestore ❌❌❌");
        debugPrint("   Error: $e");
        debugPrint("   Error Type: ${e.runtimeType}");
        debugPrint("   Stack Trace: $stackTrace");
        
        // Check if it's a permissions error
        if (e.toString().contains('permission') || e.toString().contains('PERMISSION_DENIED')) {
          debugPrint("   ⚠️ This looks like a Firestore security rules issue!");
          debugPrint("   ⚠️ Make sure your Firestore rules allow writes to 'orders' collection");
        }
      }
    } else {
      debugPrint("❌ Cannot save order - user is not logged in");
    }
  }

  // Get real-time stream of orders for the current user
  Stream<List<app_models.Order>> getOrdersStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return FirebaseFirestore.instance
        .collection('orders')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
      final List<app_models.Order> orders = [];
      
      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          
          // Reconstruct CartItems from stored data
          List<CartItem> cartItems = [];
          if (data['items'] != null && data['items'] is List) {
            for (var itemData in data['items']) {
              if (itemData is Map) {
                try {
                  final menuItem = MenuItem(
                    id: itemData['menuItemId'] ?? '',
                    name: itemData['menuItemName'] ?? 'Unknown Item',
                    description: itemData['menuItemDescription'] ?? '',
                    price: (itemData['price'] ?? 0).toDouble(),
                  );
                  final cartItem = CartItem(
                    menuItem: menuItem,
                    quantity: itemData['quantity'] ?? 1,
                  );
                  cartItems.add(cartItem);
                } catch (e) {
                  debugPrint("   ⚠️ Error reconstructing cart item: $e");
                }
              }
            }
          }
          
          final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
          // Normalize: 'unpaid' -> 'pending' (never treat unpaid as failed)
          String orderStatus = (data['status'] ?? 'pending').toString().toLowerCase();
          if (orderStatus == 'unpaid') orderStatus = 'pending';
          
          final order = app_models.Order(
            id: doc.id,
            fawryReferenceNumber: data['fawryReferenceNumber'] ?? '',
            merchantRefNumber: data['merchantRefNumber'] ?? '',
            items: cartItems,
            total: (data['total'] ?? 0).toDouble(),
            subtotal: (data['subtotal'] ?? 0).toDouble(),
            fawryFees: data['fawryFees']?.toDouble(),
            unipickFees: data['unipickFees']?.toDouble(),
            createdAt: createdAt,
            status: orderStatus,
            notes: data['notes'],
            invoiceNumber: data['invoiceNumber'],
            businessRefNumber: data['businessRefNumber'],
            truckId: data['truckId'],
            displayOrderNumber: data['displayOrderNumber'] as int?,
          );
          orders.add(order);
        } catch (e) {
          debugPrint("   ❌ Error processing order ${doc.id}: $e");
        }
      }
      
      // Sort by createdAt (descending - newest first)
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      // Check for status changes and show notifications (skip on initial load)
      if (!_isInitialLoad) {
        _checkStatusChanges(orders);
      } else {
        // On initial load, just populate previous statuses without showing notifications
        for (final order in orders) {
          _previousStatuses[order.id] = order.status.toLowerCase();
        }
        _isInitialLoad = false;
      }
      
      // Update local state
      _orders.clear();
      _orders.addAll(orders);
      notifyListeners();
      
      return orders;
    });
  }

  // Load orders from Firestore (one-time fetch, kept for backward compatibility)
  Future<void> loadOrders() async {
    _isLoading = true;
    notifyListeners();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      debugPrint("🔄 Loading orders for user: ${user.uid}");
      
      // Query only by userId (no orderBy) to avoid needing composite index
      // We'll sort by createdAt in memory
      final snapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: user.uid)
          .get();

      debugPrint("📦 Found ${snapshot.docs.length} orders in Firestore");

      _orders.clear();
      final List<app_models.Order> loadedOrders = [];
      
      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          debugPrint("   - Processing order: ${doc.id}");
          
          // Reconstruct CartItems from stored data
          List<CartItem> cartItems = [];
          if (data['items'] != null && data['items'] is List) {
            for (var itemData in data['items']) {
              if (itemData is Map) {
                try {
                  final menuItem = MenuItem(
                    id: itemData['menuItemId'] ?? '',
                    name: itemData['menuItemName'] ?? 'Unknown Item',
                    description: itemData['menuItemDescription'] ?? '',
                    price: (itemData['price'] ?? 0).toDouble(),
                  );
                  final cartItem = CartItem(
                    menuItem: menuItem,
                    quantity: itemData['quantity'] ?? 1,
                  );
                  cartItems.add(cartItem);
                } catch (e) {
                  debugPrint("   ⚠️ Error reconstructing cart item: $e");
                }
              }
            }
          }
          
          final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
          // Normalize: 'unpaid' -> 'pending' (never treat unpaid as failed)
          String orderStatus = (data['status'] ?? 'pending').toString().toLowerCase();
          if (orderStatus == 'unpaid') orderStatus = 'pending';
          
          final order = app_models.Order(
            id: doc.id,
            fawryReferenceNumber: data['fawryReferenceNumber'] ?? '',
            merchantRefNumber: data['merchantRefNumber'] ?? '',
            items: cartItems,
            total: (data['total'] ?? 0).toDouble(),
            subtotal: (data['subtotal'] ?? 0).toDouble(),
            fawryFees: data['fawryFees']?.toDouble(),
            unipickFees: data['unipickFees']?.toDouble(),
            createdAt: createdAt,
            status: orderStatus,
            notes: data['notes'],
            invoiceNumber: data['invoiceNumber'],
            businessRefNumber: data['businessRefNumber'],
            truckId: data['truckId'],
            displayOrderNumber: data['displayOrderNumber'] as int?,
          );
          loadedOrders.add(order);
          debugPrint("   ✅ Loaded order: ${doc.id} (${cartItems.length} items, ${order.total} EGP)");
        } catch (e, stackTrace) {
          debugPrint("   ❌ Error processing order ${doc.id}: $e");
          debugPrint("   Stack trace: $stackTrace");
        }
      }
      
      // Sort by createdAt (descending - newest first)
      loadedOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      _orders.addAll(loadedOrders);
      debugPrint("✅ Successfully loaded ${_orders.length} orders");
      
    } catch (e, stackTrace) {
      debugPrint("❌❌❌ ERROR loading orders ❌❌❌");
      debugPrint("   Error: $e");
      debugPrint("   Error Type: ${e.runtimeType}");
      debugPrint("   Stack Trace: $stackTrace");
      
      // Check if it's a permissions error
      if (e.toString().contains('permission') || e.toString().contains('PERMISSION_DENIED')) {
        debugPrint("   ⚠️ This looks like a Firestore security rules issue!");
        debugPrint("   ⚠️ Make sure your Firestore rules allow reads from 'orders' collection");
      }
      
      // Check if it's an index error
      if (e.toString().contains('index') || e.toString().contains('FAILED_PRECONDITION')) {
        debugPrint("   ⚠️ This looks like a Firestore index issue!");
        debugPrint("   ⚠️ The query should work without an index now (orderBy removed)");
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  // Update order status
  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    final index = _orders.indexWhere((order) => order.id == orderId);
    if (index >= 0) {
      // Create updated order
      final oldOrder = _orders[index];
      final updatedOrder = app_models.Order(
        id: oldOrder.id,
        fawryReferenceNumber: oldOrder.fawryReferenceNumber,
        merchantRefNumber: oldOrder.merchantRefNumber,
        items: oldOrder.items,
        total: oldOrder.total,
        subtotal: oldOrder.subtotal,
        fawryFees: oldOrder.fawryFees,
        unipickFees: oldOrder.unipickFees,
        createdAt: oldOrder.createdAt,
        status: newStatus,
        notes: oldOrder.notes,
        invoiceNumber: oldOrder.invoiceNumber,
        businessRefNumber: oldOrder.businessRefNumber,
        truckId: oldOrder.truckId,
        displayOrderNumber: oldOrder.displayOrderNumber,
      );
      _orders[index] = updatedOrder;
      notifyListeners();

      // Update in Firestore
      try {
        await FirebaseFirestore.instance
            .collection('orders')
            .doc(orderId)
            .update({'status': newStatus});
      } catch (e) {
        debugPrint("Error updating order status: $e");
      }
    }
  }

  // Check for status changes and trigger notifications
  void _checkStatusChanges(List<app_models.Order> orders) {
    for (final order in orders) {
      final previousStatus = _previousStatuses[order.id];
      final currentStatus = order.status.toLowerCase();
      
      // If status changed and it's not the initial load
      if (previousStatus != null && previousStatus != currentStatus) {
        // Only notify for meaningful status changes (not from pending/paid initial states)
        final notifyStatuses = ['preparing', 'ready', 'completed', 'cancelled'];
        if (notifyStatuses.contains(currentStatus)) {
          final orderNumber = order.displayOrderNumber?.toString() ?? 
                            order.merchantRefNumber.substring(0, 6);
          
          NotificationService().showOrderStatusNotification(
            orderId: order.id,
            orderNumber: orderNumber,
            status: currentStatus,
          );
          
          debugPrint('🔔 Status changed for order ${order.id}: $previousStatus -> $currentStatus');
        }
      }
      
      // Update previous status
      _previousStatuses[order.id] = currentStatus;
    }
  }

  // Clean up duplicate orders - delete duplicates with same merchantRefNumber or fawryReferenceNumber
  Future<void> _cleanupDuplicateOrders(app_models.Order currentOrder, String userId) async {
    try {
      debugPrint("🔍 Checking for duplicate orders...");
      debugPrint("   - Merchant Ref: ${currentOrder.merchantRefNumber}");
      debugPrint("   - Fawry Ref: ${currentOrder.fawryReferenceNumber}");
      debugPrint("   - Current Status: ${currentOrder.status}");
      debugPrint("   - Current Order ID: ${currentOrder.id}");
      
      // Query for orders with the same merchantRefNumber
      final merchantRefQuery = await FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: userId)
          .where('merchantRefNumber', isEqualTo: currentOrder.merchantRefNumber)
          .get();
      
      // Query for orders with the same fawryReferenceNumber
      final fawryRefQuery = await FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: userId)
          .where('fawryReferenceNumber', isEqualTo: currentOrder.fawryReferenceNumber)
          .get();
      
      // Combine results and remove duplicates
      final allDuplicates = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
      for (var doc in merchantRefQuery.docs) {
        allDuplicates[doc.id] = doc;
      }
      for (var doc in fawryRefQuery.docs) {
        allDuplicates[doc.id] = doc;
      }
      
      if (allDuplicates.length <= 1) {
        debugPrint("✅ No duplicates found");
        return;
      }
      
      debugPrint("⚠️ Found ${allDuplicates.length} orders with same reference numbers");
      
      // Determine which order to keep (prefer 'paid' status, then most recent)
      String? orderToKeepId;
      DateTime? latestTimestamp;
      
      for (var doc in allDuplicates.values) {
        final data = doc.data();
        final docStatus = (data['status'] ?? '').toString().toLowerCase();
        final docCreatedAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        
        // Prefer paid status
        if (docStatus == 'paid') {
          orderToKeepId = doc.id;
          latestTimestamp = docCreatedAt;
          debugPrint("   - Found paid order to keep: ${doc.id}");
          break;
        }
        
        // Otherwise keep the most recent
        if (latestTimestamp == null || docCreatedAt.isAfter(latestTimestamp)) {
          orderToKeepId = doc.id;
          latestTimestamp = docCreatedAt;
        }
      }
      
      // Delete all duplicates except the one to keep
      int deletedCount = 0;
      for (var doc in allDuplicates.values) {
        if (doc.id != orderToKeepId) {
          try {
            await FirebaseFirestore.instance
                .collection('orders')
                .doc(doc.id)
                .delete();
            deletedCount++;
            final docData = doc.data();
            debugPrint("   🗑️ Deleted duplicate order: ${doc.id} (status: ${docData['status']})");
          } catch (e) {
            debugPrint("   ❌ Error deleting duplicate ${doc.id}: $e");
          }
        }
      }
      
      if (deletedCount > 0) {
        debugPrint("✅ Cleaned up $deletedCount duplicate order(s)");
      }
      
    } catch (e, stackTrace) {
      debugPrint("❌ Error cleaning up duplicates: $e");
      debugPrint("   Stack Trace: $stackTrace");
      // Don't throw - cleanup failure shouldn't prevent order creation
    }
  }
}

