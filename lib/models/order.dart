class OrderNotification {
  final String orderId;
  final String orderNumber;
  final String customerName;
  final double total;
  final String deliveryType;
  final DateTime createdAt;
  final String status;
  final bool isUrgent;

  OrderNotification({
    required this.orderId,
    required this.orderNumber,
    required this.customerName,
    required this.total,
    required this.deliveryType,
    required this.createdAt,
    required this.status,
    this.isUrgent = false,
  });

  factory OrderNotification.fromJson(Map<String, dynamic> json) {
    return OrderNotification(
      orderId: json['_id'] ?? json['orderId'] ?? '',
      orderNumber: json['orderNumber'] ?? '',
      customerName: json['userId']?['fullName'] ?? json['customerName'] ?? '',
      total: json['total'] is String
          ? double.tryParse(json['total'] as String) ?? 0.0
          : (json['total'] as num?)?.toDouble() ?? 0.0,
      deliveryType: json['deliveryType'] ?? 'delivery',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      status: json['status'] ?? 'pending',
      isUrgent: json['isUrgent'] ?? false,
    );
  }
}