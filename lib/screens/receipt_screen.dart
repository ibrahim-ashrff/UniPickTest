import 'package:flutter/material.dart';
import '../models/order.dart';
import '../utils/app_colors.dart';
import '../data/mock_food_trucks.dart';

/// Screen that displays order receipt with all details
class ReceiptScreen extends StatelessWidget {
  final Order order;

  const ReceiptScreen({
    super.key,
    required this.order,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // TODO: Implement share receipt functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share receipt coming soon')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Card(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Text(
                        _getTruckName(order.truckId),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.burgundy,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Order Info
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildReceiptRow('Order ID', order.displayOrderNumber != null 
                          ? 'Order #${order.displayOrderNumber}' 
                          : order.id.substring(0, 8).toUpperCase()),
                      const Divider(),
                      _buildReceiptRow('Date', _formatDateTime(order.createdAt)),
                      if (order.fawryReferenceNumber.isNotEmpty) ...[
                        const Divider(),
                        _buildReceiptRow('Fawry Ref', order.fawryReferenceNumber),
                      ],
                      if (order.invoiceNumber != null) ...[
                        const Divider(),
                        _buildReceiptRow('Invoice #', order.invoiceNumber!),
                      ],
                      const Divider(),
                      _buildReceiptRow('Status', order.status.toUpperCase(),
                        valueStyle: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _getStatusColor(order.status),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Items
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Items',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...order.items.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                                  '${item.quantity} x ${item.menuItem.price.toStringAsFixed(2)}',
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
                      )),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Totals
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildTotalRow('Subtotal', order.subtotal),
                      if (order.fawryFees != null && order.fawryFees! > 0) ...[
                        const SizedBox(height: 8),
                        _buildTotalRow('Fawry Fees', order.fawryFees!),
                      ],
                      const Divider(height: 24),
                      _buildTotalRow(
                        'Total',
                        order.total,
                        isTotal: true,
                      ),
                    ],
                  ),
                ),
              ),

              if (order.notes != null && order.notes!.isNotEmpty) ...[
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Notes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          order.notes!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Thank you message
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 60,
                      color: Colors.green,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Thank you for your order!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, {TextStyle? valueStyle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: valueStyle ?? const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 20 : 16,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          '${amount.toStringAsFixed(2)} EGP',
          style: TextStyle(
            fontSize: isTotal ? 20 : 16,
            fontWeight: FontWeight.bold,
            color: isTotal ? Colors.red : null,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return Colors.green;
      case 'pending':
        return AppColors.burgundy;
      case 'preparing':
        return Colors.blue;
      case 'ready':
        return Colors.purple;
      case 'completed':
        return Colors.green;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDateTime(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  String _getTruckName(String? truckId) {
    if (truckId == null || truckId.isEmpty) {
      return 'Order Receipt';
    }
    try {
      final truck = mockFoodTrucks.firstWhere(
        (t) => t.id == truckId,
        orElse: () => mockFoodTrucks.first,
      );
      return truck.name;
    } catch (e) {
      return 'Order Receipt';
    }
  }
}

