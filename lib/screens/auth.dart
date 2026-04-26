import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:Saborly_admin/services/api_service.dart';
import 'package:Saborly_admin/screens/orders_dashboard_screen.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({Key? key}) : super(key: key);

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  bool _loadingBranches = true;
  List<dynamic> _publicBranches = [];
  String? _selectedBranchId;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  static const _adminRoles = {
    'admin',
    'manager',
    'superadmin',
    'super_admin',
    'branch_admin',
    'staff',
  };

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
    
    _checkLoginStatus();
    _loadPublicBranches();
  }

  String _branchIdOf(Map<String, dynamic> b) {
    final id = b['_id'];
    return id?.toString() ?? '';
  }

  /// Prefer Sabadell, then Barcelona, then first (matches admin web).
  String? _pickPreferredBranchId(List<dynamic> list) {
    if (list.isEmpty) return null;
    for (final e in list) {
      if (e is! Map) continue;
      final b = Map<String, dynamic>.from(e);
      final name = '${b['name'] ?? ''}'.toLowerCase();
      final loc = '${b['location'] ?? ''}'.toLowerCase();
      if (name.contains('sabadell') || loc.contains('sabadell')) {
        final id = _branchIdOf(b);
        if (id.isNotEmpty) return id;
      }
    }
    for (final e in list) {
      if (e is! Map) continue;
      final b = Map<String, dynamic>.from(e);
      final name = '${b['name'] ?? ''}'.toLowerCase();
      final loc = '${b['location'] ?? ''}'.toLowerCase();
      if (name.contains('barcelona') || loc.contains('barcelona')) {
        final id = _branchIdOf(b);
        if (id.isNotEmpty) return id;
      }
    }
    final first = list.first;
    if (first is! Map) return null;
    final id = _branchIdOf(Map<String, dynamic>.from(first));
    return id.isEmpty ? null : id;
  }

  Future<void> _loadPublicBranches() async {
    setState(() => _loadingBranches = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('branch_id');
      final res = await ApiService.instance.getPublicBranches();
      final list = (res['branches'] as List?) ?? [];

      String? selected = saved;
      if (selected != null && selected.isNotEmpty) {
        final ok = list.any((e) => e is Map && _branchIdOf(Map<String, dynamic>.from(e)) == selected);
        if (!ok) selected = null;
      }
      final firstBranch = list.isNotEmpty ? list.first : null;
      if (selected == null && list.length == 1 && firstBranch is Map) {
        selected = _branchIdOf(Map<String, dynamic>.from(firstBranch));
      }
      selected ??= _pickPreferredBranchId(list);

      if (selected != null && selected.isNotEmpty) {
        await ApiService.instance.setBranchId(selected);
      }

      if (!mounted) return;
      setState(() {
        _publicBranches = list;
        _selectedBranchId = selected;
        _loadingBranches = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingBranches = false;
        _errorMessage = 'Could not load branches. Check your connection.';
      });
    }
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final branchId = prefs.getString('branch_id');
    
    if (token != null) {
      if (branchId == null || branchId.isEmpty) {
        await prefs.remove('auth_token');
        return;
      }
      ApiService.instance.setAuthToken(token);
      
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const OrdersDashboardScreen()),
        );
      }
    }
  }

  Future<void> _updateFCMToken() async {
    try {
      // Get FCM token
      final fcmToken = await FirebaseMessaging.instance.getToken();
      
      if (fcmToken != null) {
        print('📱 Updating FCM token after login: $fcmToken');
        
        // Update FCM token on backend
        await ApiService.instance.updateFCMToken(
          fcmToken: fcmToken,
          platform: 'android', // Change to 'ios' or 'web' as needed
        );
        
        // Save token locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', fcmToken);
        
        print('✅ FCM token updated successfully after login');
      } else {
        print('⚠️ FCM token is null');
      }
    } catch (e) {
      print('❌ Error updating FCM token after login: $e');
      // Don't block login if FCM token update fails
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedBranchId == null || _selectedBranchId!.isEmpty) {
      setState(() {
        _errorMessage = 'Please select a branch.';
      });
      return;
    }
    await ApiService.instance.setBranchId(_selectedBranchId!);

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiService.instance.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (response['success'] == true) {
        final token = response['token'];
        final user = response['user'];
        final role = user['role']?.toString() ?? '';

        if (!_adminRoles.contains(role)) {
          setState(() {
            _errorMessage = 'Access denied. Admin or staff account required.';
            _isLoading = false;
          });
          return;
        }

        // Save token
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);
        await prefs.setString('user_id', user['id'].toString());
        await prefs.setString('user_name', '${user['firstName']} ${user['lastName']}');
        await prefs.setString('user_email', user['email']);
        await prefs.setString('user_role', role);

        final ub = user['branchId'];
        if (ub != null && ub.toString().isNotEmpty) {
          await ApiService.instance.setBranchId(ub.toString());
        }

        // Set token in API service
        ApiService.instance.setAuthToken(token);

        // 🔥 UPDATE FCM TOKEN AFTER LOGIN
        await _updateFCMToken();

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Text('Welcome back, ${user['firstName']}!'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );

          // Navigate to dashboard
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const OrdersDashboardScreen()),
          );
        }
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'Login failed';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        final msg = e is String ? e : e.toString();
        _errorMessage = msg.replaceFirst('Exception: ', '').trim();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo/Icon
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.admin_panel_settings,
                        size: 60,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Title
                    const Text(
                      'Admin Login',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Order Management System',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Login Card
                    Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Error Message
                              if (_errorMessage != null)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.red),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error, color: Colors.red, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _errorMessage!,
                                          style: const TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              if (_loadingBranches)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Center(child: CircularProgressIndicator()),
                                )
                              else if (_publicBranches.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Text(
                                    'No active branches available.',
                                    style: TextStyle(color: Colors.orange[800]),
                                  ),
                                )
                              else ...[
                                DropdownButtonFormField<String>(
                                  value: _selectedBranchId != null &&
                                          _publicBranches.any((e) =>
                                              e is Map &&
                                              _branchIdOf(Map<String, dynamic>.from(e)) ==
                                                  _selectedBranchId)
                                      ? _selectedBranchId
                                      : null,
                                  decoration: InputDecoration(
                                    labelText: 'Branch',
                                    prefixIcon: const Icon(Icons.store_outlined),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[50],
                                  ),
                                  items: _publicBranches.map((e) {
                                    if (e is! Map) return null;
                                    final b = Map<String, dynamic>.from(e);
                                    final id = _branchIdOf(b);
                                    if (id.isEmpty) return null;
                                    final name = b['name']?.toString() ?? id;
                                    return DropdownMenuItem<String>(
                                      value: id,
                                      child: Text(name),
                                    );
                                  }).whereType<DropdownMenuItem<String>>().toList(),
                                  onChanged: (v) {
                                    setState(() => _selectedBranchId = v);
                                    if (v != null) {
                                      ApiService.instance.setBranchId(v);
                                    }
                                  },
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                                  child: Text(
                                    'Super-admin and platform admin accounts work in any branch. '
                                    'Branch staff must use their assigned store.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),

                              // Email Field
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  labelText: 'Email',
                                  hintText: 'admin@example.com',
                                  prefixIcon: const Icon(Icons.email_outlined),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your email';
                                  }
                                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                    return 'Please enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Password Field
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _login(),
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  hintText: '••••••••',
                                  prefixIcon: const Icon(Icons.lock_outlined),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your password';
                                  }
                                  if (value.length < 6) {
                                    return 'Password must be at least 6 characters';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 24),

                              // Login Button
                              ElevatedButton(
                                onPressed: _isLoading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 2,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : const Text(
                                        'Login',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Footer
                    Text(
                      'Saborly Admin Panel v1.0',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}