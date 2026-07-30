// screens/orders_dashboard_screen.dart
import 'package:Saborly_admin/providers/auth_provider.dart';
import 'package:Saborly_admin/screens/auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:Saborly_admin/models/order.dart';
import 'package:Saborly_admin/screens/order_details_screen.dart';
import 'package:Saborly_admin/services/order_provider.dart';
import 'package:Saborly_admin/services/order_stream_service.dart';
import 'package:Saborly_admin/services/api_service.dart';
import 'package:Saborly_admin/widgets/order_notification_overlay.dart';
import 'package:Saborly_admin/services/firebase_messaging_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';

class OrdersDashboardScreen extends StatefulWidget {
  const OrdersDashboardScreen({Key? key}) : super(key: key);

  @override
  State<OrdersDashboardScreen> createState() => _OrdersDashboardScreenState();
}

class _OrdersDashboardScreenState extends State<OrdersDashboardScreen>
    with SingleTickerProviderStateMixin {
  static const Color _brandPrimary = Color(0xFF4A148C);
  static const Color _brandSecondary = Color(0xFF7C3AED);

  OverlayEntry? _overlayEntry;
  StreamSubscription? _orderSubscription;
  late TabController _tabController;

  final List<String> _tabs = [
    'All',
    'Pending',
    'Confirmed',
    'Preparing',
    'Ready',
    'Delivered'
  ];
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _listenToNewOrders();
    _loadOrders();
    context.read<AuthProvider>().addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
        (route) => false,
      );
    }
  }

  void _loadOrders() {
    Future.microtask(() {
      context.read<OrderProvider>().loadOrders();
    });
  }

  void _listenToNewOrders() {
    _orderSubscription = OrderStreamService.instance.orderStream.listen(
      (order) {
        final orderData = {
          '_id': order.orderId,
          'orderNumber': order.orderNumber,
          'userId': {
            'firstName': order.customerName,
            'phone': order.customerPhone,
          },
          'branchId': {
            'name': order.branchName,
          },
          'total': order.total,
          'deliveryType': order.deliveryType,
          'status': order.status,
          'createdAt': order.createdAt.toIso8601String(),
        };

        context.read<OrderProvider>().addNewOrder(orderData);
        _showOrderOverlay(order);
      },
    );
  }

  void _showOrderOverlay(OrderNotification order) {
    _removeOverlay();
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 16,
        right: 16,
        child: OrderNotificationOverlay(
          order: order,
          onViewOrder: () {
            _removeOverlay();
            _navigateToOrderDetails(order.orderId);
          },
          onDismiss: _removeOverlay,
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
      FirebaseMessagingService.stopOrderSound();
    }
  }

  void _navigateToOrderDetails(String orderId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderDetailsScreen(orderId: orderId),
      ),
    );
  }

  Future<void> _handleLogout() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: Colors.white,
        contentPadding: EdgeInsets.all(_isTablet ? 28 : 24),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: Color(0xFFDC2626),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Text(
              'Logout',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: _isTablet ? 22 : 20,
                color: const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to logout from your account?',
          style: TextStyle(
            fontSize: _isTablet ? 16 : 15,
            color: const Color(0xFF64748B),
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(
                horizontal: _isTablet ? 24 : 20,
                vertical: _isTablet ? 14 : 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontSize: _isTablet ? 15 : 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              _performLogout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: _isTablet ? 24 : 20,
                vertical: _isTablet ? 14 : 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              'Logout',
              style: TextStyle(
                fontSize: _isTablet ? 15 : 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performLogout() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(Color(0xFF1E40AF)),
                  strokeWidth: 3,
                ),
                const SizedBox(height: 20),
                Text(
                  'Logging out...',
                  style: TextStyle(
                    fontSize: _isTablet ? 16 : 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await ApiService.instance.logout();

      if (mounted) {
        Navigator.pop(context);
      }

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => AdminLoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Logout error: $e');
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Logout failed: $e')),
              ],
            ),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    context.read<AuthProvider>().removeListener(_onAuthChanged);
    _removeOverlay();
    _orderSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  bool get _isTablet => MediaQuery.of(context).size.width >= 600;
  bool get _isLargeTablet => MediaQuery.of(context).size.width >= 900;
  String _formatAmount(dynamic amount) {
    final parsed = amount is num ? amount.toDouble() : double.tryParse(amount?.toString() ?? '0') ?? 0.0;
    return 'EUR ${parsed.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildAppBar(),
          _buildStatsSection(),
          _buildTabBar(),
        ],
        body: TabBarView(
          controller: _tabController,
          children: _tabs.map((tab) => _buildOrdersList(tab)).toList(),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: _isTablet ? 120 : 100,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: EdgeInsets.only(
          left: _isTablet ? 32 : 20,
          bottom: 20,
        ),
        title: Consumer<AuthProvider>(
          builder: (context, auth, _) => Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_brandPrimary, _brandSecondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _brandPrimary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.receipt_long_rounded,
                  color: Colors.white,
                  size: _isTablet ? 22 : 20,
                ),
              ),
              SizedBox(width: _isTablet ? 14 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Orders',
                      style: TextStyle(
                        fontSize: _isTablet ? 18 : 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      auth.selectedBranch?.name ?? 'No Branch Selected',
                      style: TextStyle(
                        fontSize: _isTablet ? 12 : 11,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                const Color(0xFFE2E8F0).withOpacity(0.5),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
      actions: [
        _buildActionButton(
          icon: Icons.store_rounded,
          color: _brandSecondary,
          onTap: () => _showBranchSwitchDialog(context),
          tooltip: 'Switch Branch',
        ),
        Consumer<OrderProvider>(
          builder: (context, provider, _) => _buildActionButton(
            icon:
                provider.autoPrintEnabled ? Icons.print : Icons.print_disabled,
            color: provider.autoPrintEnabled
                ? _brandPrimary
                : const Color(0xFF94A3B8),
            onTap: _showSettingsDialog,
            tooltip: 'Settings',
          ),
        ),
        _buildActionButton(
          icon: Icons.refresh_rounded,
          color: const Color(0xFF64748B),
          onTap: _loadOrders,
          tooltip: 'Refresh',
        ),
        _buildActionButton(
          icon: Icons.logout_rounded,
          color: const Color(0xFFDC2626),
          onTap: _handleLogout,
          tooltip: 'Logout',
          isLast: true,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String tooltip,
    bool isLast = false,
  }) {
    return Container(
      margin: EdgeInsets.only(
        right: isLast ? (_isTablet ? 20 : 16) : (_isTablet ? 8 : 6),
      ),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: color.withOpacity(0.15),
                  width: 1,
                ),
              ),
              child: Icon(
                icon,
                color: color,
                size: _isTablet ? 20 : 18,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    return SliverToBoxAdapter(
      child: Consumer<OrderProvider>(
        builder: (context, provider, _) {
          final stats = provider.getTodayStats();

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: Color(0xFFF1F5F9),
                  width: 1,
                ),
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              _isTablet ? 32 : 16,
              _isTablet ? 20 : 16,
              _isTablet ? 32 : 16,
              _isTablet ? 24 : 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 2, bottom: 12),
                  child: Text(
                    "Today's Overview",
                    style: GoogleFonts.inter(
                      fontSize: _isTablet ? 13 : 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF94A3B8),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        stats['totalOrders'].toString(),
                        'Total',
                        const Color(0xFF4A148C),
                        Icons.receipt_long_rounded,
                        const Color(0xFFF3E5FF),
                      ),
                    ),
                    SizedBox(width: _isTablet ? 12 : 10),
                    Expanded(
                      child: _buildStatCard(
                        stats['pendingOrders'].toString(),
                        'Pending',
                        const Color(0xFFEA580C),
                        Icons.pending_actions_rounded,
                        const Color(0xFFFFF0E6),
                      ),
                    ),
                    SizedBox(width: _isTablet ? 12 : 10),
                    Expanded(
                      child: _buildStatCard(
                        stats['completedOrders'].toString(),
                        'Done',
                        const Color(0xFF059669),
                        Icons.check_circle_rounded,
                        const Color(0xFFE6FAF3),
                      ),
                    ),
                    SizedBox(width: _isTablet ? 12 : 10),
                    Expanded(
                      child: _buildStatCard(
                        '€${(stats['revenue'] as double).toStringAsFixed(0)}',
                        'Revenue',
                        const Color(0xFF0891B2),
                        Icons.payments_rounded,
                        const Color(0xFFE0F6FB),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(
    String value,
    String label,
    Color color,
    IconData icon,
    Color bgColor,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _isTablet ? 14 : 10,
        vertical: _isTablet ? 16 : 12,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(_isTablet ? 14 : 12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: _isTablet ? 18 : 16),
          ),
          SizedBox(height: _isTablet ? 10 : 8),
          Text(
            value,
            style: GoogleFonts.inter(
              color: const Color(0xFF0F172A),
              fontSize: _isTablet ? 22 : 18,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFF64748B),
              fontSize: _isTablet ? 12 : 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return SliverToBoxAdapter(
      child: Container(
        color: const Color(0xFFF8FAFC),
        padding: EdgeInsets.fromLTRB(
          _isTablet ? 32 : 16,
          10,
          _isTablet ? 32 : 16,
          6,
        ),
        child: Container(
          height: _isTablet ? 48 : 44,
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            padding: const EdgeInsets.all(4),
            labelPadding: EdgeInsets.symmetric(
              horizontal: _isTablet ? 14 : 10,
            ),
            indicator: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: _brandPrimary,
            unselectedLabelColor: const Color(0xFF64748B),
            labelStyle: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              fontSize: _isTablet ? 13 : 12,
            ),
            unselectedLabelStyle: GoogleFonts.inter(
              fontWeight: FontWeight.w500,
              fontSize: _isTablet ? 13 : 12,
            ),
            tabs: _tabs.map((tab) {
              return Consumer<OrderProvider>(
                builder: (context, provider, _) {
                  final count = tab == 'All'
                      ? provider.orders.length
                      : provider.getStatusCount(tab.toLowerCase());

                  return Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(tab),
                        if (count > 0) ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(tab.toLowerCase())
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              count.toString(),
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _getStatusColor(tab.toLowerCase()),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildOrdersList(String tab) {
    return Consumer<OrderProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: _isTablet ? 70 : 64,
                  height: _isTablet ? 70 : 64,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF1E40AF).withOpacity(0.1),
                        const Color(0xFF3B82F6).withOpacity(0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(Color(0xFF1E40AF)),
                      strokeWidth: 3,
                    ),
                  ),
                ),
                SizedBox(height: _isTablet ? 24 : 20),
                Text(
                  'Loading orders...',
                  style: TextStyle(
                    color: const Color(0xFF64748B),
                    fontSize: _isTablet ? 16 : 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }

        if (provider.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(_isTablet ? 20 : 18),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFEE2E2), Color(0xFFFECDD3)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFDC2626),
                    size: 32,
                  ),
                ),
                SizedBox(height: _isTablet ? 24 : 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    provider.error!,
                    style: TextStyle(
                      color: const Color(0xFF1F2937),
                      fontSize: _isTablet ? 16 : 15,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: _isTablet ? 28 : 24),
                ElevatedButton.icon(
                  onPressed: _loadOrders,
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E40AF),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: _isTablet ? 32 : 28,
                      vertical: _isTablet ? 16 : 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          );
        }

        List<Map<String, dynamic>> orders = tab == 'All'
            ? provider.orders
            : provider.getOrdersByStatus(tab.toLowerCase());

        if (orders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(_isTablet ? 28 : 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFF1F5F9),
                        const Color(0xFFE2E8F0).withOpacity(0.5),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.shopping_bag_outlined,
                    size: _isTablet ? 64 : 60,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
                SizedBox(height: _isTablet ? 24 : 20),
                Text(
                  'No ${tab.toLowerCase()} orders',
                  style: TextStyle(
                    fontSize: _isTablet ? 18 : 17,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'New orders will appear here',
                  style: TextStyle(
                    fontSize: _isTablet ? 14 : 13,
                    color: const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => provider.loadOrders(),
          color: const Color(0xFF1E40AF),
          child:
              _isLargeTablet ? _buildGridView(orders) : _buildListView(orders),
        );
      },
    );
  }

  Widget _buildListView(List<Map<String, dynamic>> orders) {
    return ListView.separated(
      padding: EdgeInsets.all(_isTablet ? 24 : 20),
      itemCount: orders.length,
      separatorBuilder: (_, __) => SizedBox(height: _isTablet ? 14 : 12),
      itemBuilder: (context, index) => _buildOrderCard(orders[index]),
    );
  }

  Widget _buildGridView(List<Map<String, dynamic>> orders) {
    return GridView.builder(
      padding: const EdgeInsets.all(32),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.6,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
      ),
      itemCount: orders.length,
      itemBuilder: (context, index) => _buildOrderCard(orders[index]),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final status = order['status'] as String;
    final isUrgent = _isOrderUrgent(order);
    final statusColor = _getStatusColor(status);

    final accentColor = isUrgent ? const Color(0xFFDC2626) : statusColor;
    final phone = (order['userId'] is Map ? order['userId']['phone'] : order['customerPhone']) as String?;
    final customerName = (order['userId'] is Map ? order['userId']['firstName'] : null) ?? 'Customer';
    final branchName = order['branchId'] is Map ? order['branchId']['name'] : order['branchName'];
    final isDelivery = order['deliveryType'] == 'delivery';

    return ClipRRect(
      borderRadius: BorderRadius.circular(_isTablet ? 14 : 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_isTablet ? 14 : 12),
          border: Border.all(color: const Color(0xFFE8ECF0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _navigateToOrderDetails(order['_id']),
            borderRadius: BorderRadius.circular(_isTablet ? 14 : 12),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left accent bar
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                      ),
                    ),
                  ),
                  // Card content
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(_isTablet ? 16 : 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top row: order number + urgent + time
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  order['orderNumber'] ?? 'N/A',
                                  style: GoogleFonts.inter(
                                    color: statusColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: _isTablet ? 13 : 12,
                                  ),
                                ),
                              ),
                              if (isUrgent) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEE2E2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.warning_rounded, size: 12, color: Color(0xFFDC2626)),
                                      const SizedBox(width: 4),
                                      Text('URGENT', style: GoogleFonts.inter(
                                        color: const Color(0xFFDC2626),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      )),
                                    ],
                                  ),
                                ),
                              ],
                              const Spacer(),
                              Row(
                                children: [
                                  const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF94A3B8)),
                                  const SizedBox(width: 3),
                                  Text(
                                    _formatTime(DateTime.parse(order['createdAt'])),
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF94A3B8),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Customer + amount row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      customerName,
                                      style: GoogleFonts.inter(
                                        fontSize: _isTablet ? 15 : 14,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF0F172A),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (phone != null && phone.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        phone,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: const Color(0xFF1E40AF),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _formatAmount(order['total'] ?? 0),
                                    style: GoogleFonts.inter(
                                      fontSize: _isTablet ? 18 : 17,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF0F172A),
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  // Delivery type badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isDelivery ? const Color(0xFFDCEAFF) : const Color(0xFFD1FAE5),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isDelivery ? Icons.delivery_dining_rounded : Icons.shopping_bag_rounded,
                                          size: 11,
                                          color: isDelivery ? const Color(0xFF1E40AF) : const Color(0xFF059669),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          (order['deliveryType'] ?? 'pickup').toUpperCase(),
                                          style: GoogleFonts.inter(
                                            fontSize: 9,
                                            color: isDelivery ? const Color(0xFF1E40AF) : const Color(0xFF059669),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (branchName != null) ...[
                            const SizedBox(height: 8),
                            Divider(height: 1, color: const Color(0xFFF1F5F9)),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.store_rounded, size: 12, color: Color(0xFF94A3B8)),
                                const SizedBox(width: 5),
                                Text(
                                  branchName,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: const Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showBranchSwitchDialog(BuildContext context) {
    final authProvider = context.read<AuthProvider>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Switch Branch'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: authProvider.branches.map((branch) {
            final isSelected = branch.id == authProvider.selectedBranch?.id;
            return ListTile(
              leading: Icon(
                Icons.store_rounded,
                color: isSelected ? const Color(0xFF1E40AF) : Colors.grey,
              ),
              title: Text(
                branch.name,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? const Color(0xFF1E40AF) : Colors.black87,
                ),
              ),
              trailing: isSelected
                  ? const Icon(Icons.check_circle, color: Color(0xFF1E40AF))
                  : null,
              onTap: () {
                Navigator.pop(context);
                if (!isSelected) {
                  authProvider.setSelectedBranch(branch);
                  _loadOrders(); // Re-fetch all data for new branch
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: Colors.white,
        contentPadding: EdgeInsets.all(_isTablet ? 28 : 24),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.settings_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Text(
              'Settings',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: _isTablet ? 22 : 20,
                color: const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        content: Consumer<OrderProvider>(
          builder: (context, provider, _) => Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSettingTile(
                  icon: Icons.print,
                  title: 'Auto-Print Orders',
                  subtitle: 'Automatically print new orders',
                  value: provider.autoPrintEnabled,
                  onChanged: (value) => provider.toggleAutoPrint(value),
                ),
                Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        const Color(0xFFE2E8F0),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                _buildSettingTile(
                  icon: Icons.check_circle,
                  title: 'Auto-Accept Orders',
                  subtitle: 'Automatically confirm new orders',
                  value: provider.autoAcceptEnabled,
                  onChanged: (value) => provider.toggleAutoAccept(value),
                ),
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E40AF),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: _isTablet ? 32 : 28,
                vertical: _isTablet ? 16 : 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              'Done',
              style: TextStyle(
                fontSize: _isTablet ? 15 : 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.symmetric(
        horizontal: _isTablet ? 20 : 16,
        vertical: _isTablet ? 12 : 10,
      ),
      secondary: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: value ? const Color(0xFFDCEAFF) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: value ? const Color(0xFF1E40AF) : const Color(0xFF94A3B8),
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: _isTablet ? 16 : 15,
          color: const Color(0xFF0F172A),
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          subtitle,
          style: TextStyle(
            fontSize: _isTablet ? 13 : 12,
            color: const Color(0xFF64748B),
          ),
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: const Color(0xFF1E40AF),
      activeTrackColor: const Color(0xFF1E40AF).withOpacity(0.3),
      inactiveThumbColor: const Color(0xFFCBD5E1),
      inactiveTrackColor: const Color(0xFFE2E8F0),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'all':
        return const Color(0xFF1E40AF);
      case 'pending':
        return const Color(0xFFEA580C);
      case 'confirmed':
        return const Color(0xFF2563EB);
      case 'preparing':
        return const Color(0xFF7C3AED);
      case 'ready':
        return const Color(0xFF059669);
      case 'delivered':
        return const Color(0xFF0891B2);
      case 'completed':
        return const Color(0xFF047857);
      case 'cancelled':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF64748B);
    }
  }

  bool _isOrderUrgent(Map<String, dynamic> order) {
    final createdAt = DateTime.parse(order['createdAt']);
    final difference = DateTime.now().difference(createdAt);
    return order['status'] == 'pending' && difference.inMinutes > 5;
  }

  String _formatTime(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inMinutes < 1) return 'Now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m';
    if (difference.inHours < 24) return '${difference.inHours}h';
    return '${dateTime.day}/${dateTime.month}';
  }
}
