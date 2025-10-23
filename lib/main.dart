import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:Saborly_admin/firebase_options.dart';
import 'package:Saborly_admin/screens/auth.dart';
import 'package:Saborly_admin/screens/orders_dashboard_screen.dart';
import 'package:Saborly_admin/services/api_service.dart';
import 'package:Saborly_admin/services/firebase_messaging_service.dart';
import 'package:Saborly_admin/services/order_provider.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('📱 Background Message: ${message.data}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize Firebase Messaging
  await FirebaseMessagingService.initialize();
  
  // Initialize API Service token
  await ApiService.instance.initToken();
  
  // Register background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
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
    final storedToken = prefs.getString('fcm_token');
    final authToken = prefs.getString('auth_token');
    
    // Check if token has changed
    final tokenChanged = storedToken != fcmToken;
    
    if (tokenChanged) {
      print('🔄 FCM Token changed or new');
      print('📱 Old Token: $storedToken');
      print('📱 New Token: $fcmToken');
    }
    
    // Save token locally first
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
        ChangeNotifierProvider(create: (_) => OrderProvider()),
      ],
      child: MaterialApp(
        title: 'Saborly Admin',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.deepPurple,
          scaffoldBackgroundColor: const Color(0xFFF5F5F5),
          fontFamily: 'Poppins',
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF4A148C),
            brightness: Brightness.light,
          ),
          cardTheme: CardTheme(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          appBarTheme: const AppBarTheme(
            elevation: 0,
            centerTitle: true,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
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
    // Show splash for at least 2 seconds
    await Future.delayed(const Duration(seconds: 2));

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (mounted) {
      if (token != null) {
        // User is logged in
        ApiService.instance.setAuthToken(token);
        
        // Verify token is still valid
        try {
          await ApiService.instance.getProfile();
          
          // Re-sync FCM token after successful auth verification
          final fcmToken = prefs.getString('fcm_token');
          if (fcmToken != null) {
            try {
              print('🔄 Re-syncing FCM token with backend...');
              await ApiService.instance.updateFCMToken(
                fcmToken: fcmToken,
                platform: 'android',
              );
              print('✅ FCM token re-synced successfully');
            } catch (e) {
              print('❌ Error re-syncing FCM token: $e');
            }
          }
          
          // Token is valid, go to dashboard
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const OrdersDashboardScreen()),
          );
        } catch (e) {
          // Token is invalid, clear it and go to login
          print('❌ Auth token invalid: $e');
          await prefs.clear();
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
          );
        }
      } else {
        // User is not logged in
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
        );
      }
    }
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
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.restaurant_menu,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Saborly Food Kitchen',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Admin Panel',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              const SizedBox(height: 48),
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}