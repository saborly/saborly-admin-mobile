import 'package:Saborly_admin/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:Saborly_admin/services/order_print_service.dart';
import 'package:Saborly_admin/services/order_provider.dart';

class OrderDetailsScreen extends StatefulWidget {
  final String orderId;

  const OrderDetailsScreen({Key? key, required this.orderId}) : super(key: key);

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  static const Color _brandPrimary = Color(0xFF4A148C);
  static const Color _brandSecondary = Color(0xFF7C3AED);
  static const Color _accent = Color(0xFFFF6B35);
  static const Color _surfaceAlt = Color(0xFFF8FAFC);

  Map<String, dynamic>? _orderData;

  bool _isLoading = true;
  String? _error;
  String _formatAmount(dynamic amount) {
    final parsed = amount is num
        ? amount.toDouble()
        : double.tryParse(amount?.toString() ?? '0') ?? 0.0;
    return 'EUR ${parsed.toStringAsFixed(2)}';
  }

  @override
  void initState() {
    super.initState();

    _loadOrderDetails();
  }

  // Check if device is tablet
  bool _isTablet(BuildContext context) {
    final shortestSide = MediaQuery.of(context).size.shortestSide;
    return shortestSide >= 600;
  }

  // Get responsive padding
  EdgeInsets _getResponsivePadding(BuildContext context) {
    return EdgeInsets.symmetric(
      horizontal: _isTablet(context) ? 32 : 16,
      vertical: 8,
    );
  }

  // Get responsive card padding
  EdgeInsets _getCardPadding(BuildContext context) {
    return EdgeInsets.all(_isTablet(context) ? 24 : 20);
  }

  // Get responsive font size
  double _getResponsiveFontSize(BuildContext context, double baseFontSize) {
    return _isTablet(context) ? baseFontSize * 1.2 : baseFontSize;
  }

  Future<void> _loadOrderDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      final orderData = await orderProvider.loadOrderDetails(widget.orderId);
      if (orderData != null) {
        setState(() {
          _orderData = orderData;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load order details';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading order details: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _printOrder() async {
    if (_orderData == null) return;

    try {
      await OrderPrintService.printOrder(_orderData!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order sent to printer'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Print failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateOrderStatus(String newStatus) async {
    if (_orderData == null) return;

    try {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      final success =
          await orderProvider.updateOrderStatus(widget.orderId, newStatus);
      if (success) {
        setState(() {
          _orderData!['status'] = newStatus;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order status updated to $newStatus'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update order status'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  bool get _isDeliveryOrder {
    return _orderData?['deliveryType']?.toLowerCase() == 'delivery';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _surfaceAlt,
        appBar: AppBar(
          title: const Text('Order Details'),
        ),
        body: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 14),
                Text(
                  'Loading order details...',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: _surfaceAlt,
        appBar: AppBar(
          title: const Text('Order Details'),
        ),
        body: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFFDC2626),
                  size: 34,
                ),
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF1F2937),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadOrderDetails,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isTablet = _isTablet(context);

    return Scaffold(
      backgroundColor: _surfaceAlt,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isTablet ? 800 : double.infinity,
                ),
                child: Column(
                  children: [
                    _buildOrderInfo(context),
                    if (isTablet)
                      _buildTabletLayout(context)
                    else
                      _buildMobileLayout(context),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActions(context),
    );
  }

  // Tablet layout - side by side
  Widget _buildTabletLayout(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  _buildCustomerInfo(context),
                  _buildPricingDetails(context),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildItemsList(context),
            ),
          ],
        ),
        _buildActionButtons(context),
      ],
    );
  }

  // Mobile layout - stacked
  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      children: [
        _buildCustomerInfo(context),
        _buildItemsList(context),
        _buildPricingDetails(context),
        _buildActionButtons(context),
      ],
    );
  }

