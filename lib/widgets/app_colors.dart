import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors
  static const Color primary = Color(0xFFE91E63);
  static const Color primaryLight = Color(0xFFF8BBD9);
  static const Color primaryDark = Color(0xFFC2185B);
  
  // Secondary Colors
  static const Color secondary = Color(0xFF00BCD4);
  static const Color secondaryLight = Color(0xFFB2EBF2);
  static const Color secondaryDark = Color(0xFF0097A7);
  
  // Background Colors
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardBackground = Color(0xFFFFFFFF);
  
  // Text Colors
  static const Color textDark = Color(0xFF212121);
  static const Color textMedium = Color(0xFF424242);
  static const Color textLight = Color(0xFF9E9E9E);
  static const Color textHint = Color(0xFFBDBDBD);
  
  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);
  
  // Food Category Colors
  static const Color friendsFamily = Color(0xFFFFE0B2);
  static const Color highOn = Color(0xFFE8F5E8);
  static const Color duetCombos = Color(0xFFFFF3E0);
  static const Color whopper = Color(0xFFE3F2FD);
  
  // Additional Colors
  static const Color border = Color(0xFFE0E0E0);
  static const Color divider = Color(0xFFEEEEEE);
  static const Color shadow = Color(0x1F000000);
  static const Color shimmer = Color(0xFFE0E0E0);
  static const Color shimmerHighlight = Color(0xFFF5F5F5);
  
  // Gradient Colors
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient cardGradient = LinearGradient(
    colors: [Colors.white, Color(0xFFFAFAFA)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  
  // Food Item Colors
  static const Map<String, Color> foodCategoryColors = {
    'burger': Color(0xFFFFE0B2),
    'pizza': Color(0xFFE8F5E8),
    'chicken': Color(0xFFFFF3E0),
    'drinks': Color(0xFFE3F2FD),
    'dessert': Color(0xFFF3E5F5),
    'combo': Color(0xFFE0F2F1),
  };
  
  // Order Status Colors
  static const Map<String, Color> orderStatusColors = {
    'pending': Color(0xFFFF9800),
    'confirmed': Color(0xFF2196F3),
    'preparing': Color(0xFFFF5722),
    'ready': Color(0xFF9C27B0),
    'delivered': Color(0xFF4CAF50),
    'cancelled': Color(0xFFF44336),
  };
}