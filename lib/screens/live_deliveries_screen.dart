import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:Saborly_admin/screens/add_driver_screen.dart';
import 'package:Saborly_admin/screens/order_details_screen.dart';
import 'package:Saborly_admin/services/api_service.dart';
import 'package:Saborly_admin/services/order_provider.dart';
import 'package:Saborly_admin/services/tracking_socket_service.dart';
import 'package:Saborly_admin/theme/app_colors.dart';

/// Branch-wide map of active deliveries — admin/staff can monitor every
/// driver currently assigned to an order for their branch in real time.
/// Hydrated once via REST (GET /drivers/active-deliveries), then kept live
/// via the `branch:active_deliveries_update` socket broadcast.
class LiveDeliveriesScreen extends StatefulWidget {
  const LiveDeliveriesScreen({super.key});

  @override
  State<LiveDeliveriesScreen> createState() => _LiveDeliveriesScreenState();
}

class _LiveDeliveriesScreenState extends State<LiveDeliveriesScreen> {
  GoogleMapController? _mapController;
  String? _selectedOrderId;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    setState(() => _isRefreshing = true);
    await context.read<OrderProvider>().loadActiveDeliveries();
    if (mounted) setState(() => _isRefreshing = false);
    _connectSocket();
  }

  void _connectSocket() {
    final token = ApiService.instance.authToken;
    final branchId = ApiService.instance.branchId;
    if (token == null || branchId == null) return;

    final socket = TrackingSocketService.instance;
    socket.connect(token);
    socket.onConnect((_) => socket.joinBranchDashboard(branchId));
    socket.on('branch:active_deliveries_update', (data) {
      if (data is Map && data['orders'] is List && mounted) {
        context.read<OrderProvider>().applyActiveDeliveriesUpdate(data['orders'] as List);
      }
    });
  }

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    await context.read<OrderProvider>().loadActiveDeliveries();
    if (mounted) setState(() => _isRefreshing = false);
  }

  @override
  void dispose() {
    final socket = TrackingSocketService.instance;
    socket.off('branch:active_deliveries_update');
    socket.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OrderProvider>();
    final deliveries = provider.activeDeliveries;
    final liveCount = deliveries.where((o) => (o['deliveryTracking'] as Map?)?['isLive'] == true).length;

    final markers = <Marker>{};
    for (final order in deliveries) {
      final tracking = order['deliveryTracking'] as Map<String, dynamic>?;
      final location = tracking?['currentLocation'] as Map<String, dynamic>?;
      final lat = (location?['latitude'] as num?)?.toDouble();
      final lng = (location?['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;

      final id = (order['id'] ?? '').toString();
      final driver = order['driver'] as Map<String, dynamic>?;
      markers.add(Marker(
        markerId: MarkerId(id),
        position: LatLng(lat, lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          id == _selectedOrderId ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueViolet,
        ),
        infoWindow: InfoWindow(
          title: '#${order['orderNumber']}',
          snippet: driver != null ? '${driver['firstName'] ?? ''} ${driver['lastName'] ?? ''}'.trim() : null,
          onTap: () => _openOrder(id),
        ),
        onTap: () => setState(() => _selectedOrderId = id),
      ));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(deliveries.length, liveCount),
            Expanded(
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: const CameraPosition(target: LatLng(41.4036344, 2.1986439), zoom: 12),
                    markers: markers,
                    zoomControlsEnabled: false,
                    onMapCreated: (c) => _mapController = c,
                  ),
                  if (deliveries.isNotEmpty && markers.isEmpty)
                    Positioned(
                      top: 12,
                      left: 12,
                      right: 12,
                      child: _buildInfoBanner(),
                    ),
                ],
              ),
            ),
            deliveries.isEmpty ? _buildEmptyState() : _buildList(deliveries),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(int total, int liveCount) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.map_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Live Deliveries', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                Text(
                  total == 0 ? 'Nothing active right now' : '$total active · $liveCount live',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.textMedium),
            tooltip: 'Add driver',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddDriverScreen()),
            ),
          ),
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  )
                : const Icon(Icons.refresh_rounded, color: AppColors.textMedium),
            onPressed: _isRefreshing ? null : _refresh,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 10, offset: Offset(0, 3))],
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF94A3B8)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'No driver locations yet — they appear once a driver starts sharing GPS',
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.primary.withOpacity(0.08), AppColors.secondary.withOpacity(0.08)]),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.local_shipping_outlined, color: AppColors.primary, size: 26),
          ),
          const SizedBox(height: 12),
          Text('No active deliveries', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: const Color(0xFF0F172A))),
          const SizedBox(height: 4),
          Text(
            'Assigned drivers will show up here once they start delivering',
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> deliveries) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(top: 4),
      child: SizedBox(
        height: 140,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
          itemCount: deliveries.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final order = deliveries[index];
            final id = (order['id'] ?? '').toString();
            final driver = order['driver'] as Map<String, dynamic>?;
            final customer = order['customer'] as Map<String, dynamic>?;
            final customerName =
                customer != null ? '${customer['firstName'] ?? ''} ${customer['lastName'] ?? ''}'.trim() : '';
            final isLive = (order['deliveryTracking'] as Map<String, dynamic>?)?['isLive'] == true;
            final isSelected = id == _selectedOrderId;

            return GestureDetector(
              onTap: () {
                setState(() => _selectedOrderId = id);
                _focusOrder(order);
              },
              onDoubleTap: () => _openOrder(id),
              child: Container(
                width: 210,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary.withOpacity(0.05) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : const Color(0xFFE8ECF0),
                    width: isSelected ? 1.6 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('#${order['orderNumber']}',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 11, color: AppColors.primary)),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: isLive ? const Color(0xFFE6FAF3) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isLive ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(isLive ? 'Live' : 'Idle',
                                  style: GoogleFonts.inter(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: isLive ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                                  )),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFEDE7F6)),
                          alignment: Alignment.center,
                          child: const Icon(Icons.two_wheeler_rounded, size: 14, color: AppColors.primary),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            driver != null ? '${driver['firstName'] ?? ''} ${driver['lastName'] ?? ''}'.trim() : 'Unassigned',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      customerName.isNotEmpty ? 'For $customerName' : '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                    ),
                    const Spacer(),
                    Text(
                      _statusLabel((order['status'] ?? '').toString()),
                      style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.secondary, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'ready':
        return 'Awaiting pickup';
      case 'driverpickup':
      case 'pickup':
        return 'Picked up';
      case 'out-for-delivery':
        return 'Out for delivery';
      default:
        return status;
    }
  }

  void _focusOrder(Map<String, dynamic> order) {
    final location = (order['deliveryTracking'] as Map<String, dynamic>?)?['currentLocation'] as Map<String, dynamic>?;
    final lat = (location?['latitude'] as num?)?.toDouble();
    final lng = (location?['longitude'] as num?)?.toDouble();
    if (lat != null && lng != null) {
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(lat, lng), 15));
    }
  }

  void _openOrder(String orderId) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailsScreen(orderId: orderId)));
  }
}
