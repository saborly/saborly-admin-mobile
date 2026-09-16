import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

/// Renders a receipt for an 80mm thermal roll printer — a narrow,
/// single-column, monochrome layout. Deliberately doesn't rely on color for
/// hierarchy (thermal printers are black-only); weight, size and spacing do
/// that work instead.
class OrderPrintService {
  // Thermal/PDF printers can clip currency glyphs like "€" depending on font support.
  // Use a text prefix for reliable output across devices.
  static const String _currencySymbol = 'EUR ';

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

    final subtotal = _toDouble(order['subtotal']) ?? 0.0;
    final deliveryFee = _toDouble(order['deliveryFee']) ?? 0.0;
    final tax = _toDouble(order['tax']) ?? 0.0;
    final discount = _toDouble(order['discount']) ?? 0.0;
    final total = _toDouble(order['total']) ?? 0.0;
    final branch = order['branchId'] is Map ? Map<String, dynamic>.from(order['branchId']) : null;
    final branchName = order['branchName'] ?? branch?['name'];
    final branchAddress = branch?['address']?.toString().trim();
    final branchPhone = branch?['phone']?.toString().trim();
    final customerName = _extractCustomerName(order);
    final customerPhone = _extractCustomerPhone(order);
    final createdAt = DateTime.tryParse(order['createdAt']?.toString() ?? '') ?? DateTime.now();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Header — restaurant identity first, like a real point-of-sale receipt
        pw.Center(
          child: pw.Column(
            children: [
              pw.Text('SABORLY', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, letterSpacing: 1.5)),
              if (branchName != null && branchName.toString().trim().isNotEmpty) ...[
                pw.SizedBox(height: 3),
                pw.Text(branchName.toString(), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ],
              if (branchAddress != null && branchAddress.isNotEmpty) ...[
                pw.SizedBox(height: 1),
                pw.Text(branchAddress, style: const pw.TextStyle(fontSize: 8.5), textAlign: pw.TextAlign.center),
              ],
              if (branchPhone != null && branchPhone.isNotEmpty) ...[
                pw.SizedBox(height: 1),
                pw.Text('Tel: $branchPhone', style: const pw.TextStyle(fontSize: 8.5)),
              ],
            ],
          ),
        ),
        pw.SizedBox(height: 10),
        _buildSeparator(thickness: 1.4),
        pw.SizedBox(height: 10),

