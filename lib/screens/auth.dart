import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:Saborly_admin/providers/auth_provider.dart';
import 'package:Saborly_admin/models/branch.dart';
import 'package:Saborly_admin/screens/main_shell.dart';
import 'package:Saborly_admin/theme/app_colors.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  Branch? _selectedBranch;
  bool _passwordVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().loadBranches();
    });
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBranch == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a branch')),
      );
      return;
    }

    final success = await context.read<AuthProvider>().login(
          _emailController.text.trim(),
          _passwordController.text,
          _selectedBranch!.id,
        );

    if (success && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.read<AuthProvider>().error ?? 'Login failed'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Sign in to Saborly',
                      style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textDark),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Manage orders and deliveries for your branch',
                      style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMedium),
                    ),
                    const SizedBox(height: 32),
                    _buildLabel('Branch'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<Branch>(
                      initialValue: _selectedBranch,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                      decoration: const InputDecoration(
                        hintText: 'Select your branch',
                        prefixIcon: Icon(Icons.storefront_outlined, size: 20),
                      ),
                      items: authProvider.branches.map((branch) {
                        return DropdownMenuItem(value: branch, child: Text(branch.name));
                      }).toList(),
                      onChanged: (value) => setState(() => _selectedBranch = value),
                      validator: (value) => value == null ? 'Please select a branch' : null,
                    ),
                    const SizedBox(height: 18),
                    _buildLabel('Email address'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        hintText: 'you@saborly.es',
                        prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
                      ),
                      validator: (value) => (value?.isEmpty ?? true) ? 'Email is required' : null,
                    ),
                    const SizedBox(height: 18),
                    _buildLabel('Password'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_passwordVisible,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _handleLogin(),
                      decoration: InputDecoration(
                        hintText: 'Enter your password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _passwordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: AppColors.textLight,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                        ),
                      ),
                      validator: (value) => (value?.isEmpty ?? true) ? 'Password is required' : null,
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: authProvider.isLoading ? null : _handleLogin,
                        child: authProvider.isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2.2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                              )
                            : const Text('Sign In'),
                      ),
                    ),
                    const SizedBox(height: 40),
                    Center(
                      child: Text(
                        'Saborly Restaurant Management',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textLight),
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

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
