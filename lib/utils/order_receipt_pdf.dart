import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../data/mock_food_trucks.dart';
import '../models/order.dart';

/// Builds a simple PDF receipt and opens the system share sheet (Save to Files, etc.).
Future<void> shareOrderReceiptPdf(Order receipt) async {
  final doc = pw.Document();
  final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(receipt.createdAt);
  final orderLabel = receipt.displayOrderNumber != null
      ? 'Order #${receipt.displayOrderNumber}'
      : receipt.id;

  doc.addPage(
    pw.MultiPage(
      pageFormat: pdf.PdfPageFormat.a4,
      margin: pw.EdgeInsets.all(40),
      build: (ctx) => [
        pw.Text(
          'UniPick',
          style: pw.TextStyle(
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          _truckName(receipt.truckId),
          style: pw.TextStyle(fontSize: 13),
        ),
        pw.SizedBox(height: 16),
        pw.Text(
          'Receipt',
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.Divider(thickness: 1),
        pw.SizedBox(height: 12),
        _pdfRow('Order', orderLabel),
        _pdfRow('Date', dateStr),
        pw.SizedBox(height: 14),
        pw.Text(
          'Items',
          style: pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        ...receipt.items.map(
          (i) => pw.Padding(
            padding: pw.EdgeInsets.only(bottom: 8),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        i.menuItem.name,
                        style: pw.TextStyle(fontSize: 11),
                      ),
                      if (i.menuItem.description.isNotEmpty)
                        pw.Text(
                          i.menuItem.description,
                          style: pw.TextStyle(
                            fontSize: 9,
                            color: pdf.PdfColors.grey700,
                          ),
                          maxLines: 2,
                        ),
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      '${i.quantity} × ${i.menuItem.price.toStringAsFixed(2)}',
                      style: pw.TextStyle(fontSize: 10),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      '${i.total.toStringAsFixed(2)} EGP',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        pw.Divider(),
        _pdfRow('Subtotal', '${receipt.subtotal.toStringAsFixed(2)} EGP'),
        if (receipt.unipickFees != null && receipt.unipickFees! > 0)
          _pdfRow('UniPick fees', '${receipt.unipickFees!.toStringAsFixed(2)} EGP'),
        if (receipt.fawryFees != null && receipt.fawryFees! > 0)
          _pdfRow('Processing fees', '${receipt.fawryFees!.toStringAsFixed(2)} EGP'),
        pw.SizedBox(height: 4),
        _pdfRow('Total', '${receipt.total.toStringAsFixed(2)} EGP', emphasize: true),
        if (receipt.notes != null && receipt.notes!.trim().isNotEmpty) ...[
          pw.SizedBox(height: 16),
          pw.Text(
            'Notes',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(receipt.notes!.trim()),
        ],
        pw.SizedBox(height: 28),
        pw.Center(
          child: pw.Text(
            'Thank you for your order!',
            style: pw.TextStyle(
              fontSize: 12,
              color: pdf.PdfColors.green800,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );

  await Printing.sharePdf(
    bytes: await doc.save(),
    filename: 'UniPick_receipt_${receipt.id}.pdf',
  );
}

pw.Widget _pdfRow(String label, String value, {bool emphasize = false}) {
  final w = emphasize ? pw.FontWeight.bold : pw.FontWeight.normal;
  return pw.Padding(
    padding: pw.EdgeInsets.only(bottom: 6),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(fontWeight: w)),
        pw.Text(value, style: pw.TextStyle(fontWeight: w)),
      ],
    ),
  );
}

String _truckName(String? truckId) {
  if (truckId == null || truckId.isEmpty) return 'Order';
  try {
    final truck = mockFoodTrucks.firstWhere(
      (t) => t.id == truckId,
      orElse: () => mockFoodTrucks.first,
    );
    return truck.name;
  } catch (_) {
    return 'Order';
  }
}
