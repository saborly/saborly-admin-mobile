import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:Saborly_admin/screens/order_details_screen.dart';
import 'package:Saborly_admin/services/api_service.dart';
import 'package:Saborly_admin/services/order_provider.dart';
import 'package:Saborly_admin/services/tracking_socket_service.dart';

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
  static const Color _brandPrimary = Color(0xFF4A148C);

  GoogleMapController? _mapController;
  String? _selectedOrderId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    await context.read<OrderProvider>().loadActiveDeliveries();
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
      appBar: AppBar(
        title: const Text('Live Deliveries'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => context.read<OrderProvider>().loadActiveDeliveries(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(target: LatLng(41.4036344, 2.1986439), zoom: 12),
              markers: markers,
              zoomControlsEnabled: false,
              onMapCreated: (c) => _mapController = c,
            ),
          ),
          _buildList(deliveries),
        ],
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> deliveries) {
    if (deliveries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        alignment: Alignment.center,
        child: const Text('No active deliveries right now', style: TextStyle(color: Color(0xFF64748B))),
      );
    }

    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(12),
        itemCount: deliveries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final order = deliveries[index];
          final id = (order['id'] ?? '').toString();
          final driver = order['driver'] as Map<String, dynamic>?;
          final customer = order['customer'] as Map<String, dynamic>?;
          final isLive = (order['deliveryTracking'] as Map<String, dynamic>?)?['isLive'] == true;

          return GestureDetector(
            onTap: () {
              setState(() => _selectedOrderId = id);
              _focusOrder(order);
            },
            onDoubleTap: () => _openOrder(id),
            child: Container(
              width: 200,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: id == _selectedOrderId ? _brandPrimary : const Color(0xFFE2E8F0),
                  width: id == _selectedOrderId ? 1.6 : 1,
                ),
                boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 3))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('#${order['orderNumber']}',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isLive ? Colors.green : Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    driver != null ? '${driver['firstName'] ?? ''} ${driver['lastName'] ?? ''}'.trim() : 'Unassigned',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    customer != null ? '${customer['firstName'] ?? ''} ${customer['lastName'] ?? ''}'.trim() : '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                  const Spacer(),
                  Text(
                    (order['status'] ?? '').toString(),
                    style: const TextStyle(fontSize: 10, color: _brandPrimary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
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
