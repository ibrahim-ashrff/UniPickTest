import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/app_colors.dart';
import '../../services/web_order_sound_stub.dart'
    if (dart.library.html) '../../services/web_order_sound_web.dart' as web_order_sound;

/// Orders Management Screen for Truck Owners
/// Shows all orders for their food truck
class TruckOwnerOrdersScreen extends StatefulWidget {
  final String? truckId;

  const TruckOwnerOrdersScreen({super.key, this.truckId});

  @override
  State<TruckOwnerOrdersScreen> createState() => _TruckOwnerOrdersScreenState();
}

class _TruckOwnerOrdersScreenState extends State<TruckOwnerOrdersScreen> {
  String _selectedStatus = 'all';
  final Set<String> _knownPaidOrderIds = {};
  bool _initialLoadDone = false;

  void _checkAndPlayNewPaidOrderSound(List<QueryDocumentSnapshot> allOrders) {
    final paidOrderIds = <String>{};
    for (final doc in allOrders) {
      final data = doc.data() as Map<String, dynamic>;
      final status = (data['status'] as String? ?? '').toLowerCase();
      if (status == 'paid') {
        paidOrderIds.add(doc.id);
      }
    }
    if (!_initialLoadDone) {
      _knownPaidOrderIds.addAll(paidOrderIds);
      _initialLoadDone = true;
      return;
    }
    final newPaidIds = paidOrderIds.difference(_knownPaidOrderIds);
    if (newPaidIds.isNotEmpty) {
      web_order_sound.playNewPaidOrderSound();
      _knownPaidOrderIds.addAll(newPaidIds);
    }
  }

  int _getOrderCountByStatus(List<QueryDocumentSnapshot> orders, String status) {
    return orders.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      String orderStatus = (data['status'] as String? ?? '').toLowerCase();
      if (orderStatus == 'unpaid') orderStatus = 'pending'; // Unpaid = pending
      return orderStatus == status.toLowerCase() && orderStatus != 'failed';
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: _getOrdersStream(),
        builder: (context, snapshot) {
          if (widget.truckId == null) {
            return Center(
              child: Text(
                'No food truck assigned.',
                style: GoogleFonts.inter(color: AppColors.textSecondary),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: GoogleFonts.inter(color: Colors.red),
              ),
            );
          }

          final allOrders = snapshot.data?.docs ?? [];
          
          // Web only: play sound when a new paid order appears
          if (kIsWeb) {
            _checkAndPlayNewPaidOrderSound(allOrders);
          }
          
          // Truck owners only see paid/preparing/ready/completed - NOT pending/unpaid (customer-only until paid)
          final ordersVisibleToOwner = allOrders.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = (data['status'] as String? ?? '').toLowerCase();
            if (status == 'failed') return false;
            if (status == 'pending' || status == 'unpaid') return false;
            return true;
          }).toList();

          final paidCount = _getOrderCountByStatus(ordersVisibleToOwner, 'paid');
          final preparingCount = _getOrderCountByStatus(ordersVisibleToOwner, 'preparing');
          final readyCount = _getOrderCountByStatus(ordersVisibleToOwner, 'ready');

