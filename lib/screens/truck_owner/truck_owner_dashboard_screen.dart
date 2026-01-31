import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/app_colors.dart';
import 'package:intl/intl.dart';

/// Dashboard Screen for Truck Owners
/// Shows order history in a table format with filters
class TruckOwnerDashboardScreen extends StatefulWidget {
  final String? truckId;

  const TruckOwnerDashboardScreen({super.key, this.truckId});

  @override
  State<TruckOwnerDashboardScreen> createState() => _TruckOwnerDashboardScreenState();
}

class _TruckOwnerDashboardScreenState extends State<TruckOwnerDashboardScreen> {
  String _selectedStatus = 'all';
  DateTime? _startDate;
  DateTime? _endDate;
  List<Map<String, dynamic>> _filteredOrders = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    if (widget.truckId == null) return;

    setState(() => _isLoading = true);

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('truckId', isEqualTo: widget.truckId)
          .get();

      final allOrders = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();

      // Filter orders
      _applyFilters(allOrders);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading orders: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyFilters(List<Map<String, dynamic>> orders) {
    setState(() {
      _filteredOrders = orders.where((order) {
        // Status filter
        if (_selectedStatus != 'all') {
          final status = (order['status'] ?? '').toString().toLowerCase();
          if (status != _selectedStatus.toLowerCase()) {
            return false;
          }
        }

        // Date filters
        final createdAt = order['createdAt'] as Timestamp?;
        if (createdAt != null) {
          final orderDate = createdAt.toDate();
          
          if (_startDate != null && orderDate.isBefore(_startDate!)) {
            return false;
          }
          
          if (_endDate != null) {
            // Include the entire end date (set to end of day)
            final endOfDay = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
            if (orderDate.isAfter(endOfDay)) {
              return false;
            }
          }
        }

        // Exclude failed orders
        final status = (order['status'] ?? '').toString().toLowerCase();
        if (status == 'failed') {
          return false;
        }

        return true;
      }).toList();

      // Sort by createdAt descending (newest first)
      _filteredOrders.sort((a, b) {
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });
    });
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now().subtract(const Duration(days: 30)),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
      });
      _loadOrders();
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
      _loadOrders();
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return Colors.blue;
      case 'preparing':
        return AppColors.burgundy;
      case 'ready':
        return Colors.green;
      case 'completed':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  double _getCompletedOrdersTotal() {
    return _filteredOrders.fold(0.0, (sum, order) {
      final total = (order['total'] ?? 0.0).toDouble();
      return sum + total;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Filters section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Filters',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                // Status filter
                Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'all', label: Text('All')),
                          ButtonSegment(value: 'paid', label: Text('Paid')),
                          ButtonSegment(value: 'preparing', label: Text('Preparing')),
                          ButtonSegment(value: 'ready', label: Text('Ready')),
                          ButtonSegment(value: 'completed', label: Text('Completed')),
                        ],
                        selected: {_selectedStatus},
                        onSelectionChanged: (Set<String> newSelection) {
                          setState(() {
                            _selectedStatus = newSelection.first;
                          });
                          _loadOrders();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Date filters
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _selectStartDate,
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(
                          _startDate == null
                              ? 'Start Date'
                              : DateFormat('MMM dd, yyyy').format(_startDate!),
                          style: GoogleFonts.inter(fontSize: 13),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.burgundy,
                          side: BorderSide(color: AppColors.burgundy),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _selectEndDate,
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(
                          _endDate == null
                              ? 'End Date'
                              : DateFormat('MMM dd, yyyy').format(_endDate!),
                          style: GoogleFonts.inter(fontSize: 13),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.burgundy,
                          side: BorderSide(color: AppColors.burgundy),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (_startDate != null || _endDate != null)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _startDate = null;
                            _endDate = null;
                          });
                          _loadOrders();
                        },
                        tooltip: 'Clear dates',
                      ),
                  ],
                ),
              ],
            ),
          ),
          // Total summary for completed orders
          if (_selectedStatus == 'completed' && _filteredOrders.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.burgundy.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.burgundy,
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.attach_money,
                        color: AppColors.burgundy,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Revenue (Completed Orders)',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_filteredOrders.length} ${_filteredOrders.length == 1 ? 'order' : 'orders'}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Text(
                    'EGP ${_getCompletedOrdersTotal().toStringAsFixed(2)}',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.burgundy,
                    ),
                  ),
                ],
              ),
            ),
          // Table section
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredOrders.isEmpty
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
                              'No orders found',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: DataTable(
                            headingRowColor: MaterialStateProperty.all(
                              AppColors.burgundy.withOpacity(0.1),
                            ),
                            columns: [
                              DataColumn(
                                label: Text(
                                  'Order ID',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Date',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Customer',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Items',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Total',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Status',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Ref Number',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                            rows: _filteredOrders.map((order) {
                              final orderId = order['id'] as String? ?? '';
                              final createdAt = order['createdAt'] as Timestamp?;
                              final customerName = order['customerName'] ?? 'Customer';
                              final items = order['items'] as List<dynamic>? ?? [];
                              final total = (order['total'] ?? 0.0).toDouble();
                              final status = (order['status'] ?? 'pending').toString();
                              final refNumber = order['fawryReferenceNumber'] ?? 'N/A';
                              final displayOrderNumber = order['displayOrderNumber'] as int?;

                              return DataRow(
                                cells: [
                                  DataCell(
                                    SizedBox(
                                      width: 80,
                                      child: Text(
                                        displayOrderNumber != null
                                            ? 'Order #$displayOrderNumber'
                                            : (orderId.length > 8 
                                                ? '${orderId.substring(0, 8)}...' 
                                                : orderId),
                                        style: GoogleFonts.inter(fontSize: 12),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      createdAt != null
                                          ? DateFormat('MMM dd, yyyy\nHH:mm').format(createdAt.toDate())
                                          : 'N/A',
                                      style: GoogleFonts.inter(fontSize: 11),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 100,
                                      child: Text(
                                        customerName.toString(),
                                        style: GoogleFonts.inter(fontSize: 12),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      '${items.length}',
                                      style: GoogleFonts.inter(fontSize: 12),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      'EGP ${total.toStringAsFixed(2)}',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.burgundy,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(status).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: _getStatusColor(status),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        status.toUpperCase(),
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: _getStatusColor(status),
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 100,
                                      child: Text(
                                        refNumber.toString(),
                                        style: GoogleFonts.inter(fontSize: 11),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

