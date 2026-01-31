import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Utility class to generate sequential order numbers per truck
class OrderNumberGenerator {
  /// Get the next order number for a specific truck
  /// Returns 1 if this is the first order for the truck
  static Future<int> getNextOrderNumber(String? truckId) async {
    if (truckId == null || truckId.isEmpty) {
      debugPrint("⚠️ No truckId provided, returning 1");
      return 1;
    }

    try {
      // Query all orders for this truck to find the highest order number
      final snapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('truckId', isEqualTo: truckId)
          .where('displayOrderNumber', isGreaterThan: 0)
          .orderBy('displayOrderNumber', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        // This is the first order for this truck
        debugPrint("✅ First order for truck $truckId - returning 1");
        return 1;
      }

      // Get the highest order number and increment it
      final highestOrder = snapshot.docs.first.data();
      final highestNumber = highestOrder['displayOrderNumber'] as int? ?? 0;
      final nextNumber = highestNumber + 1;
      
      debugPrint("✅ Next order number for truck $truckId: $nextNumber (previous highest: $highestNumber)");
      return nextNumber;
    } catch (e) {
      debugPrint("❌ Error getting next order number: $e");
      // If there's an error (e.g., missing index), try a different approach
      // Query all orders and find max in memory
      try {
        final allOrdersSnapshot = await FirebaseFirestore.instance
            .collection('orders')
            .where('truckId', isEqualTo: truckId)
            .get();

        int maxNumber = 0;
        for (var doc in allOrdersSnapshot.docs) {
          final data = doc.data();
          final orderNumber = data['displayOrderNumber'] as int? ?? 0;
          if (orderNumber > maxNumber) {
            maxNumber = orderNumber;
          }
        }

        final nextNumber = maxNumber + 1;
        debugPrint("✅ Next order number for truck $truckId (fallback method): $nextNumber");
        return nextNumber;
      } catch (e2) {
        debugPrint("❌ Fallback method also failed: $e2");
        // Last resort: return 1
        return 1;
      }
    }
  }
}

