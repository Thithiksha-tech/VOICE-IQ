import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../utils/constants.dart';
import '../../widgets/custom_button.dart';

/// Replaces the account email after the new address is verified with an emailed code.
class ChangeEmailScreen extends StatefulWidget {
  const ChangeEmailScreen({super.key});

  @override
  State<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends State<ChangeEmailScreen> {
  final ApiService _apiService = ApiService();
  final _emailFormKey = GlobalKey<FormState>();
  final _codeFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();

  bool _codeSent = false;
  bool _isLoading = false;
  String? _infoMessage;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function(String token) action) async {
    final token = Provider.of<AuthService>(context, listen: false).currentUser?.token;
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

  Future<void> _verify() async {
    if (!_codeFormKey.currentState!.validate()) return;
    final auth = Provider.of<AuthService>(context, listen: false);
    await _run((token) async {
      final profile = await _apiService.verifyEmail(_codeController.text, token);
      await auth.applyProfile(profile);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Email changed to ${profile['email']}')),
      );
      Navigator.pop(context);
    });
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _banner(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 20),
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

  @override
  Widget build(BuildContext context) {
    final currentEmail = Provider.of<AuthService>(context).currentUser?.email;

    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: const Text('Change Email'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppConstants.textPrimary,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Current email: ${currentEmail ?? 'not set'}\n'
                'Enter your new email. We will send a code there to confirm it is yours; '
                'your email changes only after you verify it.',
                style: const TextStyle(fontSize: 14, color: AppConstants.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 24),
              if (_errorMessage != null) _banner(_errorMessage!, AppConstants.errorColor, Icons.error_outline),
              if (_infoMessage != null && _errorMessage == null)
                _banner(_infoMessage!, AppConstants.accentColor, Icons.mark_email_read_outlined),
              Form(
                key: _emailFormKey,
                child: TextFormField(
                  controller: _emailController,
                  enabled: !_codeSent,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _decoration('New email', Icons.email_outlined),
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
                        label: 'Verify & Change Email',
                        icon: Icons.verified_outlined,
                        isLoading: _isLoading,
                        onPressed: _verify,
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
          ),
        ),
      ),
    );
  }
}
