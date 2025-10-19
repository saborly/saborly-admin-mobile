import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:saborlyadmin/models/order.dart';
import 'package:saborlyadmin/services/order_print_service.dart';
import 'package:saborlyadmin/services/order_provider.dart';

class OrderDetailsScreen extends StatefulWidget {
  final String orderId;

  const OrderDetailsScreen({Key? key, required this.orderId}) : super(key: key);

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  Map<String, dynamic>? _orderData;
  bool _isLoading = true;
  String? _error;

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
      final success = await orderProvider.updateOrderStatus(widget.orderId, newStatus);
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
        appBar: AppBar(
          title: const Text('Order Details'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Order Details'),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadOrderDetails,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final isTablet = _isTablet(context);

    return Scaffold(
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
          colors: [Color(0xFF4A148C), Color(0xFF6A1B9A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A148C).withOpacity(0.3),
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
          if (_orderData!['deliveryFee'] != null && _orderData!['deliveryFee'] > 0) ...[
            SizedBox(height: isTablet ? 10 : 8),
            _buildPriceRow(
              context,
              'Delivery Fee',
              _orderData!['deliveryFee']?.toDouble() ?? 0.0,
            ),
          ],
          if (_orderData!['tax'] != null && _orderData!['tax'] > 0) ...[
            SizedBox(height: isTablet ? 10 : 8),
            _buildPriceRow(context, 'Tax', _orderData!['tax']?.toDouble() ?? 0.0),
          ],
          if (_orderData!['discount'] != null && _orderData!['discount'] > 0) ...[
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
                '\$${_orderData!['total']?.toDouble().toStringAsFixed(2) ?? '0.00'}',
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
          '\$${amount.toStringAsFixed(2)}',
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
              colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
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
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(30),
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
        gradient: LinearGradient(
          colors: [
            _getStatusColor(status).withOpacity(0.1),
            _getStatusColor(status).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _getStatusColor(status).withOpacity(0.3),
          width: 2,
        ),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '👤 Customer Details',
            style: TextStyle(
              fontSize: _getResponsiveFontSize(context, 18),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: isTablet ? 20 : 16),
          _buildDetailRow(
            context,
            Icons.person,
            'Name',
            '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}',
          ),
          SizedBox(height: isTablet ? 16 : 12),
          _buildDetailRow(
            context,
            Icons.phone,
            'Phone',
            user['phone'] ?? 'N/A',
            isClickable: true,
          ),
          if (address != null) ...[
            SizedBox(height: isTablet ? 16 : 12),
            _buildDetailRow(
              context,
              Icons.location_on,
              'Address',
              address['address'] ?? 'N/A',
            ),
            if (address['apartment'] != null) ...[
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
    
    return Row(
      children: [
        Icon(
          icon,
          size: isTablet ? 24 : 20,
          color: const Color(0xFF4A148C),
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
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: isTablet ? 16 : 14,
                  fontWeight: FontWeight.w600,
                  color: isClickable ? Colors.blue : Colors.black87,
                  decoration: isClickable ? TextDecoration.underline : null,
                ),
              ),
            ],
          ),
        ),
      ],
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🍔 Order Items',
            style: TextStyle(
              fontSize: _getResponsiveFontSize(context, 18),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: isTablet ? 20 : 16),
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
  
  // Extract item name - handle both string and map (multilingual) formats
  String itemName = 'Unknown Item';
  final foodItemName = item['foodItem']?['name'];
  if (foodItemName is String) {
    itemName = foodItemName;
  } else if (foodItemName is Map) {
    // Get name in preferred order: English > Spanish > first available
    itemName = foodItemName['en'] ?? 
               foodItemName['es'] ?? 
               foodItemName.values.first ?? 
               'Unknown Item';
  }
  
  return Container(
    padding: EdgeInsets.all(isTablet ? 16 : 12),
    decoration: BoxDecoration(
      color: Colors.grey[50],
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(isTablet ? 12 : 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B35).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${item['quantity']}x',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFFF6B35),
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
              '\$${item['totalPrice']?.toDouble().toStringAsFixed(2) ?? '0.00'}',
              style: TextStyle(
                fontSize: isTablet ? 18 : 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF4A148C),
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
              color: Colors.grey[700],
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
              color: Colors.grey[700],
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
          
          if (status == 'preparing') ...[
            _buildActionButton(
              context,
              onPressed: () => _updateOrderStatus('ready'),
              icon: Icons.check,
              label: 'MARK AS READY',
              color: Colors.green,
            ),
            SizedBox(height: isTablet ? 16 : 12),
          ],
          
          if (status == 'ready') ...[
            if (_isDeliveryOrder) ...[
              _buildActionButton(
                context,
                onPressed: () => _updateOrderStatus('pickup'),
                icon: Icons.person_pin_circle,
                label: 'MARK AS PICKED UP BY DRIVER',
                color: Colors.orange,
              ),
            ] else ...[
              _buildActionButton(
                context,
                onPressed: () => _updateOrderStatus('delivered'),
                icon: Icons.check_circle_outline,
                label: 'MARK AS PICKED UP BY CUSTOMER',
                color: Colors.teal,
              ),
            ],
            SizedBox(height: isTablet ? 16 : 12),
          ],
          
          if (status == 'pickup' && _isDeliveryOrder) ...[
            _buildActionButton(
              context,
              onPressed: () => _updateOrderStatus('out-for-delivery'),
              icon: Icons.local_shipping,
              label: 'OUT FOR DELIVERY',
              color: Colors.indigo,
            ),
            SizedBox(height: isTablet ? 16 : 12),
          ],
          
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
          
          if (['pending', 'confirmed'].contains(status)) ...[
            _buildOutlinedButton(
              context,
              onPressed: () => _updateOrderStatus('cancelled'),
              icon: Icons.cancel,
              label: 'CANCEL ORDER',
            ),
          ],
        ],
      ),
    );
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
          borderRadius: BorderRadius.circular(12),
        ),
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
        foregroundColor: Colors.red,
        padding: EdgeInsets.symmetric(
          vertical: isTablet ? 20 : 16,
          horizontal: isTablet ? 24 : 16,
        ),
        minimumSize: Size(double.infinity, isTablet ? 60 : 50),
        side: BorderSide(color: Colors.red, width: isTablet ? 2 : 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
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
      backgroundColor: const Color(0xFFFF6B35),
      heroTag: 'print',
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
        return Colors.orange;
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