          final effectiveFilter = (_selectedStatus == 'pending') ? 'all' : _selectedStatus;
          List<QueryDocumentSnapshot> filteredOrders = effectiveFilter == 'all'
              ? ordersVisibleToOwner
              : ordersVisibleToOwner.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final docStatus = (data['status'] as String? ?? '').toLowerCase();
                  return docStatus == effectiveFilter.toLowerCase();
                }).toList();
          
          // Sort: All tabs use ascending (oldest first, new orders at bottom).
          // Truck owner only sees paid/preparing/ready/completed (no pending).
          filteredOrders.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            String aStatus = (aData['status'] as String? ?? '').toLowerCase();
            String bStatus = (bData['status'] as String? ?? '').toLowerCase();

            final statusOrder = {'paid': 0, 'preparing': 1, 'ready': 2, 'completed': 3};
            final aPriority = statusOrder[aStatus] ?? 5;
            final bPriority = statusOrder[bStatus] ?? 5;
            if (aPriority != bPriority) return aPriority.compareTo(bPriority);

            final createdAt = (ts) => (ts as Timestamp?)?.toDate();
            final aCreated = createdAt(aData['createdAt']) ?? DateTime.now();
            final bCreated = createdAt(bData['createdAt']) ?? DateTime.now();

            Timestamp? aTs;
            Timestamp? bTs;
            switch (aStatus) {
              case 'paid':
                aTs = aData['paidAt'] as Timestamp?;
                bTs = bData['paidAt'] as Timestamp?;
                break;
              case 'preparing':
                aTs = aData['preparingAt'] as Timestamp?;
                bTs = bData['preparingAt'] as Timestamp?;
                break;
              case 'ready':
                aTs = aData['readyAt'] as Timestamp?;
                bTs = bData['readyAt'] as Timestamp?;
                break;
              case 'completed':
                aTs = aData['completedAt'] as Timestamp?;
                bTs = bData['completedAt'] as Timestamp?;
                break;
              default:
                aTs = aData['createdAt'] as Timestamp?;
                bTs = bData['createdAt'] as Timestamp?;
            }
            final aTime = aTs?.toDate() ?? aCreated;
            final bTime = bTs?.toDate() ?? bCreated;
            return aTime.compareTo(bTime);
          });

          return Column(
            children: [
              // Status filter
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<String>(
                        segments: [
                          const ButtonSegment(value: 'all', label: Text('All')),
                          ButtonSegment(
                            value: 'paid',
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Paid'),
                                if (paidCount > 0) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '$paidCount',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          ButtonSegment(
                            value: 'preparing',
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Preparing'),
                                if (preparingCount > 0) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Colors.yellow,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '$preparingCount',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          ButtonSegment(
                            value: 'ready',
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Ready'),
                                if (readyCount > 0) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '$readyCount',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const ButtonSegment(value: 'completed', label: Text('Completed')),
                        ],
                        selected: {_selectedStatus},
                        onSelectionChanged: (Set<String> newSelection) {
                          setState(() {
                            _selectedStatus = newSelection.first;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              // Orders list
              Expanded(
                child: filteredOrders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long,
                              size: 64,
                              color: AppColors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No orders yet',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filteredOrders.length,
                        itemBuilder: (context, index) {
                          final doc = filteredOrders[index];
                          final data = doc.data() as Map<String, dynamic>;
                          return _buildOrderCard(doc.id, data);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Stream<QuerySnapshot>? _getOrdersStream() {
    if (widget.truckId == null) return null;

    // Query only by truckId (no orderBy) to avoid needing any index
    // We'll sort and filter by status in memory
    return FirebaseFirestore.instance
        .collection('orders')
        .where('truckId', isEqualTo: widget.truckId)
        .snapshots();
  }

  Widget _buildOrderCard(String orderId, Map<String, dynamic> data) {
    final items = data['items'] as List<dynamic>? ?? [];
    final total = (data['total'] ?? 0.0).toDouble();
    // Normalize: unpaid -> pending (never show unpaid as failed)
    String status = ((data['status'] ?? 'pending') as String).toLowerCase();
    if (status == 'unpaid') status = 'pending';
    final createdAt = data['createdAt'] as Timestamp?;
    final customerName = data['customerName'] ?? 'Customer';
    final notes = data['notes'] as String?;
    final displayOrderNumber = data['displayOrderNumber'] as int?;

    Color statusColor;
    String statusText;
    switch (status) {
      case 'paid':
        statusColor = Colors.blue;
        statusText = 'Paid';
        break;
      case 'preparing':
        statusColor = AppColors.burgundy;
        statusText = 'Preparing';
        break;
      case 'ready':
        statusColor = Colors.green;
        statusText = 'Ready';
        break;
      case 'completed':
        statusColor = Colors.grey;
        statusText = 'Completed';
        break;
      default:
        statusColor = Colors.red;
        statusText = 'Pending';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.2),
          child: Icon(
            Icons.receipt,
            color: statusColor,
          ),
        ),
        title: Text(
          displayOrderNumber != null 
              ? 'Order #$displayOrderNumber' 
              : 'Order #${orderId.substring(0, 8)}',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              customerName,
              style: GoogleFonts.inter(fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (createdAt != null)
              Text(
                _formatDate(createdAt.toDate()),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                statusText,
                style: GoogleFonts.inter(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'EGP ${total.toStringAsFixed(2)}',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                color: AppColors.burgundy,
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Items (${items.length})',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                ...items.map((item) {
                  final quantity = item['quantity'] ?? 1;
                  final itemName = item['menuItemName'] ?? 'Unknown';
                  final itemPrice = (item['price'] ?? 0.0).toDouble();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '$quantity x $itemName',
                            style: GoogleFonts.inter(fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          'EGP ${(itemPrice * quantity).toStringAsFixed(2)}',
                          style: GoogleFonts.inter(fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                }),
                if (notes != null && notes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Notes: $notes',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (status == 'paid')
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _updateOrderStatus(orderId, 'preparing'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.burgundy,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Start Preparing'),
                        ),
                      ),
                    if (status == 'preparing') ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _updateOrderStatus(orderId, 'ready'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Mark Ready'),
                        ),
                      ),
                    ],
                    if (status == 'ready')
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _updateOrderStatus(orderId, 'completed'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Complete'),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      final updates = <String, dynamic>{'status': newStatus};
      switch (newStatus) {
        case 'preparing':
          updates['preparingAt'] = FieldValue.serverTimestamp();
          break;
        case 'ready':
          updates['readyAt'] = FieldValue.serverTimestamp();
          break;
        case 'completed':
          updates['completedAt'] = FieldValue.serverTimestamp();
          break;
      }
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update(updates);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order status updated to $newStatus'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

