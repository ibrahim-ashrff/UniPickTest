import 'cart_item.dart';

class Order {
  final String id;
  final String fawryReferenceNumber;
  final String merchantRefNumber;
  final List<CartItem> items;
  final double total;
  final double subtotal;
  final double? fawryFees;
  /// Platform fee (e.g. 7.5 EGP); null on legacy orders without this field.
  final double? unipickFees;
  final DateTime createdAt;
  final String status; // 'pending', 'paid', 'preparing', 'ready', 'completed'
  final String? notes;
  final String? invoiceNumber;
  final String? businessRefNumber;
  final String? truckId; // ID of the food truck this order is for
  final int? displayOrderNumber; // Sequential order number per truck (e.g., 1, 2, 3...)

  Order({
    required this.id,
    required this.fawryReferenceNumber,
    required this.merchantRefNumber,
    required this.items,
    required this.total,
    required this.subtotal,
    this.fawryFees,
    this.unipickFees,
    required this.createdAt,
    required this.status,
    this.notes,
    this.invoiceNumber,
    this.businessRefNumber,
    this.truckId,
    this.displayOrderNumber,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fawryReferenceNumber': fawryReferenceNumber,
      'merchantRefNumber': merchantRefNumber,
      'items': items.map((item) => {
        'menuItemId': item.menuItem.id,
        'menuItemName': item.menuItem.name,
        'menuItemDescription': item.menuItem.description,
        'quantity': item.quantity,
        'price': item.menuItem.price,
        'total': item.total,
      }).toList(),
      'total': total,
      'subtotal': subtotal,
      'fawryFees': fawryFees,
      'unipickFees': unipickFees,
      'createdAt': createdAt.toIso8601String(),
      'status': status,
      'notes': notes,
      'invoiceNumber': invoiceNumber,
      'businessRefNumber': businessRefNumber,
    };
  }
  
  // Convert to Firestore-compatible JSON (with Timestamp)
  Map<String, dynamic> toFirestoreJson() {
    return {
      'id': id,
      'fawryReferenceNumber': fawryReferenceNumber,
      'merchantRefNumber': merchantRefNumber,
      'items': items.map((item) => {
        'menuItemId': item.menuItem.id,
        'menuItemName': item.menuItem.name,
        'menuItemDescription': item.menuItem.description,
        'quantity': item.quantity,
        'price': item.menuItem.price,
        'total': item.total,
      }).toList(),
      'total': total,
      'subtotal': subtotal,
      'fawryFees': fawryFees,
      'unipickFees': unipickFees,
      'status': status,
      'notes': notes,
      'invoiceNumber': invoiceNumber,
      'businessRefNumber': businessRefNumber,
      'truckId': truckId,
      'displayOrderNumber': displayOrderNumber,
      // Note: createdAt will be added as Timestamp in orders_provider
    };
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    // Note: This is simplified - you'd need to reconstruct CartItems from JSON
    return Order(
      id: json['id'] ?? '',
      fawryReferenceNumber: json['fawryReferenceNumber'] ?? '',
      merchantRefNumber: json['merchantRefNumber'] ?? '',
      items: [], // Would need to reconstruct from JSON
      total: (json['total'] ?? 0).toDouble(),
      subtotal: (json['subtotal'] ?? 0).toDouble(),
      fawryFees: json['fawryFees']?.toDouble(),
      unipickFees: json['unipickFees']?.toDouble(),
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      status: json['status'] ?? 'pending',
      notes: json['notes'],
      invoiceNumber: json['invoiceNumber'],
      businessRefNumber: json['businessRefNumber'],
      truckId: json['truckId'],
      displayOrderNumber: json['displayOrderNumber'] as int?,
    );
  }
}

