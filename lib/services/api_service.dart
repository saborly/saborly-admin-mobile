import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static final ApiService instance = ApiService._internal();
  factory ApiService() => instance;

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.saborly.es/api/v1',
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
      },
    ),
  );

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  String? _authToken;
  String? _branchId;

  // lib/services/api_service.dart

  ApiService._internal() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // ONLY attach if not null and not empty
        if (_authToken != null && _authToken!.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $_authToken';
        }

        // ONLY attach branch ID for non-public routes
        if (_branchId != null &&
            _branchId!.isNotEmpty &&
            !options.path.contains('public')) {
          options.headers['X-Branch-Id'] = _branchId;
        }

        print('🌐 Request: ${options.method} ${options.path}');
        return handler.next(options);
      },
      onError: (DioException e, handler) {
        print('❌ API Error: ${e.response?.statusCode} - ${e.message}');
        print('❌ Response Data: ${e.response?.data}');
        return handler.next(e);
      },
    ));
  }

  // Initialize from storage
  Future<void> initialize() async {
    _authToken = await _storage.read(key: 'auth_token');
    _branchId = await _storage.read(key: 'branch_id');
  }

  void setAuthToken(String? token) {
    _authToken = token;
    if (token != null) {
      _storage.write(key: 'auth_token', value: token);
    } else {
      _storage.delete(key: 'auth_token');
    }
  }

// Change 'void' to 'Future<void>' and add 'async'
  Future<void> setBranchId(String? id) async {
    _branchId = id;
    if (id != null) {
      await _storage.write(key: 'branch_id', value: id);
    } else {
      await _storage.delete(key: 'branch_id');
    }
  }

  String? get authToken => _authToken;
  String? get branchId => _branchId;

  // ==================== AUTH ENDPOINTS ====================

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    required String branchId,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {
          'email': email,
          'password': password,
          'branchId': branchId,
        },
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
// lib/services/api_service.dart

// Add this alongside your other methods:
  Future<Map<String, dynamic>> getBranches() async {
    try {
      final response = await _dio.get('/branches');
      if (response.data is List) {
        return {'branches': response.data};
      }
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

// Also updating getPublicBranches to return a Map for consistency
// Change return type to Future<Map<String, dynamic>>
  Future<Map<String, dynamic>> getPublicBranches() async {
    try {
      final response = await _dio.get('/branches/public');
      if (response.data is List) {
        return {'branches': response.data};
      }
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await _dio.get('/auth/profile');
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
    } finally {
      setAuthToken(null);
      setBranchId(null);
      await _storage.deleteAll();
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

  Future<Map<String, dynamic>> getOrderDetails(String orderId) async {
    try {
      final response = await _dio.get('/orders/$orderId');
      if (response.data is Map && response.data['order'] != null) {
        return response.data['order'];
      }
      return response.data as Map<String, dynamic>;
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
          if (status != null && status != 'all') 'status': status,
          'page': page,
          'limit': limit,
          'sort': '-createdAt',
        },
      );
      if (response.data is List) {
        return response.data;
      }
      if (response.data is Map && response.data['orders'] != null) {
        return response.data['orders'];
      }
      return [];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

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
      if (response.data is Map && response.data['stats'] != null) {
        return response.data['stats'];
      }
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ==================== ERROR HANDLER ====================

  String _handleError(DioException error) {
    if (error.response != null) {
      final data = error.response?.data;
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
