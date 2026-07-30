import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:Saborly_admin/services/api_service.dart';
import 'package:Saborly_admin/models/branch.dart';

class AuthProvider with ChangeNotifier {
  String? _token;
  Branch? _selectedBranch;
  bool _isLoading = false;
  String? _error;

  String? get token => _token;
  Branch? get selectedBranch => _selectedBranch;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _token != null;

  Future<void> initialize() async {
    await ApiService.instance.initialize();
    ApiService.instance.onUnauthorized = _handleUnauthorized;
    _token = ApiService.instance.authToken;
    final branchId = ApiService.instance.branchId;

    if (branchId != null) {
      // We might need to fetch branch details or just store the ID
      // For now, let's assume we fetch branches on login or initialization
      await loadBranches();
      if (_branches.isNotEmpty) {
        _selectedBranch = _branches.firstWhere(
          (b) => b.id == branchId,
          orElse: () => _branches.first,
        );
      }
    }
    notifyListeners();
  }

  List<Branch> _branches = [];
  List<Branch> get branches => _branches;

  Future<void> loadBranches() async {
    try {
      final data = await ApiService.instance.getPublicBranches();

      // Extract the 'branches' list from the map response
      final branchesList = (data['branches'] as List?) ?? [];

      _branches = branchesList.map((json) => Branch.fromJson(json)).toList();
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      print('Error loading branches: $_error');
      notifyListeners();
    }
  }

  void setSelectedBranch(Branch branch) {
    _selectedBranch = branch;
    ApiService.instance.setBranchId(branch.id);
    _updateFCMSubscription();
    notifyListeners();
  }

  Future<bool> login(String email, String password, String branchId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await ApiService.instance.login(
        email: email,
        password: password,
        branchId: branchId,
      );

      if (response['success'] == true) {
        _token = response['token'];
        ApiService.instance.setAuthToken(_token);

        // Find and set the selected branch
        _selectedBranch = _branches.firstWhere((b) => b.id == branchId);
        ApiService.instance.setBranchId(branchId);

        // Update FCM Token on backend
        try {
          final fcmToken = await FirebaseMessaging.instance.getToken();
          if (fcmToken != null) {
            await ApiService.instance.updateFCMToken(
              fcmToken: fcmToken,
              platform: 'android',
            );
            print('✅ FCM token registered on backend after login');
          }
        } catch (e) {
          print('❌ Error registering FCM token after login: $e');
        }

        await _updateFCMSubscription();

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = response['message'] ?? 'Login failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Called by ApiService when any request comes back 401 (session expired
  /// or invalid). Resets local auth state; navigation back to login is
  /// handled by the widget tree reacting to `isAuthenticated` becoming false.
  void _handleUnauthorized() {
    if (_token == null) return;
    _token = null;
    _selectedBranch = null;
    notifyListeners();
  }

  Future<void> logout() async {
    if (_selectedBranch != null) {
      await FirebaseMessaging.instance.unsubscribeFromTopic(
          'saborly-${_selectedBranch!.name.toLowerCase().replaceAll(' ', '-')}');
    }
    await ApiService.instance.logout();
    _token = null;
    _selectedBranch = null;
    notifyListeners();
  }

  String? _lastIdTopic;
  String? _lastNameTopic;

  Future<void> _updateFCMSubscription() async {
    if (_selectedBranch == null) return;

    try {
      // Unsubscribe from previous topics if they exist
      if (_lastIdTopic != null) {
        await FirebaseMessaging.instance.unsubscribeFromTopic(_lastIdTopic!);
        print('📤 Unsubscribed from FCM topic: $_lastIdTopic');
      }
      if (_lastNameTopic != null) {
        await FirebaseMessaging.instance.unsubscribeFromTopic(_lastNameTopic!);
        print('📤 Unsubscribed from FCM topic: $_lastNameTopic');
      }

      // 1. Subscribe to ID-based topics
      final sanitizedId = _selectedBranch!.id.replaceAll(RegExp(r'[^a-zA-Z0-9-_.~%]'), '');
      _lastIdTopic = 'branch-$sanitizedId';
      await FirebaseMessaging.instance.subscribeToTopic(_lastIdTopic!);
      print('✅ Subscribed: $_lastIdTopic');

      await FirebaseMessaging.instance.subscribeToTopic(sanitizedId);
      print('✅ Subscribed: $sanitizedId');

      final saborlyIdTopic = 'saborly-$sanitizedId';
      await FirebaseMessaging.instance.subscribeToTopic(saborlyIdTopic);
      print('✅ Subscribed: $saborlyIdTopic');

      // 2. Subscribe to Name-based topics
      final rawName = _selectedBranch!.name.toLowerCase();
      
      // Standard sanitization (collapsing dashes)
      String cleanName = rawName
          .replaceAll(RegExp(r'[^a-z0-9]'), '-')
          .replaceAll(RegExp(r'-+'), '-')
          .replaceAll(RegExp(r'^-+|-+$'), '');
      
      if (cleanName.isNotEmpty) {
        // Topic A: saborly-[sanitized-name]
        final topicA = 'saborly-$cleanName';
        await FirebaseMessaging.instance.subscribeToTopic(topicA);
        print('✅ Subscribed: $topicA');
        
        // Topic B: [sanitized-name] (No prefix)
        await FirebaseMessaging.instance.subscribeToTopic(cleanName);
        print('✅ Subscribed: $cleanName');

        // Topic C: If name contains "saborly", also subscribe without it
        if (cleanName.contains('saborly')) {
          final strippedName = cleanName
              .replaceAll('saborly', '')
              .replaceAll(RegExp(r'-+'), '-')
              .replaceAll(RegExp(r'^-+|-+$'), '');
          
          if (strippedName.isNotEmpty) {
            final topicC = 'saborly-$strippedName';
            await FirebaseMessaging.instance.subscribeToTopic(topicC);
            print('✅ Subscribed: $topicC');
            
            await FirebaseMessaging.instance.subscribeToTopic(strippedName);
            print('✅ Subscribed: $strippedName');
          }
        }
      }
    } catch (e) {
      print('❌ Failed to subscribe to FCM topics: $e');
    }
  }
}
