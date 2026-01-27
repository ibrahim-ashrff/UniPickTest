import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/order.dart' as app_models;
import '../models/cart_item.dart';
import '../models/menu_item.dart';

class OrdersProvider extends ChangeNotifier {
  final List<app_models.Order> _orders = [];
  bool _isLoading = false;

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
    notifyListeners();
  }

  // Add a new order (saves to Firestore if status is 'paid' or 'failed')
  Future<void> addOrder(app_models.Order order) async {
    _orders.add(order);
    notifyListeners();

    // Save to Firestore if order is paid, failed, or expired
    final status = order.status.toLowerCase();
    if (status != 'paid' && status != 'failed' && status != 'expired') {
      debugPrint("Order not saved to Firestore - status is not 'paid', 'failed', or 'expired': ${order.status}");
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

  // Load orders from Firestore
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
          
          final order = app_models.Order(
            id: doc.id,
            fawryReferenceNumber: data['fawryReferenceNumber'] ?? '',
            merchantRefNumber: data['merchantRefNumber'] ?? '',
            items: cartItems,
            total: (data['total'] ?? 0).toDouble(),
            subtotal: (data['subtotal'] ?? 0).toDouble(),
            fawryFees: data['fawryFees']?.toDouble(),
            createdAt: createdAt,
            status: data['status'] ?? 'pending',
            notes: data['notes'],
            invoiceNumber: data['invoiceNumber'],
            businessRefNumber: data['businessRefNumber'],
            truckId: data['truckId'],
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
        createdAt: oldOrder.createdAt,
        status: newStatus,
        notes: oldOrder.notes,
        invoiceNumber: oldOrder.invoiceNumber,
        businessRefNumber: oldOrder.businessRefNumber,
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

