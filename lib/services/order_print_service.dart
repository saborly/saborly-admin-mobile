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
    
    // Safely extract numerical values with null safety
    final subtotal = _toDouble(order['subtotal']) ?? 0.0;
    final deliveryFee = _toDouble(order['deliveryFee']) ?? 0.0;
    final tax = _toDouble(order['tax']) ?? 0.0;
    final discount = _toDouble(order['discount']) ?? 0.0;
    final total = _toDouble(order['total']) ?? 0.0;
    
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Header
        pw.Center(
          child: pw.Column(
            children: [
              pw.Text(
                'Saborly',
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
        _buildRow('Order #:', order['orderNumber']?.toString() ?? 'N/A', isBold: true),
        _buildRow('Date:', dateFormat.format(
          DateTime.tryParse(order['createdAt']?.toString() ?? '') ?? DateTime.now()
        )),
        _buildRow('Type:', (order['deliveryType']?.toString() ?? 'PICKUP').toUpperCase()),
        
        pw.SizedBox(height: 8),
        pw.Divider(),
        
        // Customer Info
        pw.SizedBox(height: 8),
        pw.Text(
          'CUSTOMER DETAILS',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        _buildRow('Name:', order['userId']?['firstName']?.toString() ?? 'Customer'),
        _buildRow('Phone:', order['userId']?['phone']?.toString() ?? '---'),
        
        if (order['deliveryType']?.toString().toLowerCase() == 'delivery' && 
            order['deliveryAddress'] != null) ...[
          pw.SizedBox(height: 4),
          pw.Text('Address:', style: const pw.TextStyle(fontSize: 10)),
          pw.Text(
            order['deliveryAddress']['address']?.toString() ?? '',
            style: const pw.TextStyle(fontSize: 10),
          ),
          if (order['deliveryAddress']['apartment'] != null)
            pw.Text(
              order['deliveryAddress']['apartment'].toString(),
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
        _buildRow('Subtotal:', '\$${subtotal.toStringAsFixed(2)}'),
        if (deliveryFee > 0)
          _buildRow('Delivery:', '\$${deliveryFee.toStringAsFixed(2)}'),
        if (tax > 0)
          _buildRow('Tax:', '\$${tax.toStringAsFixed(2)}'),
        if (discount > 0)
          _buildRow('Discount:', '-\$${discount.toStringAsFixed(2)}'),
        
        pw.SizedBox(height: 4),
        pw.Divider(thickness: 2),
        pw.SizedBox(height: 4),
        
        _buildRow(
          'TOTAL:',
          '\$${total.toStringAsFixed(2)}',
          isBold: true,
          fontSize: 16,
        ),

        pw.SizedBox(height: 8),
        pw.Divider(),

        // Payment Info
        pw.SizedBox(height: 8),
        _buildRow('Payment:', (order['paymentMethod']?.toString() ?? 'COD').toUpperCase()),
        if (order['codPaymentType'] != null)
          _buildRow('Pay with:', order['codPaymentType'].toString().toUpperCase()),
        _buildRow('Status:', (order['paymentStatus']?.toString() ?? 'PENDING').toUpperCase()),

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
            order['specialInstructions'].toString(),
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

  // Helper method to safely convert to double
  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
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
    // Extract item name - handle both string and map (multilingual) formats
    String itemName = 'Item';
    final foodItemName = item['foodItem']?['name'];
    
    if (foodItemName is String) {
      itemName = foodItemName;
    } else if (foodItemName is Map) {
      // Get name in preferred order: English > Spanish > Catalan > Arabic
      itemName = foodItemName['en'] ?? 
                 foodItemName['es'] ?? 
                 foodItemName['ca'] ??
                 foodItemName['ar'] ??
                 (foodItemName.values.isNotEmpty ? foodItemName.values.first.toString() : 'Item');
    }
    
    final qty = item['quantity'] ?? 1;
    final price = _toDouble(item['totalPrice']) ?? 0.0;

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
            '  Size: ${item['selectedMealSize']['name']?.toString() ?? ''}',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ],
        
        // Extras
        if (item['selectedExtras'] != null &&
            (item['selectedExtras'] as List).isNotEmpty) ...[
          pw.SizedBox(height: 2),
          pw.Text(
            '  Extras: ${(item['selectedExtras'] as List).map((e) => e['name']?.toString() ?? '').join(', ')}',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ],
        
        // Special instructions
        if (item['specialInstructions'] != null &&
            item['specialInstructions'].toString().isNotEmpty) ...[
          pw.SizedBox(height: 2),
          pw.Text(
            'Special Instructions: ${item['specialInstructions']}',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ],
        
        pw.SizedBox(height: 8),
      ],
    );
  }}