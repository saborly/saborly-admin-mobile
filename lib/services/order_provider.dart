// providers/order_provider.dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:Saborly_admin/services/api_service.dart';
import 'package:Saborly_admin/services/order_print_service.dart';
import 'package:audioplayers/audioplayers.dart';

class OrderProvider with ChangeNotifier {
  List<Map<String, dynamic>> _orders = [];
  Map<String, int> _statusCounts = {};
  Map<String, List<Map<String, dynamic>>> _ordersByStatus = {};
  bool _isLoading = false;
  String? _error;
  
  bool _autoPrintEnabled = true;
  bool _autoAcceptEnabled = false;
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<Map<String, dynamic>> get orders => _orders;

  Map<String, int> get statusCounts => _statusCounts;

  Map<String, List<Map<String, dynamic>>> get ordersByStatus => _ordersByStatus;


  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get autoPrintEnabled => _autoPrintEnabled;
  bool get autoAcceptEnabled => _autoAcceptEnabled;

  List<Map<String, dynamic>> getOrdersByStatus(String status) {
    print('Status Counts: ${jsonEncode(statusCounts)}');
print('Orders by Status: ${jsonEncode(ordersByStatus)}');

    return _ordersByStatus[status] ?? [];
  }

  int getStatusCount(String status) {
    return _statusCounts[status] ?? 0;
  }

  void toggleAutoPrint(bool value) {
    _autoPrintEnabled = value;
    notifyListeners();
  }

  void toggleAutoAccept(bool value) {
    _autoAcceptEnabled = value;
    notifyListeners();
  }

  Future<void> loadOrders({String? status}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await ApiService.instance.getOrders(status: status);
      _orders = List<Map<String, dynamic>>.from(data);
      _organizeOrders();
      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error loading orders: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> loadOrderDetails(String orderId) async {
    try {
      return await ApiService.instance.getOrderDetails(orderId);
    } catch (e) {
      debugPrint('Error loading order details: $e');
      return null;
    }
  }

  Future<bool> updateOrderStatus(String orderId, String newStatus) async {
    try {
      await ApiService.instance.updateOrderStatus(
        orderId: orderId,
        status: newStatus,
      );

      final index = _orders.indexWhere((o) => o['_id'] == orderId);
      if (index != -1) {
        _orders[index]['status'] = newStatus;
        _organizeOrders();
        notifyListeners();
      }

      return true;
    } catch (e) {
      debugPrint('Error updating order status: $e');
      return false;
    }
  }

  // Enhanced addNewOrder with proper data handling
  Future<void> addNewOrder(Map<String, dynamic> order) async {
    debugPrint('📦 Received new order: ${order['orderNumber']}');
    
    // Check if order data is complete
    bool needsFullData = false;
    
    if (order['userId'] == null || order['userId'] is! Map) {
      debugPrint('⚠️ Incomplete userId data in notification');
      needsFullData = true;
    }
    
    if (order['items'] == null || 
        (order['items'] is List && (order['items'] as List).isEmpty)) {
      debugPrint('⚠️ Incomplete items data in notification');
      needsFullData = true;
    }

    // If data is incomplete, fetch full order details
    Map<String, dynamic> completeOrder = order;
    if (needsFullData && order['_id'] != null) {
      debugPrint('🔄 Fetching complete order data...');
      try {
        final fullOrder = await ApiService.instance.getOrderDetails(order['_id']);
        if (fullOrder != null) {
          completeOrder = fullOrder;
          debugPrint('✅ Got complete order data');
        } else {
          debugPrint('❌ Could not fetch complete order data');
        }
      } catch (e) {
        debugPrint('❌ Error fetching complete order: $e');
      }
    }

    _orders.insert(0, completeOrder);
    _organizeOrders();
    notifyListeners();

    // Play notification sound
    await _playNotificationSound();

    // Auto-print if enabled
    if (_autoPrintEnabled) {
      try {
        debugPrint('🖨️ Auto-printing order: ${completeOrder['orderNumber']}');
        await OrderPrintService.printOrder(completeOrder);
        debugPrint('✅ Auto-printed order: ${completeOrder['orderNumber']}');
      } catch (e) {
        debugPrint('❌ Auto-print failed: $e');
      }
    }

    // Auto-accept if enabled
    if (_autoAcceptEnabled && completeOrder['status'] == 'pending') {
      await Future.delayed(const Duration(seconds: 2));
      await updateOrderStatus(completeOrder['_id'], 'confirmed');
      debugPrint('✅ Auto-accepted order: ${completeOrder['orderNumber']}');
    }
  }

  void _organizeOrders() {
    _statusCounts = {};
    _ordersByStatus = {
      'pending': [],
      'confirmed': [],
      'preparing': [],
      'ready': [],
      'delivered':[],
      'completed': [],
      'cancelled': [],
    };

    for (var order in _orders) {
      final status = order['status'] as String;
      _statusCounts[status] = (_statusCounts[status] ?? 0) + 1;
      
      if (_ordersByStatus.containsKey(status)) {
        _ordersByStatus[status]!.add(order);
      }
    }
  }

  Future<void> _playNotificationSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/order_notification.mp3'));
      await _audioPlayer.setVolume(1.0);
    } catch (e) {
      debugPrint('Error playing sound: $e');
    }
  }

  Map<String, dynamic> getTodayStats() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    
    final todayOrders = _orders.where((order) {
      final createdAtStr = order['createdAt'] as String?;
      if (createdAtStr == null || createdAtStr.isEmpty) return false;
      
      try {
        final orderDate = DateTime.parse(createdAtStr);
        return orderDate.isAfter(todayStart) && orderDate.isBefore(todayEnd);
      } catch (e) {
        debugPrint('Error parsing date: $createdAtStr - $e');
        return false;
      }
    }).toList();

    double todayRevenue = 0;
    int completedToday = 0;
    int pendingCount = 0;
    int preparingCount = 0;
    int deliveredCount=0;
    for (var order in todayOrders) {
      final status = order['status'] as String?;
      final total = order['total'];
      
      if (status == 'delivered') {
        completedToday++;
        if (total != null) {
          todayRevenue += (total is num) ? total.toDouble() : 0.0;
        }
      }
      
      if (status == 'pending') {
        pendingCount++;
      } else if (status == 'preparing') {
        preparingCount++;
      }
      else if(status=='delivered'){
        deliveredCount++;
      }
    }

    return {
      'totalOrders': todayOrders.length,
      'completedOrders': completedToday,
      'revenue': todayRevenue,
      'pendingOrders': pendingCount,
      'preparingOrders': preparingCount,
      'deliveredCount':deliveredCount,
    };
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}