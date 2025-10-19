import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class OrderPrintService {
  static Future<void> printOrder(Map<String, dynamic> order) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (context) => _buildReceipt(order),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
  }

  static pw.Widget _buildReceipt(Map<String, dynamic> order) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Header
        pw.Center(
          child: pw.Column(
            children: [
              pw.Text(
                'Saorely',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Thank you for your order!',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.SizedBox(height: 8),
              pw.Divider(thickness: 2),
            ],
          ),
        ),

        // Order Details
        pw.SizedBox(height: 12),
        _buildRow('Order #:', order['orderNumber'], isBold: true),
        _buildRow('Date:', dateFormat.format(
          DateTime.parse(order['createdAt'] ?? DateTime.now().toString())
        )),
        _buildRow('Type:', order['deliveryType']?.toUpperCase() ?? 'PICKUP'),
        
        pw.SizedBox(height: 8),
        pw.Divider(),
        
        // Customer Info
        pw.SizedBox(height: 8),
        pw.Text(
          'CUSTOMER DETAILS',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        _buildRow('Name:', order['userId']?['firstName'] ?? 'Customer'),
        _buildRow('Phone:', order['userId']?['phone'] ?? '---'),
        
        if (order['deliveryType'] == 'delivery' && 
            order['deliveryAddress'] != null) ...[
          pw.SizedBox(height: 4),
          pw.Text('Address:', style: const pw.TextStyle(fontSize: 10)),
          pw.Text(
            order['deliveryAddress']['address'] ?? '',
            style: const pw.TextStyle(fontSize: 10),
          ),
          if (order['deliveryAddress']['apartment'] != null)
            pw.Text(
              order['deliveryAddress']['apartment'],
              style: const pw.TextStyle(fontSize: 10),
            ),
        ],

        pw.SizedBox(height: 8),
        pw.Divider(),

        // Items
        pw.SizedBox(height: 8),
        pw.Text(
          'ORDER ITEMS',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),

        ...List.generate(
          (order['items'] as List?)?.length ?? 0,
          (i) => _buildItemRow(order['items'][i]),
        ),

        pw.SizedBox(height: 8),
        pw.Divider(),

        // Totals
        pw.SizedBox(height: 8),
        _buildRow('Subtotal:', '\$${order['subtotal']?.toStringAsFixed(2)}'),
        if (order['deliveryFee'] > 0)
          _buildRow('Delivery:', '\$${order['deliveryFee']?.toStringAsFixed(2)}'),
        if (order['tax'] > 0)
          _buildRow('Tax:', '\$${order['tax']?.toStringAsFixed(2)}'),
        if (order['discount'] > 0)
          _buildRow('Discount:', '-\$${order['discount']?.toStringAsFixed(2)}'),
        
        pw.SizedBox(height: 4),
        pw.Divider(thickness: 2),
        pw.SizedBox(height: 4),
        
        _buildRow(
          'TOTAL:',
          '\$${order['total']?.toStringAsFixed(2)}',
          isBold: true,
          fontSize: 16,
        ),

        pw.SizedBox(height: 8),
        pw.Divider(),

        // Payment Info
        pw.SizedBox(height: 8),
        _buildRow('Payment:', order['paymentMethod']?.toUpperCase() ?? 'COD'),
        if (order['codPaymentType'] != null)
          _buildRow('Pay with:', order['codPaymentType']?.toUpperCase()),
        _buildRow('Status:', order['paymentStatus']?.toUpperCase() ?? 'PENDING'),

        // Special Instructions
        if (order['specialInstructions'] != null &&
            order['specialInstructions'].toString().isNotEmpty) ...[
          pw.SizedBox(height: 8),
          pw.Divider(),
          pw.SizedBox(height: 8),
          pw.Text(
            'SPECIAL INSTRUCTIONS',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            order['specialInstructions'],
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],

        pw.SizedBox(height: 16),
        pw.Center(
          child: pw.Column(
            children: [
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Text(
                'Enjoy your meal!',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildRow(
    String label,
    String value, {
    bool isBold = false,
    double fontSize = 11,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildItemRow(Map<String, dynamic> item) {
    final itemName = item['foodItem']?['name'] ?? 'Item';
    final qty = item['quantity'] ?? 1;
    final price = item['totalPrice'] ?? 0.0;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
              child: pw.Text(
                '$qty x $itemName',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Text(
              '\$${price.toStringAsFixed(2)}',
              style: const pw.TextStyle(fontSize: 11),
            ),
          ],
        ),
        
        // Meal size
        if (item['selectedMealSize'] != null) ...[
          pw.SizedBox(height: 2),
          pw.Text(
            '  Size: ${item['selectedMealSize']['name']}',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ],
        
        // Extras
        if (item['selectedExtras'] != null &&
            (item['selectedExtras'] as List).isNotEmpty) ...[
          pw.SizedBox(height: 2),
          pw.Text(
            '  Extras: ${(item['selectedExtras'] as List).map((e) => e['name']).join(', ')}',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ],
        
        // Special instructions
        if (item['specialInstructions'] != null &&
            item['specialInstructions'].toString().isNotEmpty) ...[
          pw.SizedBox(height: 2),
          pw.Text(
            '  Note: ${item['specialInstructions']}',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ],
        
        pw.SizedBox(height: 8),
      ],
    );
  }
}
