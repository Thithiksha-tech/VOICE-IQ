import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../models/dashboard_model.dart';
import '../../models/session_model.dart';
import '../../utils/constants.dart';
import '../../widgets/score_badge.dart';
import '../../widgets/custom_button.dart';
import 'practice_screen.dart';
import 'history_screen.dart';
import 'progress_screen.dart';
import 'profile_screen.dart';
import 'session_detail_screen.dart';

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  final ApiService _apiService = ApiService();
  StudentDashboardModel? _dashboardData;
  bool _isLoading = true;
  String? _error;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final auth = Provider.of<AuthService>(context, listen: false);
    final token = auth.currentUser?.token;

    if (token == null) {
      setState(() {
        _isLoading = false;
        _error = 'User not authenticated.';
      });
      return;
    }

    try {
      final data = await _apiService.getStudentDashboard(token);
      if (mounted) {
        setState(() {
          _dashboardData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final studentName = auth.currentUser?.name ?? 'Student';

    // Sub-screens for bottom navigation
    final List<Widget> pages = [
      _buildDashboardHome(studentName),
      const HistoryScreen(),
      const ProgressScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppConstants.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.record_voice_over_rounded, color: AppConstants.primaryColor, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'VoiceIQ',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppConstants.primaryColor),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppConstants.textSecondary),
            tooltip: 'Refresh Data',
            onPressed: _loadDashboard,
          ),
        ],
      ),
      body: pages[_currentTabIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        onTap: (index) => setState(() => _currentTabIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppConstants.primaryColor,
        unselectedItemColor: AppConstants.textSecondary,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.history_outlined), activeIcon: Icon(Icons.history_rounded), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.auto_graph_outlined), activeIcon: Icon(Icons.auto_graph_rounded), label: 'Progress'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildDashboardHome(String studentName) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading student performance metrics...', style: TextStyle(color: AppConstants.textSecondary)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48, color: AppConstants.errorColor),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppConstants.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 20),
              CustomButton(
                label: 'Retry Connection',
                icon: Icons.refresh,
                onPressed: _loadDashboard,
              ),
            ],
          ),
        ),
      );
    }

    final data = _dashboardData;
    final overallPerf = data?.overallPerformance ?? 0.0;
    final sessionsCount = data?.practiceSessionsCount ?? 0;
    final recentScore = data?.recentScore;

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Student Welcome Card
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, $studentName',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Ready to sharpen your oral communication?',
                      style: TextStyle(fontSize: 13, color: AppConstants.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Performance Overview Cards
            Container(
              padding: const EdgeInsets.all(20),
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Overall Performance
                  Column(
                    children: [
                      ScoreBadge(score: overallPerf, size: 68),
                      const SizedBox(height: 8),
                      const Text(
                        'Overall Performance',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppConstants.textSecondary),
                      ),
                    ],
                  ),
                  Container(width: 1, height: 60, color: Colors.grey.shade200),
                  // Practice Sessions Count
                  Column(
                    children: [
                      Text(
                        sessionsCount.toString(),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppConstants.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Practice Sessions',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppConstants.textSecondary),
                      ),
                    ],
                  ),
                  Container(width: 1, height: 60, color: Colors.grey.shade200),
                  // Recent Score
                  Column(
                    children: [
                      Text(
                        recentScore != null ? recentScore.toStringAsFixed(0) : '—',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: recentScore != null && recentScore >= 75 ? AppConstants.accentColor : AppConstants.warningColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Recent Score',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppConstants.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Big Action: START PRACTICE
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.mic, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Interactive Voice Practice',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Receive a viva prompt, record your actual voice, and obtain instant AI feedback on fluency, grammar, pronunciation & confidence.',
                    style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppConstants.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text(
                        'Start Voice Practice',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PracticeScreen()),
                        );
                        _loadDashboard();
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Recent Sessions Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Practice Sessions',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppConstants.textPrimary),
                ),
                if (data != null && data.recentSessions.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(() => _currentTabIndex = 1),
                    child: const Text('View All'),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            if (data == null || data.recentSessions.isEmpty)
              Container(
                padding: const EdgeInsets.all(28),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(Icons.mic_none_rounded, size: 40, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    const Text(
                      'No practice sessions yet',
                      style: TextStyle(fontWeight: FontWeight.w600, color: AppConstants.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Tap "Start Voice Practice" above to take your first oral test.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppConstants.textSecondary),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: data.recentSessions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final session = data.recentSessions[index];
                  return _buildSessionCard(session);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCard(PracticeSessionModel session) {
    final dateStr = DateFormat('MMM d, y • h:mm a').format(session.createdAt);
    final score = session.overallScore ?? 0.0;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SessionDetailScreen(sessionId: session.id)),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            ScoreBadge(score: score, size: 48, showLabel: false),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.prompt,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppConstants.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateStr,
                    style: const TextStyle(fontSize: 12, color: AppConstants.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppConstants.textSecondary),
          ],
        ),
      ),
    );
  }
}
