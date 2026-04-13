import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../data/mock_food_trucks.dart';
import '../data/mock_menu.dart';
import '../models/cart_item.dart';
import '../models/food_truck.dart';
import '../models/menu_item.dart';
import '../models/popular_menu_slide.dart';

/// Firestore collection aggregating how often each (truck, menu item) was ordered (paid orders).
abstract class PopularMenuService {
  static const String collection = 'menu_item_popularity';

  static const List<String> _truckNameFieldKeys = [
    'name',
    'businessName',
    'truckName',
    'displayName',
    'title',
  ];

  static bool _isGenericFoodTruckLabel(String? raw) {
    final s = raw?.trim().toLowerCase() ?? '';
    return s == 'food truck' || s == 'foodtruck';
  }

  static FoodTruck? _mockTruckById(String truckId) {
    for (final t in mockFoodTrucks) {
      if (t.id == truckId) return t;
    }
    return null;
  }

  /// First non-empty, non-generic display name from a `food_trucks/{id}` document map.
  static String? nameFromTruckDocumentMap(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return null;
    for (final key in _truckNameFieldKeys) {
      final v = data[key];
      final s = v == null ? '' : v.toString().trim();
      if (s.isNotEmpty && !_isGenericFoodTruckLabel(s)) return s;
    }
    return null;
  }

  /// Human-readable truck name for UI: denormalized [preferredTruckName], then Firestore fields,
  /// then built-in mock list by [truckId], then a short neutral fallback (never the generic "Food Truck").
  static String resolvedDisplayName(
    String truckId,
    Map<String, dynamic>? firestoreTruckData, {
    String? preferredTruckName,
  }) {
    final preferred = preferredTruckName?.trim();
    if (preferred != null && preferred.isNotEmpty && !_isGenericFoodTruckLabel(preferred)) {
      return preferred;
    }
    final fromDoc = nameFromTruckDocumentMap(firestoreTruckData);
    if (fromDoc != null) return fromDoc;
    final mock = _mockTruckById(truckId);
    if (mock != null) return mock.name;
    if (truckId.length <= 20) return truckId;
    return '${truckId.substring(0, 8)}…';
  }

  /// Full [FoodTruck] for slides and menus; [preferredTruckName] is usually `menu_item_popularity.truckName`.
  static FoodTruck resolveFoodTruckForSlide(
    String truckId,
    Map<String, dynamic>? data, {
    String? preferredTruckName,
  }) {
    final name = resolvedDisplayName(truckId, data, preferredTruckName: preferredTruckName);
    final mock = _mockTruckById(truckId);
    final cuisine = (data?['cuisine'] ?? mock?.cuisine ?? '').toString();
    final double rating;
    if (data != null && data['rating'] is num) {
      rating = (data['rating'] as num).toDouble();
    } else {
      rating = mock?.rating ?? 0.0;
    }
    final imageUrl = (data?['imageUrl'] ?? mock?.imageUrl ?? '').toString();
    final description = data?['description']?.toString() ?? mock?.description;
    final bool isOpen;
    if (data != null) {
      final raw = data['isOpen'];
      isOpen = raw is bool ? raw : true;
    } else {
      isOpen = mock?.isOpen ?? true;
    }
    final ownerId = data?['ownerId']?.toString() ?? mock?.ownerId;
    return FoodTruck(
      id: truckId,
      name: name,
      cuisine: cuisine,
      rating: rating,
      imageUrl: imageUrl,
      description: description,
      isOpen: isOpen,
      ownerId: ownerId,
    );
  }

  /// Hero carousel: prefer live `food_trucks` snapshot, then slide payload (fixes stale labels).
  static String displayTruckNameForHero(
    String truckId,
    Map<String, dynamic>? liveTruckDoc,
    String slideTruckName,
  ) {
    final live = nameFromTruckDocumentMap(liveTruckDoc);
    if (live != null) return live;
    return resolvedDisplayName(truckId, null, preferredTruckName: slideTruckName);
  }

