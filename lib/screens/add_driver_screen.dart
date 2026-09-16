import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:Saborly_admin/services/order_provider.dart';
import 'package:Saborly_admin/theme/app_colors.dart';

class AddDriverScreen extends StatefulWidget {
  const AddDriverScreen({super.key});

  @override
  State<AddDriverScreen> createState() => _AddDriverScreenState();
}

class _AddDriverScreenState extends State<AddDriverScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  static const _vehicleTypes = {
    'bike': ('Bike', Icons.pedal_bike_rounded),
    'motorcycle': ('Motorcycle', Icons.two_wheeler_rounded),
    'car': ('Car', Icons.directions_car_rounded),
    'on_foot': ('On Foot', Icons.directions_walk_rounded),
  };
  String? _vehicleType;

  bool _passwordVisible = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final error = await context.read<OrderProvider>().createDriver(
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          password: _passwordController.text,
          vehicleType: _vehicleType,
        );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (error == null) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_firstNameController.text.trim()} was added as a driver'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Add Driver'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Text(
                'New drivers are added to your current branch and can sign in with the email and password set here.',
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMedium, height: 1.4),
              ),
              const SizedBox(height: 24),
              _label('First name'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _firstNameController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: 'Ahmed',
                  prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                ),
                validator: (v) => (v == null || v.trim().length < 2) ? 'Enter a valid first name' : null,
              ),
              const SizedBox(height: 18),
              _label('Last name'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _lastNameController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: 'Khan',
                  prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                ),
                validator: (v) => (v == null || v.trim().length < 2) ? 'Enter a valid last name' : null,
              ),
              const SizedBox(height: 18),
              _label('Email address'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: 'driver@saborly.es',
                  prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
                ),
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return 'Email is required';
                  if (!RegExp(r'^[\w.-]+@[\w.-]+\.\w{2,}$').hasMatch(value)) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 18),
              _label('Phone number'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: '+34 600 000 000',
                  prefixIcon: Icon(Icons.phone_outlined, size: 20),
                ),
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return 'Phone number is required';
                  if (!RegExp(r'^\+?[\d\s\-()]+$').hasMatch(value)) return 'Enter a valid phone number';
                  return null;
                },
              ),
              const SizedBox(height: 18),
              _label('Temporary password'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _passwordController,
                obscureText: !_passwordVisible,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: 'At least 6 characters',
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
                validator: (v) => (v == null || v.length < 6) ? 'Password must be at least 6 characters' : null,
              ),
              const SizedBox(height: 18),
              _label('Vehicle type (optional)'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _vehicleTypes.entries.map((entry) {
                  final selected = _vehicleType == entry.key;
                  return ChoiceChip(
                    label: Text(entry.value.$1),
                    avatar: Icon(entry.value.$2, size: 16, color: selected ? Colors.white : AppColors.textMedium),
                    selected: selected,
                    onSelected: (_) => setState(() => _vehicleType = selected ? null : entry.key),
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.chipBackground,
                    labelStyle: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : AppColors.textDark,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
                    ),
                    showCheckmark: false,
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                        )
                      : const Text('Add Driver'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
    );
  }
}
