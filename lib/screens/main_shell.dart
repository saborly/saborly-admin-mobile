import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:Saborly_admin/providers/auth_provider.dart';
import 'package:Saborly_admin/screens/account_screen.dart';
import 'package:Saborly_admin/screens/auth.dart';
import 'package:Saborly_admin/screens/live_deliveries_screen.dart';
import 'package:Saborly_admin/screens/orders_dashboard_screen.dart';
import 'package:Saborly_admin/services/order_provider.dart';
import 'package:Saborly_admin/theme/app_colors.dart';

/// App shell shown after login: a persistent bottom nav across Orders,
/// Deliveries and Account, replacing the old pattern where those (plus
/// Switch Branch / Settings / Logout) were scattered behind an app-bar icon
/// and a '⋮' popup menu on the orders screen.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  final _tabs = const [
    OrdersDashboardScreen(),
    LiveDeliveriesScreen(),
    AccountScreen(),
  ];

  @override
  void initState() {
    super.initState();
    context.read<AuthProvider>().addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  void dispose() {
    context.read<AuthProvider>().removeListener(_onAuthChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = context.select<OrderProvider, int>((p) => p.getStatusCount('pending'));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: _FloatingNavBar(
        index: _index,
        pendingCount: pendingCount,
        onChanged: (i) => setState(() => _index = i),
      ),
    );
  }
}

class _FloatingNavBar extends StatelessWidget {
  final int index;
  final int pendingCount;
  final ValueChanged<int> onChanged;

  const _FloatingNavBar({required this.index, required this.pendingCount, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottomInset > 0 ? bottomInset : 16),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.softShadow(opacity: 0.08, blur: 20, offset: const Offset(0, 8)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            _NavItem(
              icon: Icons.receipt_long_rounded,
              label: 'Orders',
              badgeCount: pendingCount,
              selected: index == 0,
              onTap: () => onChanged(0),
            ),
            _NavItem(
              icon: Icons.pedal_bike_rounded,
              label: 'Deliveries',
              selected: index == 1,
              onTap: () => onChanged(1),
            ),
            _NavItem(
              icon: Icons.person_rounded,
              label: 'Account',
              selected: index == 2,
              onTap: () => onChanged(2),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    Widget iconWidget = Icon(icon, color: selected ? AppColors.primary : AppColors.textLight, size: 22);
    if (badgeCount > 0) {
      iconWidget = Badge(
        backgroundColor: AppColors.danger,
        label: Text(badgeCount > 9 ? '9+' : '$badgeCount'),
        child: iconWidget,
      );
    }

    return Expanded(
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? AppColors.primaryLight : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: iconWidget,
            ),
          ),
        ),
      ),
    );
  }
}