  /// After a paid order is stored, bump popularity for each line (by quantity).
  static Future<void> incrementFromPaidOrder(String? truckId, List<CartItem> items) async {
    if (truckId == null || truckId.isEmpty || items.isEmpty) return;
    final firestore = FirebaseFirestore.instance;
    String truckNameForPopularity = '';
    try {
      final tSnap = await firestore.collection('food_trucks').doc(truckId).get();
      truckNameForPopularity = resolveFoodTruckForSlide(truckId, tSnap.data()).name;
    } catch (e, st) {
      debugPrint('incrementFromPaidOrder truck read: $e\n$st');
      truckNameForPopularity = resolveFoodTruckForSlide(truckId, null).name;
    }
    final batch = firestore.batch();
    for (final ci in items) {
      final menuId = ci.menuItem.id;
      if (menuId.isEmpty) continue;
      final docId = '${truckId}_$menuId';
      final ref = firestore.collection(collection).doc(docId);
      batch.set(
        ref,
        {
          'truckId': truckId,
          'menuItemId': menuId,
          'orderCount': FieldValue.increment(ci.quantity),
          'lastOrderedAt': FieldValue.serverTimestamp(),
          if (truckNameForPopularity.isNotEmpty) 'truckName': truckNameForPopularity,
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  static Future<PopularMenuSlide?> _slideFromPopularityDoc(
    DocumentSnapshot doc,
  ) async {
    final d = doc.data() as Map<String, dynamic>?;
    if (d == null) return null;
    final truckId = (d['truckId'] ?? '').toString();
    final menuItemId = (d['menuItemId'] ?? '').toString();
    if (truckId.isEmpty || menuItemId.isEmpty) return null;
    final orderCount = (d['orderCount'] is num) ? (d['orderCount'] as num).toInt() : 0;

    final firestore = FirebaseFirestore.instance;
    final itemSnap = await firestore
        .collection('food_trucks')
        .doc(truckId)
        .collection('menu_items')
        .doc(menuItemId)
        .get();
    if (!itemSnap.exists) return null;
    final data = itemSnap.data() as Map<String, dynamic>;
    final name = (data['name'] ?? '').toString();
    final category = (data['category'] ?? 'Sides').toString();
    final rawUrl = (data['imageUrl'] ?? '').toString().trim();
    final item = MenuItem(
      id: menuItemId,
      name: name,
      description: (data['description'] ?? '').toString(),
      price: (data['price'] ?? 0.0).toDouble(),
      imageUrl: rawUrl.isNotEmpty ? rawUrl : defaultMenuImageFor(name, category),
      category: category,
    );

    final preferredRaw = (d['truckName'] ?? '').toString().trim();
    final preferredPopularity =
        preferredRaw.isNotEmpty && !_isGenericFoodTruckLabel(preferredRaw) ? preferredRaw : null;

    final truckSnap = await firestore.collection('food_trucks').doc(truckId).get();
    final truck = resolveFoodTruckForSlide(
      truckId,
      truckSnap.data(),
      preferredTruckName: preferredPopularity,
    );

    return PopularMenuSlide(item: item, truck: truck, orderCount: orderCount);
  }

  /// Walk popularity docs in order until [maxItems] valid slides (menu doc still exists).
  /// Multiple slides can be from the same truck — purely order-count driven.
  static Future<List<PopularMenuSlide>> resolveTopDocs(
    QuerySnapshot snapshot,
    int maxItems,
  ) async {
    final list = <PopularMenuSlide>[];
    for (final doc in snapshot.docs) {
      if (list.length >= maxItems) break;
      final slide = await _slideFromPopularityDoc(doc);
      if (slide != null) list.add(slide);
    }
    return list;
  }

  /// Live top items by `orderCount` (reads extra docs so missing/deleted menu rows don't leave gaps).
  static Stream<List<PopularMenuSlide>> watchTop({int limit = 4}) {
    const fetchDocs = 24;
    return FirebaseFirestore.instance
        .collection(collection)
        .orderBy('orderCount', descending: true)
        .limit(fetchDocs)
        .snapshots()
        .asyncMap((snap) => resolveTopDocs(snap, limit));
  }

  /// Offline / error fallback: mock items all attributed to the first mock truck only
  /// (never assign generic mock dishes to Pizza Corner / Sushi Roll, etc.).
  static List<PopularMenuSlide> syntheticSingleTruckFallback(int limit) {
    if (mockFoodTrucks.isEmpty) return [];
    final truck = mockFoodTrucks.first;
    return mockMenuItems
        .take(limit)
        .map(
          (item) => PopularMenuSlide(item: item, truck: truck, orderCount: 0),
        )
        .toList();
  }

  /// Real menu rows from Firestore: walk trucks in doc order, add items until [limit].
  /// All slides can be from one truck if it has enough menu items.
  static Future<List<PopularMenuSlide>> loadSlidesFromActualMenus({
    int limit = 4,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final out = <PopularMenuSlide>[];
    try {
      final trucksSnap = await firestore.collection('food_trucks').get();
      for (final truckDoc in trucksSnap.docs) {
        if (out.length >= limit) break;
        final truckId = truckDoc.id;
        final truck = resolveFoodTruckForSlide(truckId, truckDoc.data());
        final need = limit - out.length;
        final menuSnap = await firestore
            .collection('food_trucks')
            .doc(truckId)
            .collection('menu_items')
            .limit(need)
            .get();
        for (final doc in menuSnap.docs) {
          if (out.length >= limit) break;
          final d = doc.data();
          final name = (d['name'] ?? '').toString();
          final category = (d['category'] ?? 'Sides').toString();
          final rawUrl = (d['imageUrl'] ?? '').toString().trim();
          final item = MenuItem(
            id: doc.id,
            name: name,
            description: (d['description'] ?? '').toString(),
            price: (d['price'] ?? 0.0).toDouble(),
            imageUrl: rawUrl.isNotEmpty ? rawUrl : defaultMenuImageFor(name, category),
            category: category,
          );
          out.add(PopularMenuSlide(item: item, truck: truck, orderCount: 0));
        }
      }
    } catch (e, st) {
      debugPrint('loadSlidesFromActualMenus: $e\n$st');
    }
    if (out.isEmpty) {
      return syntheticSingleTruckFallback(limit);
    }
    return out;
  }
}
