// screens/orders_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:saborlyadmin/models/order.dart';
import 'package:saborlyadmin/screens/order_details_screen.dart';
import 'package:saborlyadmin/services/order_provider.dart';
import 'package:saborlyadmin/services/order_stream_service.dart';
import 'package:saborlyadmin/widgets/order_notification_overlay.dart';
import 'dart:async';

class OrdersDashboardScreen extends StatefulWidget {
  const OrdersDashboardScreen({Key? key}) : super(key: key);

  @override
  State<OrdersDashboardScreen> createState() => _OrdersDashboardScreenState();
}

class _OrdersDashboardScreenState extends State<OrdersDashboardScreen> 
    with SingleTickerProviderStateMixin {
  OverlayEntry? _overlayEntry;
  StreamSubscription? _orderSubscription;
  late TabController _tabController;
  
  final List<String> _tabs = ['All', 'Pending', 'Confirmed', 'Preparing', 'Ready'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _listenToNewOrders();
    _loadOrders();
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
          'userId': {'firstName': order.customerName},
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
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _navigateToOrderDetails(String orderId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderDetailsScreen(orderId: orderId),
      ),
    );
  }

  @override
  void dispose() {
    _removeOverlay();
    _orderSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  bool get _isTablet => MediaQuery.of(context).size.width >= 600;
  bool get _isLargeTablet => MediaQuery.of(context).size.width >= 900;

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
      expandedHeight: _isTablet ? 100 : 90,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: EdgeInsets.only(
          left: _isTablet ? 32 : 20,
          bottom: 16,
        ),
        title: Text(
          'Orders',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
            fontSize: _isTablet ? 26 : 22,
            letterSpacing: -0.5,
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: const Color(0xFFE2E8F0),
        ),
      ),
      actions: [
        Consumer<OrderProvider>(
          builder: (context, provider, _) => Container(
            margin: EdgeInsets.only(right: _isTablet ? 12 : 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _showSettingsDialog,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    provider.autoPrintEnabled ? Icons.print : Icons.print_disabled,
                    color: provider.autoPrintEnabled 
                        ? const Color(0xFF1E40AF)
                        : const Color(0xFFCBD5E1),
                    size: _isTablet ? 22 : 20,
                  ),
                ),
              ),
            ),
          ),
        ),
        Container(
          margin: EdgeInsets.only(right: _isTablet ? 20 : 16),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _loadOrders,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.refresh_rounded,
                  color: const Color(0xFF64748B),
                  size: _isTablet ? 22 : 20,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsSection() {
    return SliverToBoxAdapter(
      child: Consumer<OrderProvider>(
        builder: (context, provider, _) {
          final stats = provider.getTodayStats();
          
          return Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(
              _isTablet ? 32 : 20,
              _isTablet ? 28 : 24,
              _isTablet ? 32 : 20,
              _isTablet ? 28 : 24,
            ),
            child: _isLargeTablet
                ? Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          stats['totalOrders'].toString(),
                          'Total Orders',
                          const Color(0xFF1E40AF),
                          Icons.receipt_long_rounded,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: _buildStatCard(
                          stats['completedOrders'].toString(),
                          'Completed',
                          const Color(0xFF065F46),
                          Icons.check_circle_rounded,
                        ),
                      ),
                      const SizedBox(width: 20),
                  
                    ],
                  )
                : Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              stats['totalOrders'].toString(),
                              'Total Orders',
                              const Color(0xFF1E40AF),
                              Icons.receipt_long_rounded,
                            ),
                          ),
                          SizedBox(width: _isTablet ? 20 : 16),
                          Expanded(
                            child: _buildStatCard(
                              stats['completedOrders'].toString(),
                              'Completed',
                              const Color(0xFF065F46),
                              Icons.check_circle_rounded,
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

  Widget _buildStatCard(String value, String label, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _isTablet ? 20 : 16,
        vertical: _isTablet ? 20 : 16,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.02),
        borderRadius: BorderRadius.circular(_isTablet ? 14 : 12),
        border: Border.all(
          color: color.withOpacity(0.15),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(_isTablet ? 10 : 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(_isTablet ? 10 : 8),
            ),
            child: Icon(icon, color: color, size: _isTablet ? 20 : 18),
          ),
          SizedBox(height: _isTablet ? 16 : 12),
          Text(
            value,
            style: TextStyle(
              color: const Color(0xFF0F172A),
              fontSize: _isTablet ? 28 : 24,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: const Color(0xFF64748B),
              fontSize: _isTablet ? 13 : 12,
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
        padding: EdgeInsets.symmetric(
          horizontal: _isTablet ? 32 : 20,
          vertical: _isTablet ? 16 : 12,
        ),
        child: Container(
          height: _isTablet ? 52 : 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_isTablet ? 12 : 10),
            border: Border.all(
              color: const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          padding: EdgeInsets.all(_isTablet ? 5 : 4),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            padding: EdgeInsets.zero,
            labelPadding: EdgeInsets.symmetric(
              horizontal: _isTablet ? 20 : 16,
            ),
            indicator: BoxDecoration(
              color: const Color(0xFF1E40AF),
              borderRadius: BorderRadius.circular(_isTablet ? 8 : 7),
            ),
            labelColor: Colors.white,
            unselectedLabelColor: const Color(0xFF64748B),
            labelStyle: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: _isTablet ? 14 : 13,
            ),
            unselectedLabelStyle: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: _isTablet ? 14 : 13,
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
                          SizedBox(width: _isTablet ? 8 : 6),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: _isTablet ? 8 : 6,
                              vertical: _isTablet ? 4 : 2,
                            ),
                            decoration: BoxDecoration(
                              color: _tabController.index == _tabs.indexOf(tab)
                                  ? Colors.white.withOpacity(0.25)
                                  : _getStatusColor(tab.toLowerCase()).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(_isTablet ? 8 : 6),
                            ),
                            child: Text(
                              count.toString(),
                              style: TextStyle(
                                fontSize: _isTablet ? 11 : 10,
                                fontWeight: FontWeight.w700,
                                color: _tabController.index == _tabs.indexOf(tab)
                                    ? Colors.white
                                    : _getStatusColor(tab.toLowerCase()),
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
                  width: _isTablet ? 60 : 56,
                  height: _isTablet ? 60 : 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E40AF).withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(Color(0xFF1E40AF)),
                    strokeWidth: 2.5,
                  ),
                ),
                SizedBox(height: _isTablet ? 20 : 16),
                Text(
                  'Loading orders',
                  style: TextStyle(
                    color: const Color(0xFF64748B),
                    fontSize: _isTablet ? 15 : 14,
                    fontWeight: FontWeight.w500,
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
                  padding: EdgeInsets.all(_isTablet ? 18 : 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFDC2626),
                    size: 28,
                  ),
                ),
                SizedBox(height: _isTablet ? 20 : 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    provider.error!,
                    style: TextStyle(
                      color: const Color(0xFF1F2937),
                      fontSize: _isTablet ? 15 : 14,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: _isTablet ? 24 : 20),
                ElevatedButton.icon(
                  onPressed: _loadOrders,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E40AF),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: _isTablet ? 28 : 24,
                      vertical: _isTablet ? 12 : 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_isTablet ? 9 : 8),
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
                  padding: EdgeInsets.all(_isTablet ? 24 : 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.shopping_bag_outlined,
                    size: _isTablet ? 60 : 56,
                    color: const Color(0xFFCBD5E1),
                  ),
                ),
                SizedBox(height: _isTablet ? 20 : 16),
                Text(
                  'No ${tab.toLowerCase()} orders',
                  style: TextStyle(
                    fontSize: _isTablet ? 17 : 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Check back later for new orders',
                  style: TextStyle(
                    fontSize: _isTablet ? 13 : 12,
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
          child: _isLargeTablet
              ? _buildGridView(orders)
              : _buildListView(orders),
        );
      },
    );
  }

  Widget _buildListView(List<Map<String, dynamic>> orders) {
    return ListView.separated(
      padding: EdgeInsets.all(_isTablet ? 24 : 16),
      itemCount: orders.length,
      separatorBuilder: (_, __) => SizedBox(height: _isTablet ? 12 : 10),
      itemBuilder: (context, index) => _buildOrderCard(orders[index]),
    );
  }

  Widget _buildGridView(List<Map<String, dynamic>> orders) {
    return GridView.builder(
      padding: const EdgeInsets.all(32),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.4,
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

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_isTablet ? 12 : 10),
        border: Border.all(
          color: isUrgent 
              ? const Color(0xFFDC2626).withOpacity(0.25)
              : const Color(0xFFE2E8F0),
          width: isUrgent ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isUrgent 
                ? const Color(0xFFDC2626).withOpacity(0.04)
                : Colors.black.withOpacity(0.02),
            blurRadius: _isTablet ? 8 : 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToOrderDetails(order['_id']),
          borderRadius: BorderRadius.circular(_isTablet ? 12 : 10),
          child: Padding(
            padding: EdgeInsets.all(_isTablet ? 16 : 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: _isTablet ? 12 : 10,
                        vertical: _isTablet ? 6 : 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(_isTablet ? 6 : 5),
                      ),
                      child: Text(
                        order['orderNumber'] ?? 'N/A',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: _isTablet ? 12 : 11,
                        ),
                      ),
                    ),
                    if (isUrgent) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: _isTablet ? 9 : 7,
                          vertical: _isTablet ? 5 : 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(_isTablet ? 6 : 5),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.priority_high,
                              size: 12,
                              color: Color(0xFFDC2626),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'URGENT',
                              style: TextStyle(
                                color: const Color(0xFFDC2626),
                                fontSize: _isTablet ? 10 : 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      _formatTime(DateTime.parse(order['createdAt'])),
                      style: TextStyle(
                        color: const Color(0xFF94A3B8),
                        fontSize: _isTablet ? 11 : 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            order['userId']?['firstName'] ?? 'Customer',
                            style: TextStyle(
                              fontSize: _isTablet ? 15 : 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: _isTablet ? 5 : 3),
                          Row(
                            children: [
                              Icon(
                                order['deliveryType'] == 'delivery'
                                    ? Icons.delivery_dining_rounded
                                    : Icons.shopping_bag_rounded,
                                size: _isTablet ? 12 : 11,
                                color: const Color(0xFF94A3B8),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                (order['deliveryType'] ?? 'pickup').toUpperCase(),
                                style: TextStyle(
                                  fontSize: _isTablet ? 10 : 9,
                                  color: const Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: _isTablet ? 16 : 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '\$${(order['total'] ?? 0).toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: _isTablet ? 18 : 16,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_isTablet ? 14 : 12),
        ),
        backgroundColor: Colors.white,
        title: Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: _isTablet ? 20 : 18,
            color: const Color(0xFF0F172A),
          ),
        ),
        content: Consumer<OrderProvider>(
          builder: (context, provider, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: _isTablet ? 16 : 12,
                        vertical: _isTablet ? 8 : 6,
                      ),
                      title: Text(
                        'Auto-Print Orders',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: _isTablet ? 15 : 14,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      subtitle: Text(
                        'Print new orders automatically',
                        style: TextStyle(
                          fontSize: _isTablet ? 12 : 11,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      value: provider.autoPrintEnabled,
                      onChanged: (value) => provider.toggleAutoPrint(value),
                      activeColor: const Color(0xFF1E40AF),
                      inactiveTrackColor: const Color(0xFFE2E8F0),
                    ),
                    Divider(
                      height: 1,
                      color: const Color(0xFFE2E8F0),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: _isTablet ? 16 : 12,
                        vertical: _isTablet ? 8 : 6,
                      ),
                      title: Text(
                        'Auto-Accept Orders',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: _isTablet ? 15 : 14,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      subtitle: Text(
                        'Confirm new orders automatically',
                        style: TextStyle(
                          fontSize: _isTablet ? 12 : 11,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      value: provider.autoAcceptEnabled,
                      onChanged: (value) => provider.toggleAutoAccept(value),
                      activeColor: const Color(0xFF1E40AF),
                      inactiveTrackColor: const Color(0xFFE2E8F0),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(
                horizontal: _isTablet ? 20 : 16,
                vertical: _isTablet ? 10 : 8,
              ),
            ),
            child: Text(
              'Close',
              style: TextStyle(
                fontSize: _isTablet ? 15 : 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E40AF),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'all':
        return const Color(0xFF1E40AF);
      case 'pending':
        return const Color(0xFFB45309);
      case 'confirmed':
        return const Color(0xFF1E40AF);
      case 'preparing':
        return const Color(0xFF6D28D9);
      case 'ready':
        return const Color(0xFF047857);
      case 'completed':
        return const Color(0xFF065F46);
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
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${dateTime.day}/${dateTime.month}';
  }
}