import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/app_colors.dart';

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

  int _getOrderCountByStatus(List<QueryDocumentSnapshot> orders, String status) {
    return orders.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final orderStatus = (data['status'] as String? ?? '').toLowerCase();
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
          
          // First, exclude failed orders
          final ordersWithoutFailed = allOrders.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = (data['status'] as String? ?? '').toLowerCase();
            return status != 'failed';
          }).toList();

          final paidCount = _getOrderCountByStatus(ordersWithoutFailed, 'paid');
          final preparingCount = _getOrderCountByStatus(ordersWithoutFailed, 'preparing');
          final readyCount = _getOrderCountByStatus(ordersWithoutFailed, 'ready');

          // Filter by status and sort by createdAt
          List<QueryDocumentSnapshot> filteredOrders = _selectedStatus == 'all'
              ? ordersWithoutFailed
              : ordersWithoutFailed.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return (data['status'] as String? ?? '').toLowerCase() == 
                         _selectedStatus.toLowerCase();
                }).toList();
          
          // Sort by createdAt (descending - newest first)
          filteredOrders.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTime = aData['createdAt'] as Timestamp?;
            final bTime = bData['createdAt'] as Timestamp?;
            
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            
            return bTime.compareTo(aTime); // Descending order
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
    final status = data['status'] ?? 'pending';
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
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update({'status': newStatus});

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

