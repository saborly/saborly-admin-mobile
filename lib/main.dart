import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
        navigatorKey: navigatorKey,
        title: 'Saborly Admin',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: scaffoldBg,
          colorScheme: ColorScheme.fromSeed(
            seedColor: primary,
            brightness: Brightness.light,
            primary: primary,
            secondary: secondary,
            surface: surface,
          ),
          textTheme: GoogleFonts.interTextTheme(
            ThemeData.light().textTheme.apply(
              bodyColor: const Color(0xFF111827),
              displayColor: const Color(0xFF111827),
            ),
          ),
          cardTheme: CardThemeData(
            elevation: 0,
            color: surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          appBarTheme: AppBarTheme(
            elevation: 0,
            centerTitle: false,
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF0F172A),
            surfaceTintColor: Colors.transparent,
            titleTextStyle: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: primary,
              side: const BorderSide(color: Color(0xFFD1D5DB)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            labelStyle: GoogleFonts.inter(color: const Color(0xFF475569), fontSize: 14),
            hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 14),
            prefixIconColor: const Color(0xFF64748B),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFDC2626)),
            ),
          ),
          snackBarTheme: SnackBarThemeData(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF0F172A),
            contentTextStyle: GoogleFonts.inter(color: Colors.white, fontSize: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
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
            labelStyle: GoogleFonts.inter(color: const Color(0xFF1E293B), fontSize: 12),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          dialogTheme: DialogThemeData(
            backgroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
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
        MaterialPageRoute(builder: (_) => const OrdersDashboardScreen()),
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