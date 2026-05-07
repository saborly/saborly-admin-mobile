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
import 'package:Saborly_admin/providers/auth_provider.dart';

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
    const primary = Color(0xFF4A148C);
    const secondary = Color(0xFF7C3AED);
    const surface = Color(0xFFFFFFFF);
    const scaffoldBg = Color(0xFFF6F7FB);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
      ],
      child: MaterialApp(
        title: 'Saborly Admin',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: scaffoldBg,
          fontFamily: 'Poppins',
          colorScheme: ColorScheme.fromSeed(
            seedColor: primary,
            brightness: Brightness.light,
            primary: primary,
            secondary: secondary,
            surface: surface,
          ),
          textTheme: ThemeData.light().textTheme.apply(
                bodyColor: const Color(0xFF111827),
                displayColor: const Color(0xFF111827),
              ),
          cardTheme: CardThemeData(
            elevation: 0,
            color: surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          appBarTheme: const AppBarTheme(
            elevation: 0,
            centerTitle: false,
            backgroundColor: Colors.white,
            foregroundColor: Color(0xFF0F172A),
            surfaceTintColor: Colors.transparent,
            titleTextStyle: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
              fontFamily: 'Poppins',
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: primary,
              side: const BorderSide(color: Color(0xFFD1D5DB)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            labelStyle: const TextStyle(color: Color(0xFF475569)),
            hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
            prefixIconColor: const Color(0xFF64748B),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: primary, width: 1.4),
            ),
          ),
          snackBarTheme: SnackBarThemeData(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF1F2937),
            contentTextStyle: const TextStyle(color: Colors.white),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          dividerTheme: const DividerThemeData(
            color: Color(0xFFE5E7EB),
            thickness: 1,
            space: 1,
          ),
          progressIndicatorTheme: const ProgressIndicatorThemeData(
            color: primary,
          ),
          chipTheme: ChipThemeData(
            selectedColor: primary.withOpacity(0.12),
            backgroundColor: const Color(0xFFF1F5F9),
            labelStyle: const TextStyle(color: Color(0xFF1E293B), fontSize: 12),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          dialogTheme: DialogThemeData(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
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

    if (!mounted) return;
    
    final authProvider = context.read<AuthProvider>();
    await authProvider.initialize();

    if (mounted) {
      if (authProvider.isAuthenticated && authProvider.selectedBranch != null) {
        // User is logged in and branch is selected
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const OrdersDashboardScreen()),
        );
      } else {
        // User is not logged in or branch not selected
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
                'Saborly Admin',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Order Management Console',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.w500,
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