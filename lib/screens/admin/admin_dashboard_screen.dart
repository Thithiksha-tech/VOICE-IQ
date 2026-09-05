import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../models/dashboard_model.dart';
import '../../utils/constants.dart';
import '../../widgets/score_badge.dart';
import '../auth/login_screen.dart';
import 'admin_student_detail_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final ApiService _apiService = ApiService();
  AdminDashboardModel? _dashboardData;
  List<AdminStudentSummaryModel> _students = [];
  bool _isLoading = true;
  String? _error;
  int _selectedTab = 0; // 0 = Overview, 1 = Student Roster

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  Future<void> _loadAdminData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final auth = Provider.of<AuthService>(context, listen: false);
    final token = auth.currentUser?.token;

    if (token == null) {
      setState(() {
        _isLoading = false;
        _error = 'Admin authentication required.';
      });
      return;
    }

    try {
      final dashFuture = _apiService.getAdminDashboard(token);
      final studentsFuture = _apiService.getAdminStudents(token);

      final results = await Future.wait([dashFuture, studentsFuture]);

      if (mounted) {
        setState(() {
          _dashboardData = results[0] as AdminDashboardModel;
          _students = results[1] as List<AdminStudentSummaryModel>;
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

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark luxury theme
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 1,
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: Colors.amber, size: 22),
            SizedBox(width: 10),
            Text(
              'VoiceIQ Admin Console',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _loadAdminData,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            tooltip: 'Sign Out Admin',
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.amber)))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _loadAdminData, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Navigation Tabs
                    Container(
                      color: const Color(0xFF1E293B),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _selectedTab = 0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: _selectedTab == 0 ? Colors.amber : Colors.transparent,
                                      width: 2.5,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  'Overview & Feed',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _selectedTab == 0 ? Colors.amber : Colors.white60,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _selectedTab = 1),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: _selectedTab == 1 ? Colors.amber : Colors.transparent,
                                      width: 2.5,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  'Student Roster (${_students.length})',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _selectedTab == 1 ? Colors.amber : Colors.white60,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadAdminData,
                        child: _selectedTab == 0 ? _buildOverviewTab() : _buildStudentsTab(),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildOverviewTab() {
    final data = _dashboardData;
    if (data == null) return const SizedBox();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Institutional Performance Metrics',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          const Text('Real-time aggregations from all student speaking practice submissions.', style: TextStyle(color: Colors.white60, fontSize: 13)),
          const SizedBox(height: 20),

          // Aggregate Cards
          Row(
            children: [
              Expanded(
                child: _buildAdminMetricCard('Total Students', data.totalStudents.toString(), Icons.people_alt_outlined, Colors.blueAccent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAdminMetricCard('Sessions Logged', data.totalPracticeSessions.toString(), Icons.mic_none_outlined, Colors.purpleAccent),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildAdminMetricCard(
            'Institutional Average Score',
            '${data.averagePerformance.toStringAsFixed(1)} / 100',
            Icons.speed_rounded,
            data.averagePerformance >= 70 ? Colors.emerald : Colors.amber,
          ),
          const SizedBox(height: 28),

          // Recent Activity Stream
          const Text(
            'Recent Speech Practice Submissions',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 12),

          if (data.recentActivity.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('No recent practice submissions found.', style: TextStyle(color: Colors.white60)),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: data.recentActivity.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final act = data.recentActivity[index];
                final dateStr = DateFormat('MMM d, h:mm a').format(act.createdAt);

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: act.overallScore >= 75 ? Colors.green.withOpacity(0.2) : Colors.amber.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          act.overallScore.toStringAsFixed(0),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: act.overallScore >= 75 ? Colors.greenAccent : Colors.amber,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              act.studentName,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              act.prompt,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Text(dateStr, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStudentsTab() {
    if (_students.isEmpty) {
      return const Center(
        child: Text('No enrolled students found.', style: TextStyle(color: Colors.white60)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _students.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final st = _students[index];

        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AdminStudentDetailScreen(studentId: st.id, studentName: st.name)),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blueAccent.withOpacity(0.2),
                  child: Text(
                    st.name.isNotEmpty ? st.name[0].toUpperCase() : 'S',
                    style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        st.name,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(st.email, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                      const SizedBox(height: 6),
                      Text(
                        '${st.sessionsCount} Sessions • Avg: ${st.averageScore.toStringAsFixed(1)}%',
                        style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 14),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAdminMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.white60)),
            ],
          ),
        ],
      ),
    );
  }
}
