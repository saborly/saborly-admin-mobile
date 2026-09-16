import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:Saborly_admin/firebase_options.dart';
import 'package:Saborly_admin/screens/auth.dart';
import 'package:Saborly_admin/screens/main_shell.dart';
import 'package:Saborly_admin/services/api_service.dart';
import 'package:Saborly_admin/services/firebase_messaging_service.dart';
import 'package:Saborly_admin/services/order_provider.dart';
import 'package:Saborly_admin/providers/auth_provider.dart';
import 'package:Saborly_admin/theme/app_colors.dart';
import 'package:Saborly_admin/theme/app_theme.dart';

// Global navigator key so services (e.g. notification tap handling) can
// push routes without a BuildContext from the active widget tree.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // CRITICAL: Register background message handler BEFORE initializing messaging service
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  
  // Initialize Firebase Messaging
  await FirebaseMessagingService.initialize();
  
  // Initialize API Service
  await ApiService.instance.initialize();
  
  // Get and save FCM token
  await _initializeFCMToken();
  
  runApp(const MyApp());
}

Future<void> _initializeFCMToken() async {
  try {
    // Get current FCM token
    final fcmToken = await FirebaseMessagingService.getToken();
    
    if (fcmToken == null) {
      print('❌ Failed to get FCM token');
      return;
    }
    
    print('📱 Current FCM Token: $fcmToken');
    
    // Get stored token
    final prefs = await SharedPreferences.getInstance();
    final authToken = prefs.getString('auth_token');

    await prefs.setString('fcm_token', fcmToken);
    
    // If user is logged in, update token on backend
    if (authToken != null) {
      try {
        print('🔄 User is logged in, updating FCM token on backend...');
        
        await ApiService.instance.updateFCMToken(
          fcmToken: fcmToken,
          platform: 'android',
        );
        
        print('✅ FCM token saved to backend');
      } catch (e) {
        print('❌ Error saving FCM token: $e');
      }
    } else {
      print('ℹ️ User not logged in, token will be saved after login');
    }
    
    // Listen for token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      print('🔄 FCM Token refreshed: $newToken');
      
      // Save new token locally
      await prefs.setString('fcm_token', newToken);
      
      // Update on backend if logged in
      final currentAuthToken = prefs.getString('auth_token');
      if (currentAuthToken != null) {
        try {
          await ApiService.instance.updateFCMToken(
            fcmToken: newToken,
            platform: 'android',
          );
          print('✅ New FCM token updated on backend');
        } catch (e) {
          print('❌ Error updating refreshed FCM token: $e');
        }
      }
    });
    
  } catch (e) {
    print('❌ Error initializing FCM token: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Saborly Admin',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const SplashScreen(),
      ),
    );
  }
}

// Splash Screen to check authentication
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();

    try {
      await authProvider.initialize().timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Auth init error/timeout: $e');
    }

    if (!mounted) return;

    if (authProvider.isAuthenticated && authProvider.selectedBranch != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Container(
        color: AppColors.surface,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 24),
              Text(
                'Saborly Admin',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Order Management Console',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textMedium,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 40),
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}