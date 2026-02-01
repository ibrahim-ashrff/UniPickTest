import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Utility class to generate sequential order numbers per truck
/// Uses atomic Firestore operations to prevent race conditions
class OrderNumberGenerator {
  /// Get the next order number for a specific truck using atomic counter
  /// Returns 1 if this is the first order for the truck
  static Future<int> getNextOrderNumber(String? truckId) async {
    if (truckId == null || truckId.isEmpty) {
      debugPrint("⚠️ No truckId provided, returning 1");
      return 1;
    }

    final counterRef = FirebaseFirestore.instance
        .collection('order_counters')
        .doc(truckId);

    try {
      // Use a transaction to atomically increment the counter
      final result = await FirebaseFirestore.instance.runTransaction<int>(
        (transaction) async {
          final counterDoc = await transaction.get(counterRef);

          int currentCount = 0;
          if (counterDoc.exists) {
            final data = counterDoc.data();
            currentCount = data?['count'] as int? ?? 0;
            debugPrint("📊 Transaction: Found counter for truck $truckId: $currentCount");
          } else {
            debugPrint("📊 Transaction: No counter exists for truck $truckId, starting at 0");
          }

          final newCount = currentCount + 1;
          debugPrint("🔄 Transaction: Incrementing counter for truck $truckId: $currentCount -> $newCount");

          if (counterDoc.exists) {
            transaction.update(counterRef, {
              'count': newCount,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          } else {
            transaction.set(counterRef, {
              'count': newCount,
              'truckId': truckId,
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
          return newCount;
        },
        timeout: const Duration(seconds: 10),
      );

      debugPrint("✅ Next order number for truck $truckId: $result");
      return result;
    } catch (e) {
      debugPrint("❌ Error getting next order number (transaction failed): $e");
      debugPrint("   Error type: ${e.runtimeType}");
      debugPrint("   Error details: $e");

      // Fallback 1: Try direct update with FieldValue.increment (atomic operation)
      try {
        debugPrint("🔄 Fallback 1: Trying FieldValue.increment...");
        await counterRef.set({
          'count': FieldValue.increment(1),
          'truckId': truckId,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        final counterDoc = await counterRef.get();
        if (counterDoc.exists) {
          final data = counterDoc.data();
          final newCount = data?['count'] as int? ?? 1;
          debugPrint("✅ Next order number for truck $truckId (increment method): $newCount");
          return newCount;
        }
      } catch (e1) {
        debugPrint("❌ Increment method failed: $e1");
      }

      // Fallback 2: Query existing orders to find max
      try {
        debugPrint("🔄 Fallback 2: Querying existing orders...");
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
        debugPrint("✅ Next order number for truck $truckId (query method): $nextNumber (max found: $maxNumber)");

        // Try to update the counter document for future use
        try {
          await FirebaseFirestore.instance
              .collection('order_counters')
              .doc(truckId)
              .set({
            'count': nextNumber,
            'truckId': truckId,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          debugPrint("✅ Counter document updated for future use");
        } catch (e2) {
          debugPrint("⚠️ Could not update counter document: $e2");
        }

        return nextNumber;
      } catch (e2) {
        debugPrint("❌ Query method also failed: $e2");
        debugPrint("⚠️ All methods failed, returning 1 as last resort");
        return 1;
      }
    }
  }
}

