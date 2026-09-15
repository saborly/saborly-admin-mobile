import 'package:socket_io_client/socket_io_client.dart' as io;

typedef SocketEventHandler = void Function(dynamic data);

/// Thin Socket.IO wrapper for the admin app's Live Deliveries dashboard.
/// Same factory-singleton idiom as ApiService — connects with the staff
/// JWT and joins the branch dashboard room for batched active-delivery
/// updates (see sockets/orderTrackingHandlers.js on the backend).
class TrackingSocketService {
  static final TrackingSocketService instance = TrackingSocketService._internal();
  factory TrackingSocketService() => instance;
  TrackingSocketService._internal();

  // Same host as ApiService's baseUrl, without the /api/v1 REST prefix.
  static const String _socketUrl = 'https://api.saborly.es';

  io.Socket? _socket;

  bool get isConnected => _socket?.connected ?? false;

  void connect(String authToken) {
    disconnect();

    _socket = io.io(
      _socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': authToken})
          .build(),
    );
    _socket!.connect();
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  void on(String event, SocketEventHandler handler) => _socket?.on(event, handler);
  void off(String event) => _socket?.off(event);
  void onConnect(SocketEventHandler handler) => _socket?.onConnect(handler);
  void onConnectError(SocketEventHandler handler) => _socket?.onConnectError(handler);

  void joinBranchDashboard(String branchId) => _socket?.emit('join_branch_dashboard', {'branchId': branchId});
  void joinOrderTracking(String orderId) => _socket?.emit('join_order_tracking', {'orderId': orderId});
  void leaveOrderTracking(String orderId) => _socket?.emit('leave_order_tracking', {'orderId': orderId});
}
