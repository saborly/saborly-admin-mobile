import 'dart:async';

import 'package:saborlyadmin/models/order.dart';

class OrderStreamService {
  static final OrderStreamService instance = OrderStreamService._();
  OrderStreamService._();

  final _orderController = StreamController<OrderNotification>.broadcast();
  Stream<OrderNotification> get orderStream => _orderController.stream;

  void addNewOrder(OrderNotification order) {
    _orderController.add(order);
  }

  void dispose() {
    _orderController.close();
  }
}