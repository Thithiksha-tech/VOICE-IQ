import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../models/session_model.dart';
import '../../models/dashboard_model.dart';
import '../student/session_detail_screen.dart';

class AdminStudentDetailScreen extends StatefulWidget {
  final AdminStudentSummaryModel student;

  const AdminStudentDetailScreen({super.key, required this.student});

  int get studentId => student.id;
  String get studentName => student.name;

  @override
  State<AdminStudentDetailScreen> createState() => _AdminStudentDetailScreenState();
}

class _AdminStudentDetailScreenState extends State<AdminStudentDetailScreen> {
  final ApiService _apiService = ApiService();
  List<PracticeSessionModel> _history = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchStudentHistory();
  }

  /// Two confirmations: an explanation, then typing the register number's last 3 digits.
  Future<void> _confirmResetLogin() async {
    final st = widget.student;
    final regNo = st.registerNumber ?? '';
    final lastDigits = regNo.length >= 3 ? regNo.substring(regNo.length - 3) : regNo;

    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset this login?'),
        content: Text(
          'This will, for ${st.name} ($regNo):\n\n'
          '• set the password back to the default\n'
          '• remove their email\n'
          '• sign them out on every phone\n'
          '• make them set up email and password again\n\n'
          'Their practice history and scores are kept.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continue')),
        ],
      ),
    );
    if (proceed != true || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('Confirm reset'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Type $lastDigits (the last 3 digits of $regNo) to reset ${st.name}'s login."),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  maxLength: 3,
                  onChanged: (_) => setDialogState(() {}),
                  decoration: const InputDecoration(border: OutlineInputBorder(), counterText: ''),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: controller.text.trim() == lastDigits ? () => Navigator.pop(ctx, true) : null,
                child: const Text('Reset login'),
              ),
            ],
          ),
        );
      },
    );
    if (confirmed != true || !mounted) return;

    final token = Provider.of<AuthService>(context, listen: false).currentUser?.token;
    if (token == null) return;
    try {
      final message = await _apiService.adminResetStudentLogin(st.id, token);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 8)),
      );
      Navigator.pop(context, true); // tells the roster to reload
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _fetchStudentHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final auth = Provider.of<AuthService>(context, listen: false);
    final token = auth.currentUser?.token;
    if (token == null) return;

    try {
      final list = await _apiService.getStudentHistory(widget.studentId, token);
      if (mounted) {
        setState(() {
          _history = list;
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
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(widget.studentName, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.amber)))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white70)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.studentName,
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Reg. No. ${widget.student.registerNumber ?? '-'} • '
                              '${widget.student.activated ? 'Active' : 'Not activated'}',
                              style: const TextStyle(color: Colors.white60, fontSize: 13),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.student.email ?? 'Email not set up yet',
                              style: const TextStyle(color: Colors.white38, fontSize: 12),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildStat('Sessions', _history.length.toString()),
                                _buildStat(
                                  'Average',
                                  _history.isNotEmpty
                                      ? '${(_history.map((s) => s.overallScore ?? 0.0).reduce((a, b) => a + b) / _history.length).toStringAsFixed(1)}%'
                                      : '—',
                                ),
                                _buildStat(
                                  'Highest',
                                  _history.isNotEmpty
                                      ? '${_history.map((s) => s.overallScore ?? 0.0).reduce((a, b) => a > b ? a : b).toStringAsFixed(0)}%'
                                      : '—',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Skill breakdown: average of each AI-evaluated skill
                      if (widget.student.sessionsCount > 0) ...[
                        const Text(
                          'Skill Averages',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Column(
                            children: widget.student.skillAverages.entries.map(_buildSkillBar).toList(),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Practice History
                      const Text(
                        'Practice Submissions & Evaluations',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 12),

                      if (_history.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('No practice sessions submitted by this student yet.', style: TextStyle(color: Colors.white60)),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _history.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final s = _history[index];
                            final dateStr = DateFormat('MMM d, y • h:mm a').format(s.createdAt);

                            return InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => SessionDetailScreen(sessionId: s.id)),
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
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withOpacity(0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        (s.overallScore ?? 0.0).toStringAsFixed(0),
                                        style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            s.prompt,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(dateStr, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 14),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: const Icon(Icons.restart_alt_rounded),
                          label: const Text('Reset login'),
                          onPressed: _confirmResetLogin,
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSkillBar(MapEntry<String, double> skill) {
    final label = '${skill.key[0].toUpperCase()}${skill.key.substring(1)}';
    final color = skill.value >= 75 ? Colors.greenAccent : (skill.value >= 50 ? Colors.amber : Colors.redAccent);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              Text(skill.value.toStringAsFixed(0), style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (skill.value / 100).clamp(0, 1),
              minHeight: 7,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.amber)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.white60)),
      ],
    );
  }
}
