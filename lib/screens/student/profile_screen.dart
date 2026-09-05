import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../utils/constants.dart';
import '../../widgets/custom_button.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final user = auth.currentUser;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Profile Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: AppConstants.primaryColor.withOpacity(0.12),
                  child: Text(
                    (user?.name.isNotEmpty == true) ? user!.name[0].toUpperCase() : 'U',
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppConstants.primaryColor),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  user?.name ?? 'Student',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppConstants.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? '',
                  style: const TextStyle(fontSize: 14, color: AppConstants.textSecondary),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppConstants.primaryLight.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    user?.role.toUpperCase() ?? 'STUDENT',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppConstants.primaryLight),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Technical Environment Info (Helpful for Project Viva!)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.terminal_rounded, color: AppConstants.primaryLight, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'MCA Project Architecture Specs',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppConstants.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildInfoRow('Project', 'VoiceIQ AI Speech Coach'),
                _buildInfoRow('Mobile Engine', 'Flutter 3.x + Dart'),
                _buildInfoRow('Backend Engine', 'FastAPI (Python 3.10+)'),
                _buildInfoRow('Database Layer', 'SQLite 3 (SQLAlchemy ORM)'),
                _buildInfoRow('Active Server IP', AppConstants.apiBaseUrl),
                _buildInfoRow('Speech-to-Text', 'Whisper / Gemini AI Model'),
                _buildInfoRow('Evaluation Core', 'Multi-metric Syntactic NLP'),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Logout Action
          CustomButton(
            label: 'Sign Out of VoiceIQ',
            icon: Icons.logout_rounded,
            backgroundColor: AppConstants.errorColor,
            onPressed: () async {
              await auth.logout();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, color: AppConstants.textSecondary)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppConstants.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
