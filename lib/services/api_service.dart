import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static final ApiService instance = ApiService._internal();
  factory ApiService() => instance;
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://saborly-backend.vercel.app/api/v1',
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
      },
    ),
  );

  String? _authToken;

  ApiService._internal() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final bid = prefs.getString('branch_id');
        if (bid != null && bid.isNotEmpty) {
          options.headers['X-Branch-Id'] = bid;
        }
        handler.next(options);
      },
    ));
  }

  // Initialize token from storage
  Future<void> initToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token != null) {
      setAuthToken(token);
    }
  }

  void setAuthToken(String token) {
    _authToken = token;
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  Future<void> setBranchId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('branch_id', id);
  }

  Future<void> clearBranchId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('branch_id');
  }

  // ==================== AUTH ENDPOINTS ====================

  // Login
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {
          'email': email,
          'password': password,
        },
      );

      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getPublicBranches() async {
    try {
      final response = await _dio.get('/branches/public');
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getBranches() async {
    try {
      final response = await _dio.get('/branches');
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Get Profile
  Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await _dio.get('/auth/profile');
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
      
      // Clear local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('branch_id');
      await prefs.remove('user_id');
      await prefs.remove('user_name');
      await prefs.remove('user_email');
      await prefs.remove('user_role');
      
      _authToken = null;
      _dio.options.headers.remove('Authorization');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Update FCM Token
  Future<Map<String, dynamic>> updateFCMToken({
    required String fcmToken,
    String? deviceId,
    String platform = 'android',
  }) async {
    try {
      final response = await _dio.post(
        '/auth/fcm-token',
        data: {
          'fcmToken': fcmToken,
          'deviceId': deviceId ?? 'admin_device',
          'platform': platform,
        },
      );

      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ==================== ORDER ENDPOINTS ====================

  // Get Order Details
  Future<Map<String, dynamic>> getOrderDetails(String orderId) async {
    try {
      final response = await _dio.get('/orders/$orderId');
      return response.data['order'];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

 Future<List<dynamic>> getAllOrders({
  String? status,
  int page = 1,
  int limit = 20,
}) async {
  try {
    final response = await _dio.get(
      '/orders/getall',
      queryParameters: {
        if (status != null && status != 'all') 'status': status,
        'page': page,
        'limit': limit,
      },
    );
    return response.data['orders'] as List<dynamic>;
  } on DioException catch (e) {
    throw _handleError(e);
  }
}
  // Update Order Status
  Future<Map<String, dynamic>> updateOrderStatus({
    required String orderId,
    required String status,
    String? message,
  }) async {
    try {
      final response = await _dio.patch(
        '/orders/$orderId/status',
        data: {
          'status': status,
          if (message != null) 'message': message,
        },
      );

      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Cancel Order
  Future<Map<String, dynamic>> cancelOrder({
    required String orderId,
    required String reason,
  }) async {
    try {
      final response = await _dio.patch(
        '/orders/$orderId/cancel',
        data: {
          'reason': reason,
        },
      );

      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Get Order Statistics
  Future<Map<String, dynamic>> getOrderStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final response = await _dio.get(
        '/orders/stats',
        queryParameters: {
          if (startDate != null) 'startDate': startDate.toIso8601String(),
          if (endDate != null) 'endDate': endDate.toIso8601String(),
        },
      );

      return response.data['stats'];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<dynamic>> getOrders({
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _dio.get(
     '/orders/getall',
        queryParameters: {
          if (status != null) 'status': status,
          'page': page,
          'limit': limit,
          'sort': '-createdAt',
        },
      );

      return response.data['orders'];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ==================== ERROR HANDLER ====================

  String _handleError(DioException error) {
    if (error.response != null) {
      final data = error.response?.data;
      
      // Handle different error formats
      if (data is Map<String, dynamic>) {
        return data['message'] ?? 'An error occurred';
      }
      
      return 'An error occurred';
    } else if (error.type == DioExceptionType.connectionTimeout) {
      return 'Connection timeout. Please check your internet connection.';
    } else if (error.type == DioExceptionType.receiveTimeout) {
      return 'Receive timeout. Server is taking too long to respond.';
    } else if (error.type == DioExceptionType.connectionError) {
      return 'Connection error. Please check your internet connection.';
    } else {
      return 'Network error. Please try again.';
    }
  }
}