  Widget _buildPricingDetails(BuildContext context) {
    final isTablet = _isTablet(context);

    return Container(
      margin: _getResponsivePadding(context),
      padding: _getCardPadding(context),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_brandPrimary, _brandSecondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: _brandPrimary.withOpacity(0.25),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildPriceRow(
            context,
            'Subtotal',
            _orderData!['subtotal']?.toDouble() ?? 0.0,
          ),
          if (_orderData!['deliveryFee'] != null &&
              _orderData!['deliveryFee'] > 0) ...[
            SizedBox(height: isTablet ? 10 : 8),
            _buildPriceRow(
              context,
              'Delivery Fee',
              _orderData!['deliveryFee']?.toDouble() ?? 0.0,
            ),
          ],
          if (_orderData!['tax'] != null && _orderData!['tax'] > 0) ...[
            SizedBox(height: isTablet ? 10 : 8),
            _buildPriceRow(
                context, 'Tax', _orderData!['tax']?.toDouble() ?? 0.0),
          ],
          if (_orderData!['discount'] != null &&
              _orderData!['discount'] > 0) ...[
            SizedBox(height: isTablet ? 10 : 8),
            _buildPriceRow(
              context,
              'Discount',
              -(_orderData!['discount']?.toDouble() ?? 0.0),
            ),
          ],
          SizedBox(height: isTablet ? 16 : 12),
          const Divider(color: Colors.white38, thickness: 1),
          SizedBox(height: isTablet ? 16 : 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TOTAL',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: _getResponsiveFontSize(context, 20),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                _formatAmount(_orderData!['total']),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: _getResponsiveFontSize(context, 24),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(BuildContext context, String label, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: _getResponsiveFontSize(context, 14),
          ),
        ),
        Text(
          _formatAmount(amount),
          style: TextStyle(
            color: Colors.white,
            fontSize: _getResponsiveFontSize(context, 14),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildAppBar(BuildContext context) {
    final isTablet = _isTablet(context);

    return SliverAppBar(
      expandedHeight: isTablet ? 250 : 200,
      pinned: true,
      elevation: 0,
      backgroundColor: _brandPrimary,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          _orderData!['orderNumber'],
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: isTablet ? 20 : 16,
          ),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_brandPrimary, _brandSecondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: isTablet ? 60 : 40),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 28 : 20,
                  vertical: isTablet ? 14 : 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.access_time,
                      color: Colors.white,
                      size: isTablet ? 24 : 20,
                    ),
                    SizedBox(width: isTablet ? 12 : 8),
                    Text(
                      _formatDateTime(
                        DateTime.parse(_orderData!['createdAt']),
                      ),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isTablet ? 16 : 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderInfo(BuildContext context) {
    final status = _orderData!['status'];
    final isTablet = _isTablet(context);

    return Container(
      margin: EdgeInsets.all(isTablet ? 24 : 16),
      padding: _getCardPadding(context),
      decoration: BoxDecoration(
        color: Colors.white,
        gradient: LinearGradient(
          colors: [Colors.white, _getStatusColor(status).withOpacity(0.04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _getStatusColor(status).withOpacity(0.22),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _getStatusIcon(status),
                color: _getStatusColor(status),
                size: isTablet ? 40 : 32,
              ),
              SizedBox(width: isTablet ? 16 : 12),
              Text(
                status.toUpperCase(),
                style: TextStyle(
                  fontSize: _getResponsiveFontSize(context, 24),
                  fontWeight: FontWeight.bold,
                  color: _getStatusColor(status),
                ),
              ),
            ],
          ),
          SizedBox(height: isTablet ? 20 : 16),
          Wrap(
            spacing: isTablet ? 16 : 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              _buildInfoChip(
                context,
                icon: _orderData!['deliveryType'] == 'delivery'
                    ? Icons.delivery_dining
                    : Icons.shopping_bag,
                label: _orderData!['deliveryType'].toUpperCase(),
              ),
              _buildInfoChip(
                context,
                icon: Icons.payment,
                label: _orderData!['paymentMethod'].toUpperCase(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    final isTablet = _isTablet(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 20 : 16,
        vertical: isTablet ? 12 : 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: isTablet ? 22 : 18,
            color: const Color(0xFF4A148C),
          ),
          SizedBox(width: isTablet ? 10 : 8),
          Text(
            label,
            style: TextStyle(
              fontSize: isTablet ? 14 : 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF4A148C),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerInfo(BuildContext context) {
    final user = _orderData!['userId'];
    final address = _orderData!['deliveryAddress'];
    final isTablet = _isTablet(context);

    return Container(
      margin: _getResponsivePadding(context),
      padding: _getCardPadding(context),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _brandPrimary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: _brandPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Customer Details',
                style: TextStyle(
                  fontSize: _getResponsiveFontSize(context, 18),
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          SizedBox(height: isTablet ? 20 : 16),
          SizedBox(height: isTablet ? 14 : 12),
          _buildDetailRow(
            context,
            Icons.person,
            'Name',
            user is Map
                ? '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim()
                : 'Customer',
          ),
          SizedBox(height: isTablet ? 16 : 12),
          _buildDetailRow(
            context,
            Icons.phone,
            'Phone',
            (user is Map ? user['phone'] : _orderData!['customerPhone']) ??
                'N/A',
            isClickable: true,
          ),
          if (_orderData!['branchId'] != null ||
              _orderData!['branchName'] != null) ...[
            SizedBox(height: isTablet ? 16 : 12),
            _buildDetailRow(
              context,
              Icons.store,
              'Branch',
              _orderData!['branchId'] is Map
                  ? (_orderData!['branchId']['name'] ?? 'N/A')
                  : (_orderData!['branchName'] ?? 'N/A'),
            ),
          ],
          if (address != null) ...[
            SizedBox(height: isTablet ? 16 : 12),
            _buildDetailRow(
              context,
              Icons.location_on,
              'Address',
              (address is Map ? address['address'] : null) ?? 'N/A',
            ),
            if (address is Map && address['apartment'] != null) ...[
              SizedBox(height: isTablet ? 12 : 8),
              Padding(
                padding: EdgeInsets.only(left: isTablet ? 48 : 40),
                child: Text(
                  address['apartment'],
                  style: TextStyle(
                    fontSize: isTablet ? 16 : 14,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    bool isClickable = false,
  }) {
    final isTablet = _isTablet(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: isTablet ? 24 : 20,
            color: _brandPrimary,
          ),
          SizedBox(width: isTablet ? 16 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: isTablet ? 14 : 12,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isTablet ? 16 : 14,
                    fontWeight: FontWeight.w600,
                    color: isClickable
                        ? const Color(0xFF1E40AF)
                        : const Color(0xFF0F172A),
                    decoration: isClickable ? TextDecoration.underline : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList(BuildContext context) {
    final items = _orderData!['items'] as List;
    final isTablet = _isTablet(context);

    return Container(
      margin: _getResponsivePadding(context),
      padding: _getCardPadding(context),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.receipt_long_rounded,
                  color: _accent,
                  size: isTablet ? 22 : 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Order Items',
                style: TextStyle(
                  fontSize: _getResponsiveFontSize(context, 18),
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          SizedBox(height: isTablet ? 20 : 16),
          Container(
            height: 1,
            decoration: const BoxDecoration(color: Color(0xFFE2E8F0)),
          ),
          SizedBox(height: isTablet ? 16 : 14),
          Text(
            '${items.length} item${items.length > 1 ? 's' : ''}',
            style: TextStyle(
              fontSize: isTablet ? 13 : 12,
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: isTablet ? 18 : 14),
          ...items.asMap().entries.map((entry) {
            final item = entry.value;
            return Padding(
              padding: EdgeInsets.only(
                bottom: entry.key < items.length - 1 ? (isTablet ? 20 : 16) : 0,
              ),
              child: _buildOrderItem(context, item),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildOrderItem(BuildContext context, Map<String, dynamic> item) {
    final isTablet = _isTablet(context);
    debugPrint("order item is ${item}");

    // Extract item name - handle both string and map (multilingual) formats
    String itemName = 'Unknown Item';
    final foodItemName = item['foodItem']?['name'];
    if (foodItemName is String) {
      itemName = foodItemName;
    } else if (foodItemName is Map) {
      // Get name in preferred order: English > Spanish > Catalan > Arabic
      itemName = foodItemName['en'] ??
          foodItemName['es'] ??
          foodItemName['ca'] ??
          foodItemName['ar'] ??
          (foodItemName.values.isNotEmpty
              ? foodItemName.values.first.toString()
              : 'Unknown Item');
    }

    return Container(
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isTablet ? 12 : 8),
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${item['quantity']}x',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _accent,
                    fontSize: isTablet ? 16 : 14,
                  ),
                ),
              ),
              SizedBox(width: isTablet ? 16 : 12),
              Expanded(
                child: Text(
                  itemName,
                  style: TextStyle(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                _formatAmount(item['totalPrice']),
                style: TextStyle(
                  fontSize: isTablet ? 18 : 16,
                  fontWeight: FontWeight.bold,
                  color: _brandPrimary,
                ),
              ),
            ],
          ),
          if (item['selectedMealSize'] != null) ...[
            SizedBox(height: isTablet ? 10 : 8),
            Text(
              '• Size: ${item['selectedMealSize']['name'] ?? 'N/A'}',
              style: TextStyle(
                fontSize: isTablet ? 15 : 13,
                color: const Color(0xFF475569),
              ),
            ),
          ],
          if (item['selectedExtras'] != null &&
              (item['selectedExtras'] as List).isNotEmpty) ...[
            SizedBox(height: isTablet ? 6 : 4),
            Text(
              '• Extras: ${(item['selectedExtras'] as List).map((e) => e['name'] ?? 'N/A').join(', ')}',
              style: TextStyle(
                fontSize: isTablet ? 15 : 13,
                color: const Color(0xFF475569),
              ),
            ),
          ],
          if (item['specialInstructions'] != null &&
              item['specialInstructions'].toString().trim().isNotEmpty) ...[
            SizedBox(height: isTablet ? 6 : 4),
            Text(
              '• Special Instructions: ${item['specialInstructions']}',
              style: TextStyle(
                fontSize: isTablet ? 15 : 13,
                color: const Color(0xFF475569),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final status = _orderData!['status'];
    final isTablet = _isTablet(context);

    return Container(
      margin: EdgeInsets.all(isTablet ? 24 : 16),
      child: Column(
        children: [
          // PENDING -> CONFIRMED
          if (status == 'pending') ...[
            _buildActionButton(
              context,
              onPressed: () => _updateOrderStatus('confirmed'),
              icon: Icons.check_circle,
              label: 'ACCEPT ORDER',
              color: Colors.green,
            ),
            SizedBox(height: isTablet ? 16 : 12),
          ],

          // CONFIRMED -> PREPARING
          if (status == 'confirmed') ...[
            _buildActionButton(
              context,
              onPressed: () => _updateOrderStatus('preparing'),
              icon: Icons.restaurant,
              label: 'START PREPARING',
              color: Colors.blue,
            ),
            SizedBox(height: isTablet ? 16 : 12),
          ],

          // PREPARING -> READY
          if (status == 'preparing') ...[
            _buildActionButton(
              context,
              onPressed: () => _updateOrderStatus('ready'),
              icon: Icons.done_all,
              label: 'MARK AS READY',
              color: Colors.green,
            ),
            SizedBox(height: isTablet ? 16 : 12),
          ],

          // READY -> Different paths for delivery vs pickup
          if (status == 'ready') ...[
            if (_isDeliveryOrder) ...[
              // For delivery orders: Show button to mark as picked up by driver
              _buildActionButton(
                context,
                onPressed: () => _showDriverPickupDialog(context),
                icon: Icons.motorcycle,
                label: 'DRIVER PICKED UP',
                color: Colors.orange,
              ),
            ] else ...[
              // For pickup orders: READY -> DELIVERED (customer picks up)
              _buildActionButton(
                context,
                onPressed: () => _updateOrderStatus('delivered'),
                icon: Icons.check_circle_outline,
                label: 'CUSTOMER PICKED UP',
                color: Colors.teal,
              ),
            ],
            SizedBox(height: isTablet ? 16 : 12),
          ],

          // PICKUP/DRIVERPICKUP -> OUT-FOR-DELIVERY (only for delivery orders)
          if ((status == 'pickup' || status == 'driverpickup') &&
              _isDeliveryOrder) ...[
            _buildActionButton(
              context,
              onPressed: () => _updateOrderStatus('out-for-delivery'),
              icon: Icons.local_shipping,
              label: 'OUT FOR DELIVERY',
              color: Colors.indigo,
            ),
            SizedBox(height: isTablet ? 16 : 12),
          ],

          // OUT-FOR-DELIVERY -> DELIVERED (only for delivery orders)
          if (status == 'out-for-delivery' && _isDeliveryOrder) ...[
            _buildActionButton(
              context,
              onPressed: () => _updateOrderStatus('delivered'),
              icon: Icons.check_circle,
              label: 'MARK AS DELIVERED',
              color: Colors.teal,
            ),
            SizedBox(height: isTablet ? 16 : 12),
          ],

          // CANCEL option for pending and confirmed orders only
          if (['pending', 'confirmed'].contains(status)) ...[
            _buildOutlinedButton(
              context,
              onPressed: () => _showCancelDialog(context),
              icon: Icons.cancel,
              label: 'CANCEL ORDER',
            ),
          ],
        ],
      ),
    );
  }

// Add driver pickup dialog
  void _showDriverPickupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.motorcycle, color: Colors.orange),
            SizedBox(width: 8),
            Text('Driver Pickup'),
          ],
        ),
        content: Text(
          'Confirm that the driver has picked up this order from the restaurant?',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateOrderStatus('pickup');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('CONFIRM PICKUP'),
          ),
        ],
      ),
    );
  }

// Add cancel dialog method
  void _showCancelDialog(BuildContext context) {
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Are you sure you want to cancel this order?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Cancellation Reason',
                hintText: 'Enter reason for cancellation',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('KEEP ORDER'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please provide a cancellation reason'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.pop(context);
              await _cancelOrder(reasonController.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('CANCEL ORDER'),
          ),
        ],
      ),
    );
  }

// Add cancel order method
  Future<void> _cancelOrder(String reason) async {
    if (_orderData == null) return;

    try {
      // Call the cancel API
      await ApiService.instance.cancelOrder(
        orderId: widget.orderId,
        reason: reason,
      );

      setState(() {
        _orderData!['status'] = 'cancelled';
        _orderData!['cancellation'] = {
          'reason': reason,
          'cancelledBy': 'admin',
          'cancelledAt': DateTime.now().toIso8601String(),
        };
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order cancelled successfully'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cancelling order: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildActionButton(
    BuildContext context, {
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    final isTablet = _isTablet(context);

    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: isTablet ? 24 : 20),
      label: Text(
        label,
        style: TextStyle(fontSize: isTablet ? 16 : 14),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          vertical: isTablet ? 20 : 16,
          horizontal: isTablet ? 24 : 16,
        ),
        minimumSize: Size(double.infinity, isTablet ? 60 : 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        elevation: 0,
        shadowColor: Colors.transparent,
      ),
    );
  }

  Widget _buildOutlinedButton(
    BuildContext context, {
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
  }) {
    final isTablet = _isTablet(context);

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: isTablet ? 24 : 20),
      label: Text(
        label,
        style: TextStyle(fontSize: isTablet ? 16 : 14),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.red.shade700,
        padding: EdgeInsets.symmetric(
          vertical: isTablet ? 20 : 16,
          horizontal: isTablet ? 24 : 16,
        ),
        minimumSize: Size(double.infinity, isTablet ? 60 : 50),
        side: BorderSide(color: Colors.red.shade400, width: isTablet ? 2 : 1.5),
        backgroundColor: Colors.red.shade50.withOpacity(0.35),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  Widget _buildFloatingActions(BuildContext context) {
    final isTablet = _isTablet(context);

    return FloatingActionButton.extended(
      onPressed: _printOrder,
      icon: Icon(Icons.print, size: isTablet ? 24 : 20),
      label: Text(
        'PRINT',
        style: TextStyle(fontSize: isTablet ? 16 : 14),
      ),
      backgroundColor: _brandPrimary,
      foregroundColor: Colors.white,
      heroTag: 'print',
      elevation: 0,
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'preparing':
        return Colors.purple;
      case 'ready':
        return Colors.green;
      case 'pickup':
        return Colors.orange.shade700;
      case 'driverpickup':
        return Colors.orange.shade700;
      case 'shop':
        return Colors.deepOrange;
      case 'out-for-delivery':
        return Colors.indigo;
      case 'delivered':
        return Colors.teal;
      case 'cancelled':
        return Colors.red;
      case 'refunded':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.pending_actions;
      case 'confirmed':
        return Icons.check_circle;
      case 'preparing':
        return Icons.restaurant;
      case 'ready':
        return Icons.done_all;
      case 'pickup':
      case 'driverpickup':
        return Icons.person_pin_circle;
      case 'shop':
        return Icons.store;
      case 'out-for-delivery':
        return Icons.local_shipping;
      case 'delivered':
        return Icons.delivery_dining;
      case 'cancelled':
        return Icons.cancel;
      case 'refunded':
        return Icons.money_off;
      default:
        return Icons.info;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
}
