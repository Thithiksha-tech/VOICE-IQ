import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../models/session_model.dart';
import '../../utils/constants.dart';
import '../../widgets/score_badge.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final ApiService _apiService = ApiService();
  List<PracticeSessionModel> _sessions = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final auth = Provider.of<AuthService>(context, listen: false);
    final user = auth.currentUser;

    if (user == null || user.token == null) {
      setState(() {
        _isLoading = false;
        _error = 'User not authenticated.';
      });
      return;
    }

    try {
      final list = await _apiService.getStudentHistory(user.id, user.token!);
      if (mounted) {
        setState(() {
          _sessions = list;
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Text(_error!));
    }

    if (_sessions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text('Complete practice sessions to view your communication growth analytics.'),
        ),
      );
    }

    // Calculate aggregations
    final scores = _sessions.map((s) => s.overallScore ?? 0.0).toList();
    final avgScore = scores.reduce((a, b) => a + b) / scores.length;
    final highest = scores.reduce((a, b) => a > b ? a : b);
    final lowest = scores.reduce((a, b) => a < b ? a : b);

    // Calculate metric averages from speech_analysis
    final analyses = _sessions.where((s) => s.analysis != null).map((s) => s.analysis!).toList();
    double avgFluency = 0, avgPron = 0, avgGrammar = 0, avgVocab = 0, avgConf = 0, avgWpm = 0;
    int totalFillers = 0;

    if (analyses.isNotEmpty) {
      avgFluency = analyses.map((a) => a.fluencyScore).reduce((a, b) => a + b) / analyses.length;
      avgPron = analyses.map((a) => a.pronunciationScore).reduce((a, b) => a + b) / analyses.length;
      avgGrammar = analyses.map((a) => a.grammarScore).reduce((a, b) => a + b) / analyses.length;
      avgVocab = analyses.map((a) => a.vocabularyScore).reduce((a, b) => a + b) / analyses.length;
      avgConf = analyses.map((a) => a.confidenceScore).reduce((a, b) => a + b) / analyses.length;
      avgWpm = analyses.map((a) => a.wordsPerMinute).reduce((a, b) => a + b) / analyses.length;
      totalFillers = analyses.map((a) => a.fillerWordCount).reduce((a, b) => a + b);
    }

    return RefreshIndicator(
      onRefresh: _loadProgress,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Performance Analytics',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppConstants.textPrimary),
            ),
            const SizedBox(height: 4),
            const Text(
              'Longitudinal communication metrics based on your practice submissions',
              style: TextStyle(fontSize: 13, color: AppConstants.textSecondary),
            ),
            const SizedBox(height: 20),

            // High Level Stat Tiles
            Row(
              children: [
                Expanded(
                  child: _buildStatTile('Average Score', avgScore.toStringAsFixed(1), Icons.insights, AppConstants.primaryLight),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatTile('Peak Score', highest.toStringAsFixed(0), Icons.emoji_events_outlined, AppConstants.accentColor),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatTile('Pacing (WPM)', avgWpm.toStringAsFixed(0), Icons.speed, AppConstants.primaryColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatTile('Total Fillers', totalFillers.toString(), Icons.record_voice_over, AppConstants.warningColor),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Category Strength Index
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
                  const Text(
                    'Skill Proficiency Index',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppConstants.textPrimary),
                  ),
                  const SizedBox(height: 14),
                  MetricBar(title: 'Fluency & Rhythm', score: avgFluency, icon: Icons.waves_rounded),
                  MetricBar(title: 'Pronunciation (AI-Estimated)', score: avgPron, icon: Icons.hearing_rounded),
                  MetricBar(title: 'Grammar & Structure', score: avgGrammar, icon: Icons.spellcheck_rounded),
                  MetricBar(title: 'Vocabulary & Diction', score: avgVocab, icon: Icons.menu_book_rounded),
                  MetricBar(title: 'Confidence Index', score: avgConf, icon: Icons.shield_outlined),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Recent Trajectory
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
                  const Text(
                    'Session Score Trajectory',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppConstants.textPrimary),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: _sessions.take(6).toList().reversed.map((s) {
                      final score = s.overallScore ?? 0.0;
                      final height = (score / 100.0) * 120.0;
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('${score.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Container(
                            width: 28,
                            height: height.clamp(12.0, 120.0),
                            decoration: BoxDecoration(
                              color: score >= 75 ? AppConstants.accentColor : AppConstants.primaryLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text('#${s.id}', style: const TextStyle(fontSize: 10, color: AppConstants.textSecondary)),
                        ],
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppConstants.textPrimary)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12, color: AppConstants.textSecondary)),
        ],
      ),
    );
  }
}