        // Order number — the primary reference, boxed for prominence
        pw.Center(
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: pw.BoxDecoration(border: pw.Border.all(width: 1.2)),
            child: pw.Text(
              'ORDER #${order['orderNumber']?.toString() ?? 'N/A'}',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, letterSpacing: 0.5),
            ),
          ),
        ),
        pw.SizedBox(height: 10),
        _buildRow('Date', dateFormat.format(createdAt)),
        _buildRow('Order Type', _prettyLabel(order['deliveryType']?.toString() ?? 'pickup')),

        pw.SizedBox(height: 8),
        _buildSeparator(),

        // Customer details
        pw.SizedBox(height: 8),
        _buildSectionTitle('Customer'),
        pw.SizedBox(height: 4),
        _buildRow('Name', customerName),
        _buildRow('Phone', customerPhone),

        if (order['deliveryType']?.toString().toLowerCase() == 'delivery' && order['deliveryAddress'] is Map) ...[
          pw.SizedBox(height: 4),
          pw.Text('Address', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.Text(
            order['deliveryAddress']['address']?.toString() ?? '',
            style: const pw.TextStyle(fontSize: 10),
          ),
          if (order['deliveryAddress']['apartment'] != null && order['deliveryAddress']['apartment'].toString().trim().isNotEmpty)
            pw.Text(
              order['deliveryAddress']['apartment'].toString(),
              style: const pw.TextStyle(fontSize: 10),
            ),
        ],

        pw.SizedBox(height: 8),
        _buildSeparator(),

        // Items
        pw.SizedBox(height: 8),
        _buildSectionTitle('Order Items'),
        pw.SizedBox(height: 8),
        ...List.generate(
          (order['items'] as List?)?.length ?? 0,
          (i) => _buildItemRow(Map<String, dynamic>.from(order['items'][i] ?? {})),
        ),

        _buildSeparator(),

        // Totals
        pw.SizedBox(height: 8),
        _buildRow('Subtotal', _formatMoney(subtotal)),
        if (deliveryFee > 0) _buildRow('Delivery Fee', _formatMoney(deliveryFee)),
        if (tax > 0) _buildRow('Tax', _formatMoney(tax)),
        if (discount > 0) _buildRow('Discount', '-${_formatMoney(discount)}'),

        pw.SizedBox(height: 6),
        _buildSeparator(thickness: 1.2),
        pw.SizedBox(height: 6),
        _buildRow('Total', _formatMoney(total), isBold: true, fontSize: 15),

        pw.SizedBox(height: 8),
        _buildSeparator(),

        // Payment Info
        pw.SizedBox(height: 8),
        _buildSectionTitle('Payment'),
        pw.SizedBox(height: 4),
        _buildRow('Method', _prettyLabel(order['paymentMethod']?.toString() ?? 'cash-on-delivery')),
        if (order['codPaymentType'] != null) _buildRow('Cash Type', _prettyLabel(order['codPaymentType'].toString())),
        _buildRow('Status', _prettyLabel(order['paymentStatus']?.toString() ?? 'pending')),

        // Special Instructions
        if (order['specialInstructions'] != null && order['specialInstructions'].toString().trim().isNotEmpty) ...[
          pw.SizedBox(height: 8),
          _buildSeparator(),
          pw.SizedBox(height: 8),
          _buildSectionTitle('Special Instructions'),
          pw.SizedBox(height: 4),
          pw.Text(
            order['specialInstructions'].toString(),
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],

        pw.SizedBox(height: 14),
        pw.Center(
          child: pw.Column(
            children: [
              _buildSeparator(),
              pw.SizedBox(height: 8),
              pw.Text('Thank you for choosing Saborly', style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
              if (branchPhone != null && branchPhone.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Text('Questions about your order? Call $branchPhone', style: const pw.TextStyle(fontSize: 8.5)),
              ],
              pw.SizedBox(height: 6),
              pw.Text(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()), style: const pw.TextStyle(fontSize: 7.5)),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildSectionTitle(String title) {
    return pw.Text(
      title.toUpperCase(),
      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, letterSpacing: 0.8),
    );
  }

  static pw.Widget _buildSeparator({double thickness = 0.8}) {
    return pw.Divider(thickness: thickness);
  }

  static String _formatMoney(double amount) {
    return '$_currencySymbol${amount.toStringAsFixed(2)}';
  }

  /// Turns `cashOnDelivery` / `out-for-delivery` into "Cash On Delivery" /
  /// "Out For Delivery" instead of shouting the raw value in ALL CAPS.
  static String _prettyLabel(String raw) {
    final spaced = raw
        .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
        .replaceAll('-', ' ')
        .replaceAll('_', ' ');
    return spaced
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }

  static String _extractCustomerName(Map<String, dynamic> order) {
    if (order['userId'] is Map) {
      final user = Map<String, dynamic>.from(order['userId']);
      final firstName = (user['firstName'] ?? '').toString().trim();
      final lastName = (user['lastName'] ?? '').toString().trim();
      final fullName = '$firstName $lastName'.trim();
      if (fullName.isNotEmpty) return fullName;
    }
    final fallback = order['customerName']?.toString().trim();
    return (fallback == null || fallback.isEmpty) ? 'Customer' : fallback;
  }

  static String _extractCustomerPhone(Map<String, dynamic> order) {
    if (order['userId'] is Map) {
      final user = Map<String, dynamic>.from(order['userId']);
      final phone = user['phone']?.toString().trim();
      if (phone != null && phone.isNotEmpty) return phone;
    }
    final fallback = order['customerPhone']?.toString().trim();
    return (fallback == null || fallback.isEmpty) ? 'N/A' : fallback;
  }

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
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 2,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: fontSize,
                fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ),
          pw.Expanded(
            flex: 3,
            child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                value,
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  fontSize: fontSize,
                  fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildItemRow(Map<String, dynamic> item) {
    // Extract item name - supports simple and multilingual map formats
    String itemName = 'Item';
    final foodItemName = item['foodItem']?['name'];

    if (foodItemName is String) {
      itemName = foodItemName;
    } else if (foodItemName is Map) {
      itemName = foodItemName['en'] ??
          foodItemName['es'] ??
          foodItemName['ca'] ??
          foodItemName['ar'] ??
          (foodItemName.values.isNotEmpty ? foodItemName.values.first.toString() : 'Item');
    }

    final qty = item['quantity'] ?? 1;
    final price = _toDouble(item['totalPrice']) ?? 0.0;

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 7),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: 20,
                child: pw.Text('${qty}x', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              ),
              pw.Expanded(
                child: pw.Text(itemName, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              ),
              pw.Text(_formatMoney(price), style: const pw.TextStyle(fontSize: 11)),
            ],
          ),

          // Meal size
          if (item['selectedMealSize'] != null) ...[
            pw.SizedBox(height: 2),
            pw.Text(
              '     Size: ${item['selectedMealSize']['name']?.toString() ?? ''}',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ],

          // Extras
          if (item['selectedExtras'] != null && (item['selectedExtras'] as List).isNotEmpty) ...[
            pw.SizedBox(height: 2),
            pw.Text(
              '     Extras: ${(item['selectedExtras'] as List).map((e) => e['name']?.toString() ?? '').join(', ')}',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ],

          // Special instructions
          if (item['specialInstructions'] != null && item['specialInstructions'].toString().trim().isNotEmpty) ...[
            pw.SizedBox(height: 2),
            pw.Text(
              '     Note: ${item['specialInstructions']}',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ],
        ],
      ),
    );
  }
}
