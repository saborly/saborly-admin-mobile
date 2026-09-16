import 'package:Saborly_admin/services/api_service.dart';
import 'package:Saborly_admin/services/firebase_messaging_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:Saborly_admin/services/order_print_service.dart';
import 'package:Saborly_admin/services/order_provider.dart';
import 'package:Saborly_admin/theme/app_colors.dart';

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
  /// Turns a raw backend value like `cashOnDelivery` or `out-for-delivery`
  /// into a readable label ("Cash On Delivery") instead of showing it
  /// verbatim in ALL CAPS, which reads as broken rather than intentional.
  String _prettyLabel(String raw) {
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

  Future<void> _loadOrderDetails({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      final orderData = await orderProvider.loadOrderDetails(widget.orderId);
      if (orderData != null) {
        setState(() {
          _orderData = orderData;
          _isLoading = false;
        });
      } else if (!silent) {
        setState(() {
          _error = 'Failed to load order details';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!silent) {
        setState(() {
          _error = 'Error loading order details: $e';
          _isLoading = false;
        });
      }
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
        // Stop ringing when order is accepted or any status is updated
        if (newStatus == 'confirmed' || newStatus == 'cancelled') {
          FirebaseMessagingService.stopOrderSound();
        }
        // Accepting a delivery order can auto-assign a driver server-side —
        // refetch the full order rather than patching just the status field
        // locally, so the driver info shows up immediately without the
        // admin needing to back out and re-open the screen.
        if (newStatus == 'confirmed' && _isDeliveryOrder) {
          await _loadOrderDetails(silent: true);
        } else {
          setState(() {
            _orderData!['status'] = newStatus;
          });
        }
        if (!mounted) return;
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

  bool _assigningDriver = false;

  Future<void> _showAssignDriverDialog() async {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    await orderProvider.loadAvailableDrivers();
    if (!mounted) return;

    final drivers = orderProvider.availableDrivers;

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) {
        if (drivers.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Text('No drivers available in this branch right now.'),
          );
        }
        return SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: drivers.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final driver = drivers[index];
              final isOnline = (driver['driverStatus'] as Map<String, dynamic>?)?['isOnline'] == true;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Icon(Icons.two_wheeler_rounded, color: AppColors.primary),
                ),
                title: Text('${driver['firstName'] ?? ''} ${driver['lastName'] ?? ''}'.trim()),
                subtitle: Text(driver['phone'] ?? ''),
                trailing: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isOnline ? Colors.green : Colors.grey.shade400,
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _assignDriver(driver);
                },
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _assignDriver(Map<String, dynamic> driver) async {
    if (_orderData == null) return;
    setState(() => _assigningDriver = true);

    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final success = await orderProvider.assignDriver(widget.orderId, driver['_id'].toString());

    if (!mounted) return;
    setState(() {
      _assigningDriver = false;
      if (success) _orderData!['deliveryAgent'] = driver;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Driver assigned' : 'Failed to assign driver'),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.surfaceAlt,
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
        backgroundColor: AppColors.surfaceAlt,
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
      backgroundColor: AppColors.surfaceAlt,
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
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      // Pinned above the keyboard/home-indicator instead of buried at the
      // bottom of a scroll, so the primary action is always reachable —
      // matches the accept/reject bar pattern from the reference designs.
      bottomNavigationBar: SafeArea(
        child: _buildBottomActionBar(context),
      ),
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
        _buildDriverAssignmentSection(context),
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
        _buildDriverAssignmentSection(context),
      ],
    );
  }

  Widget _buildPricingDetails(BuildContext context) {
    final isTablet = _isTablet(context);

    return Container(
      margin: _getResponsivePadding(context),
      padding: _getCardPadding(context),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.softShadow(),
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
          const Divider(color: AppColors.divider, thickness: 1),
          SizedBox(height: isTablet ? 16 : 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: TextStyle(
                  color: AppColors.textDark,
                  fontSize: _getResponsiveFontSize(context, 16),
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                _formatAmount(_orderData!['total']),
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: _getResponsiveFontSize(context, 20),
                  fontWeight: FontWeight.w800,
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
            color: AppColors.textMedium,
            fontSize: _getResponsiveFontSize(context, 14),
          ),
        ),
        Text(
          _formatAmount(amount),
          style: TextStyle(
            color: AppColors.textDark,
            fontSize: _getResponsiveFontSize(context, 14),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.textDark,
      title: Text('#${_orderData!['orderNumber']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      actions: [
        Center(
          child: Text(
            _formatDateTime(DateTime.parse(_orderData!['createdAt'])),
            style: const TextStyle(fontSize: 12.5, color: AppColors.textMedium, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          onPressed: _printOrder,
          icon: const Icon(Icons.print_outlined, color: AppColors.textMedium, size: 22),
          tooltip: 'Print receipt',
        ),
      ],
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
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.softShadow(),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _getStatusIcon(status),
                color: AppColors.statusColor(status),
                size: isTablet ? 40 : 32,
              ),
              SizedBox(width: isTablet ? 16 : 12),
              Text(
                AppColors.statusLabel(status),
                style: TextStyle(
                  fontSize: _getResponsiveFontSize(context, 22),
                  fontWeight: FontWeight.bold,
                  color: AppColors.statusColor(status),
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
                label: _prettyLabel(_orderData!['deliveryType']),
              ),
              _buildInfoChip(
                context,
                icon: Icons.payment,
                label: _prettyLabel(_orderData!['paymentMethod']),
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
        horizontal: isTablet ? 16 : 12,
        vertical: isTablet ? 8 : 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.chipBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: isTablet ? 18 : 15,
            color: AppColors.textMedium,
          ),
          SizedBox(width: isTablet ? 8 : 6),
          Text(
            label,
            style: TextStyle(
              fontSize: isTablet ? 13 : 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
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
            color: const Color(0xFF0F172A).withOpacity(0.05),
            blurRadius: 16,
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
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.primary,
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
            onTap: () {
              final phone = user is Map ? user['phone'] : _orderData!['customerPhone'];
              if (phone != null && phone.toString().trim().isNotEmpty) {
                _showContactOptions(context, phone.toString());
              }
            },
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
    VoidCallback? onTap,
  }) {
    final isTablet = _isTablet(context);

    final row = Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: isTablet ? 24 : 20,
            color: AppColors.primary,
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
                        ? AppColors.primary
                        : const Color(0xFF0F172A),
                    decoration: isClickable ? TextDecoration.underline : null,
                  ),
                ),
              ],
            ),
          ),
          if (isClickable && onTap != null)
            const Icon(Icons.chevron_right_rounded, color: AppColors.textLight, size: 20),
        ],
      ),
    );

    if (!isClickable || onTap == null) return row;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: row,
      ),
    );
  }

  /// Lets the admin reach the customer directly from the order — a plain
  /// phone-number label with no action was a dead end before.
  void _showContactOptions(BuildContext context, String phone) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)),
                ),
              ),
              Text('Contact customer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark)),
              const SizedBox(height: 4),
              Text(phone, style: TextStyle(fontSize: 13.5, color: AppColors.textMedium)),
              const SizedBox(height: 18),
              _ContactOptionTile(
                icon: Icons.call_rounded,
                iconColor: AppColors.primary,
                label: 'Call',
                subtitle: phone,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _launchPhoneCall(phone);
                },
              ),
              const SizedBox(height: 10),
              _ContactOptionTile(
                icon: Icons.chat_rounded,
                iconColor: const Color(0xFF25D366),
                label: 'WhatsApp',
                subtitle: 'Open a chat',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _launchWhatsApp(phone);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchPhoneCall(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone.trim());
    final launched = await launchUrl(uri);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the phone dialer')),
      );
    }
  }

  Future<void> _launchWhatsApp(String phone) async {
    // wa.me wants digits only (country code, no '+', spaces or dashes).
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/$digits');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open WhatsApp')),
      );
    }
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
            color: const Color(0xFF0F172A).withOpacity(0.05),
            blurRadius: 16,
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
                  color: AppColors.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.receipt_long_rounded,
                  color: AppColors.accent,
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
      // Get name in preferred order: English > Spanish > Catalan > Arabic > French
      itemName = foodItemName['en'] ??
          foodItemName['es'] ??
          foodItemName['ca'] ??
          foodItemName['ar'] ??
          foodItemName['fr'] ??
          (foodItemName.values.isNotEmpty
              ? foodItemName.values.first.toString()
              : 'Unknown Item');
    }

    return Container(
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isTablet ? 12 : 8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${item['quantity']}x',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.accent,
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
                  color: AppColors.primary,
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

  Widget _buildDriverAssignmentSection(BuildContext context) {
    final status = _orderData!['status'];
    if (!_isDeliveryOrder || ['cancelled', 'delivered', 'refunded'].contains(status)) {
      return const SizedBox.shrink();
    }

    final driver = _orderData!['deliveryAgent'] as Map<String, dynamic>?;
    final isOnline = (driver?['driverStatus'] as Map<String, dynamic>?)?['isOnline'] == true;
    final isTablet = _isTablet(context);

    return Container(
      margin: EdgeInsets.fromLTRB(isTablet ? 24 : 16, 0, isTablet ? 24 : 16, isTablet ? 16 : 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: driver != null ? AppColors.primary.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: driver != null ? AppColors.primary.withOpacity(0.18) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(Icons.two_wheeler_rounded, color: AppColors.primary, size: 22),
              ),
              if (driver != null)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isOnline ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driver != null ? '${driver['firstName'] ?? ''} ${driver['lastName'] ?? ''}'.trim() : 'No driver assigned yet',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 2),
                Text(
                  driver != null
                      ? (isOnline ? 'Online · sharing live location' : 'Offline right now')
                      : 'Assign a driver so this order shows up on their map',
                  style: TextStyle(
                    fontSize: 12,
                    color: driver != null && isOnline ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                    fontWeight: driver != null && isOnline ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _assigningDriver ? null : _showAssignDriverDialog,
            child: _assigningDriver
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(driver != null ? 'Change' : 'Assign', style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  /// Pinned action bar for the order-details screen (set as `bottomNavigationBar`
  /// so it's reachable without scrolling). Pending orders get a split
  /// Reject/Accept row — the pattern most admin order apps use for the
  /// single decision that matters most — everything else gets one primary
  /// action plus a cancel option below it.
  Widget _buildBottomActionBar(BuildContext context) {
    final status = _orderData!['status'];
    final isTablet = _isTablet(context);

    if (['delivered', 'cancelled', 'refunded'].contains(status)) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.fromLTRB(isTablet ? 24 : 16, 14, isTablet ? 24 : 16, isTablet ? 20 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: status == 'pending' ? _buildPendingActions(context) : _buildInProgressActions(context, status),
    );
  }

  Widget _buildPendingActions(BuildContext context) {
    final isTablet = _isTablet(context);
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            context,
            onPressed: () => _showCancelDialog(context),
            icon: Icons.close_rounded,
            label: 'Reject Order',
            color: AppColors.danger,
          ),
        ),
        SizedBox(width: isTablet ? 16 : 12),
        Expanded(
          child: _buildActionButton(
            context,
            onPressed: () => _updateOrderStatus('confirmed'),
            icon: Icons.check_circle,
            label: 'Accept Order',
            color: Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildInProgressActions(BuildContext context, String status) {
    final isTablet = _isTablet(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // CONFIRMED -> PREPARING
          if (status == 'confirmed') ...[
            _buildActionButton(
              context,
              onPressed: () => _updateOrderStatus('preparing'),
              icon: Icons.restaurant,
              label: 'Start Preparing',
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
              label: 'Mark as Ready',
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
                label: 'Driver Picked Up',
                color: Colors.orange,
              ),
            ] else ...[
              // For pickup orders: READY -> DELIVERED (customer picks up)
              _buildActionButton(
                context,
                onPressed: () => _updateOrderStatus('delivered'),
                icon: Icons.check_circle_outline,
                label: 'Customer Picked Up',
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
              label: 'Out for Delivery',
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
              label: 'Mark as Delivered',
              color: Colors.teal,
            ),
            SizedBox(height: isTablet ? 16 : 12),
          ],

          // Cancel stays available at every stage up until the order is
          // actually delivered — matches what the backend already allows
          // (PATCH /:id/cancel rejects only delivered/cancelled/refunded).
          _buildOutlinedButton(
            context,
            onPressed: () => _showCancelDialog(context),
            icon: Icons.cancel,
            label: 'Cancel Order',
          ),
        ],
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
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateOrderStatus('pickup');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Confirm Pickup'),
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
            child: const Text('Keep Order'),
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
            child: const Text('Cancel Order'),
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

      FirebaseMessagingService.stopOrderSound();
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

class _ContactOptionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _ContactOptionTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: iconColor.withOpacity(0.12), shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppColors.textDark)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 12.5, color: AppColors.textMedium)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textLight, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
