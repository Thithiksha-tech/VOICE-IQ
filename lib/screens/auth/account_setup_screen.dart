import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../utils/constants.dart';
import '../../widgets/custom_button.dart';

/// Shown on a student's first sign-in: verify an email, then replace the default password.
/// AuthWrapper opens the dashboard automatically once both steps are done.
class AccountSetupScreen extends StatefulWidget {
  const AccountSetupScreen({super.key});

  @override
  State<AccountSetupScreen> createState() => _AccountSetupScreenState();
}

class _AccountSetupScreenState extends State<AccountSetupScreen> {
  final ApiService _apiService = ApiService();
  final _emailFormKey = GlobalKey<FormState>();
  final _codeFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _codeSent = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _infoMessage;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function(String token) action) async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final token = auth.currentUser?.token;
    if (token == null) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await action(token);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendCode() async {
    if (!_emailFormKey.currentState!.validate()) return;
    await _run((token) async {
      final message = await _apiService.sendEmailCode(_emailController.text, token);
      setState(() {
        _codeSent = true;
        _infoMessage = message;
      });
    });
  }

  Future<void> _verifyCode() async {
    if (!_codeFormKey.currentState!.validate()) return;
    final auth = Provider.of<AuthService>(context, listen: false);
    await _run((token) async {
      final profile = await _apiService.verifyEmail(_codeController.text, token);
      _infoMessage = null;
      await auth.applyProfile(profile);
    });
  }

  Future<void> _savePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;
    final auth = Provider.of<AuthService>(context, listen: false);
    await _run((token) async {
      final profile = await _apiService.setPassword(_passwordController.text, token);
      await auth.applyProfile(profile);
    });
  }

  InputDecoration _decoration(String label, IconData icon, {Widget? suffix, String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _banner(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _stepChip(int number, String label, {required bool active, required bool done}) {
    final color = done ? AppConstants.accentColor : (active ? AppConstants.primaryColor : AppConstants.textSecondary);
    return Expanded(
      child: Row(
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: color.withValues(alpha: done || active ? 1 : 0.25),
            child: done
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Text('$number', style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: TextStyle(fontSize: 13, fontWeight: active ? FontWeight.bold : FontWeight.w500, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emailStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Add an email you can access. We will use it to reset your password if you ever forget it.',
          style: TextStyle(fontSize: 14, color: AppConstants.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 18),
        Form(
          key: _emailFormKey,
          child: TextFormField(
            controller: _emailController,
            enabled: !_codeSent,
            keyboardType: TextInputType.emailAddress,
            decoration: _decoration('Your email', Icons.email_outlined, hint: 'name@gmail.com'),
            validator: (val) => val == null || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(val.trim())
                ? 'Please enter a valid email'
                : null,
          ),
        ),
        const SizedBox(height: 16),
        if (!_codeSent)
          CustomButton(label: 'Send Code', icon: Icons.send_rounded, isLoading: _isLoading, onPressed: _sendCode)
        else
          Form(
            key: _codeFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: _decoration('6-digit code', Icons.pin_outlined),
                  validator: (val) => val == null || !RegExp(r'^\d{6}$').hasMatch(val.trim())
                      ? 'Enter the 6-digit code from the email'
                      : null,
                ),
                const SizedBox(height: 8),
                CustomButton(
                  label: 'Verify Email',
                  icon: Icons.verified_outlined,
                  isLoading: _isLoading,
                  onPressed: _verifyCode,
                ),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => setState(() {
                            _codeSent = false;
                            _infoMessage = null;
                            _errorMessage = null;
                            _codeController.clear();
                          }),
                  child: const Text('Wrong email or no code? Change email'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _passwordStep() {
    return Form(
      key: _passwordFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Choose your own password. Your default password will stop working.',
            style: TextStyle(fontSize: 14, color: AppConstants.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: _decoration(
              'New password',
              Icons.lock_outline,
              suffix: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (val) => val == null || val.length < 6 ? 'Password must be at least 6 characters' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmController,
            obscureText: _obscurePassword,
            decoration: _decoration('Confirm new password', Icons.lock_outline),
            validator: (val) => val != _passwordController.text ? 'Passwords do not match' : null,
          ),
          const SizedBox(height: 24),
          CustomButton(
            label: 'Save Password & Continue',
            icon: Icons.check_rounded,
            isLoading: _isLoading,
            onPressed: _savePassword,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final user = auth.currentUser;
    final emailDone = user?.emailVerified ?? false;
    final firstName = (user?.name ?? '').split(' ').first;

    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Welcome, $firstName!',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppConstants.primaryColor),
              ),
              const SizedBox(height: 6),
              Text(
                'Register No. ${user?.registerNumber ?? ''}  •  Let\'s set up your account',
                style: const TextStyle(fontSize: 14, color: AppConstants.textSecondary),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  _stepChip(1, 'Verify email', active: !emailDone, done: emailDone),
                  _stepChip(2, 'Set password', active: emailDone, done: false),
                ],
              ),
              const SizedBox(height: 24),
              if (_errorMessage != null) _banner(_errorMessage!, AppConstants.errorColor, Icons.error_outline),
              if (_infoMessage != null && _errorMessage == null)
                _banner(_infoMessage!, AppConstants.accentColor, Icons.mark_email_read_outlined),
              if (emailDone)
                _banner('Email verified: ${user?.email}', AppConstants.accentColor, Icons.verified_outlined),
              emailDone ? _passwordStep() : _emailStep(),
              const SizedBox(height: 28),
              TextButton.icon(
                onPressed: _isLoading ? null : () => auth.logout(),
                icon: const Icon(Icons.logout, size: 18, color: AppConstants.textSecondary),
                label: const Text('Sign out', style: TextStyle(color: AppConstants.textSecondary)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
