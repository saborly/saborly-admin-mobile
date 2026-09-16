import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:Saborly_admin/models/branch.dart';
import 'package:Saborly_admin/providers/auth_provider.dart';
import 'package:Saborly_admin/services/order_provider.dart';
import 'package:Saborly_admin/theme/app_colors.dart';

/// Account tab — replaces the old branch-switch/settings/logout popup menu
/// with a single discoverable screen, in line with how the reference admin
/// apps surface these as a proper tab rather than hiding them behind icons.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Text('Account', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textDark)),
            const SizedBox(height: 20),
            const _ProfileCard(),
            const SizedBox(height: 24),
            const _SectionLabel('Branch'),
            const SizedBox(height: 10),
            const _BranchCard(),
            const SizedBox(height: 24),
            const _SectionLabel('Order preferences'),
            const SizedBox(height: 10),
            const _PreferencesCard(),
            const SizedBox(height: 32),
            const _LogoutButton(),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Saborly Admin · Order Management Console',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textLight),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textLight, letterSpacing: 0.5),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final seed = auth.adminEmail ?? auth.adminName ?? '';
    final displayName = (auth.adminName != null && auth.adminName!.isNotEmpty) ? auth.adminName! : 'Branch Staff';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.softShadow(opacity: 0.05, blur: 16, offset: const Offset(0, 4)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: AppColors.avatarColor(seed), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(
              auth.adminInitials,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                if (auth.adminEmail != null) ...[
                  const SizedBox(height: 2),
                  Text(auth.adminEmail!, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMedium)),
                ],
              ],
            ),
          ),
          if (auth.adminRole != null && auth.adminRole!.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(20)),
              child: Text(
                auth.adminRole!,
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
            ),
        ],
      ),
    );
  }
}

class _BranchCard extends StatelessWidget {
  const _BranchCard();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final branch = auth.selectedBranch;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.softShadow(opacity: 0.05, blur: 16, offset: const Offset(0, 4)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _showBranchSwitchSheet(context),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(12)),
                  alignment: Alignment.center,
                  child: const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Active branch', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMedium)),
                      const SizedBox(height: 2),
                      Text(
                        branch?.name ?? 'No branch selected',
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: AppColors.chipBackground, borderRadius: BorderRadius.circular(8)),
                  child: Text('Switch', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.primary)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showBranchSwitchSheet(BuildContext context) {
    final authProvider = context.read<AuthProvider>();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)),
                ),
              ),
              Text('Switch Branch', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark)),
              const SizedBox(height: 4),
              Text('Orders and stats will switch to the selected branch', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMedium)),
              const SizedBox(height: 18),
              if (authProvider.branches.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text('No branches available', style: GoogleFonts.inter(color: AppColors.textMedium)),
                )
              else
                ...authProvider.branches.map((branch) => _BranchOption(branch: branch)),
            ],
          ),
        ),
      ),
    );
  }
}

class _BranchOption extends StatelessWidget {
  final Branch branch;
  const _BranchOption({required this.branch});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final isSelected = branch.id == authProvider.selectedBranch?.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.pop(context);
          if (!isSelected) {
            authProvider.setSelectedBranch(branch);
            context.read<OrderProvider>().loadOrders();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryLight : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary.withValues(alpha: 0.12) : Colors.white,
                  shape: BoxShape.circle,
                  border: isSelected ? null : Border.all(color: AppColors.border),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.storefront_rounded, size: 18, color: isSelected ? AppColors.primary : AppColors.textLight),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  branch.name,
                  style: GoogleFonts.inter(
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 14.5,
                    color: isSelected ? AppColors.primary : AppColors.textDark,
                  ),
                ),
              ),
              if (isSelected) const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreferencesCard extends StatelessWidget {
  const _PreferencesCard();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OrderProvider>();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.softShadow(opacity: 0.05, blur: 16, offset: const Offset(0, 4)),
      ),
      child: Column(
        children: [
          _PreferenceTile(
            icon: Icons.print_rounded,
            title: 'Auto-print orders',
            subtitle: 'Send new orders straight to the receipt printer',
            value: provider.autoPrintEnabled,
            onChanged: provider.toggleAutoPrint,
          ),
          Divider(height: 1, color: AppColors.divider, indent: 16, endIndent: 16),
          _PreferenceTile(
            icon: Icons.check_circle_rounded,
            title: 'Auto-accept orders',
            subtitle: 'Automatically confirm new orders as they arrive',
            value: provider.autoAcceptEnabled,
            onChanged: provider.toggleAutoAccept,
          ),
        ],
      ),
    );
  }
}

class _PreferenceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PreferenceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      value: value,
      onChanged: onChanged,
      secondary: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: value ? AppColors.primaryLight : AppColors.chipBackground,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: value ? AppColors.primary : AppColors.textLight, size: 20),
      ),
      title: Text(title, style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.textDark)),
      subtitle: Text(subtitle, style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textMedium)),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _confirmLogout(context),
        icon: const Icon(Icons.logout_rounded, size: 18),
        label: const Text('Log out'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.danger,
          side: const BorderSide(color: Color(0xFFFCA5A5)),
          backgroundColor: const Color(0xFFFEF2F2),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14.5),
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.logout_rounded, color: AppColors.danger, size: 22),
            ),
            const SizedBox(width: 14),
            Text('Log out', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 19, color: AppColors.textDark)),
          ],
        ),
        content: Text(
          'You will need to sign in again to manage orders.',
          style: GoogleFonts.inter(fontSize: 14.5, color: AppColors.textMedium, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<AuthProvider>().logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
  }
}
