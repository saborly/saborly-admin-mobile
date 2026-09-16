import 'package:flutter/material.dart';

/// Single source of truth for this app's brand colors, gradients and
/// order-status colors. Every screen should read from here rather than
/// redeclaring its own `_brandPrimary`/`_getStatusColor` — that duplication
/// is exactly what used to make colors drift between screens.
///
/// Palette direction: a calm indigo brand color used sparingly against a
/// mostly-neutral slate surface system — closer to a modern SaaS dashboard
/// (Stripe/Linear-style) than a bright two-tone gradient on every element.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF4F46E5); // indigo-600
  static const Color primaryDark = Color(0xFF3730A3); // indigo-800
  static const Color primaryLight = Color(0xFFEEF2FF); // indigo-50
  static const Color secondary = Color(0xFF7C3AED); // violet — used sparingly, not as a second brand color
  static const Color accent = Color(0xFFF97316); // orange — urgency/alerts only

  static const Color background = Color(0xFFF7F8FA);
  static const Color surface = Colors.white;
  static const Color surfaceAlt = Color(0xFFF7F8FA);
  static const Color chipBackground = Color(0xFFF1F2F6);

  static const Color textDark = Color(0xFF111827);
  static const Color textMedium = Color(0xFF6B7280);
  static const Color textLight = Color(0xFF9CA3AF);

  static const Color border = Color(0xFFE5E7EB);
  static const Color divider = Color(0xFFEEEFF2);
  static const Color shadow = Color(0x0F000000);

  static const Color success = Color(0xFF16A34A);
  static const Color danger = Color(0xFFDC2626);
  static const Color warning = Color(0xFFD97706);
  static const Color info = Color(0xFF2563EB);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF3730A3), Color(0xFF1E1B4B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static List<BoxShadow> softShadow({double opacity = 0.04, double blur = 14, Offset offset = const Offset(0, 3)}) {
    return [BoxShadow(color: Colors.black.withValues(alpha: opacity), blurRadius: blur, offset: offset)];
  }

  /// Cycles a small set of calm accent colors for avatar initials (customers,
  /// admins) so repeat names are visually distinguishable without needing a
  /// photo — deterministic per string so the same name always lands on the
  /// same color.
  static const List<Color> avatarPalette = [
    primary,
    Color(0xFF0D9488), // teal
    Color(0xFFD97706), // amber
    secondary,
    Color(0xFF0891B2), // cyan
    Color(0xFFDB2777), // pink
  ];

  static Color avatarColor(String seed) {
    if (seed.isEmpty) return primary;
    return avatarPalette[seed.codeUnitAt(0) % avatarPalette.length];
  }

  /// Every order status the backend can return (models/Order.js), so no
  /// screen falls back to a generic grey for a status it forgot to handle.
  static const Map<String, Color> _statusColors = {
    'all': info,
    'pending': warning,
    'confirmed': info,
    'preparing': primary,
    'ready': Color(0xFF0D9488), // teal
    'pickup': success,
    'driverpickup': Color(0xFF0891B2), // cyan
    'shop': Color(0xFF65A30D), // olive
    'out-for-delivery': secondary,
    'delivered': Color(0xFF15803D),
    'completed': Color(0xFF15803D),
    'cancelled': danger,
    'refunded': Color(0xFF6B7280),
  };

  static Color statusColor(String status) => _statusColors[status.toLowerCase()] ?? textLight;

  static String statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'confirmed':
        return 'Confirmed';
      case 'preparing':
        return 'Preparing';
      case 'ready':
        return 'Ready';
      case 'pickup':
        return 'Picked Up';
      case 'driverpickup':
        return 'Driver Picked Up';
      case 'shop':
        return 'Collected';
      case 'out-for-delivery':
        return 'Out for Delivery';
      case 'delivered':
        return 'Delivered';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'refunded':
        return 'Refunded';
      default:
        return status;
    }
  }
}
