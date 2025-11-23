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
    // Extract customer name from userId object
    String customerName = 'Unknown Customer';
    if (json['userId'] != null && json['userId'] is Map) {
      final userId = json['userId'] as Map<String, dynamic>;
      final firstName = userId['firstName'] ?? '';
      final lastName = userId['lastName'] ?? '';
      customerName = '$firstName $lastName'.trim();
      if (customerName.isEmpty) {
        customerName = 'Unknown Customer';
      }
    } else if (json['customerName'] != null) {
      customerName = json['customerName'] as String;
    }

    return OrderNotification(
      orderId: json['_id'] ?? json['orderId'] ?? '',
      orderNumber: json['orderNumber'] ?? '',
      customerName: customerName,
      total: json['total'] is String
          ? double.tryParse(json['total'] as String) ?? 0.0
          : (json['total'] as num?)?.toDouble() ?? 0.0,
      deliveryType: json['deliveryType'] ?? 'pickup',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      status: json['status'] ?? 'pending',
      isUrgent: json['isUrgent'] ?? false,
    );
  }

  // Helper method to convert to map for storage or transmission
  Map<String, dynamic> toJson() {
    return {
      '_id': orderId,
      'orderNumber': orderNumber,
      'customerName': customerName,
      'total': total,
      'deliveryType': deliveryType,
      'createdAt': createdAt.toIso8601String(),
      'status': status,
      'isUrgent': isUrgent,
    };
  }

  // Helper to get delivery type icon
  String get deliveryTypeIcon {
    switch (deliveryType.toLowerCase()) {
      case 'delivery':
        return '🚚';
      case 'pickup':
        return '🛍️';
      default:
        return '📦';
    }
  }

  // Helper to get delivery type display text
  String get deliveryTypeDisplay {
    switch (deliveryType.toLowerCase()) {
      case 'delivery':
        return 'Delivery';
      case 'pickup':
        return 'Pickup';
      default:
        return deliveryType;
    }
  }

  // Helper to check if order is recent (within last 5 minutes)
  bool get isRecent {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    return difference.inMinutes < 5;
  }

  // Helper to get formatted time ago
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  @override
  String toString() {
    return 'OrderNotification(orderNumber: $orderNumber, customer: $customerName, total: \$$total, type: $deliveryType)';
  }
}