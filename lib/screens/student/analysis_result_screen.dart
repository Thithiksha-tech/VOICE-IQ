import 'package:flutter/material.dart';
import '../../models/session_model.dart';
import '../../utils/constants.dart';
import '../../widgets/score_badge.dart';
import '../../widgets/custom_button.dart';
import 'practice_screen.dart';

class AnalysisResultScreen extends StatelessWidget {
  final PracticeSessionModel session;

  const AnalysisResultScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final analysis = session.analysis;
    final overall = session.overallScore ?? 0.0;

    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: const Text('Speech Evaluation Results'),
        backgroundColor: Colors.white,
        foregroundColor: AppConstants.textPrimary,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Overall Score Hero Card
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
                  const Text(
                    'Overall Communication Score',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppConstants.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  ScoreBadge(score: overall, size: 88),
                  const SizedBox(height: 12),
                  Text(
                    overall >= 80
                        ? 'Excellent Delivery! Ready for viva & placement rounds.'
                        : (overall >= 60
                            ? 'Good Baseline. Practice pacing and vocabulary precision.'
                            : 'Needs Focused Improvement in sentence flow.'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: AppConstants.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Pacing & Disfluency Quick Metrics
            if (analysis != null)
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.speed_rounded, size: 18, color: AppConstants.primaryLight),
                              SizedBox(width: 6),
                              Text('Pacing', style: TextStyle(fontSize: 12, color: AppConstants.textSecondary)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${analysis.wordsPerMinute.toStringAsFixed(0)} WPM',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppConstants.textPrimary),
                          ),
                          const SizedBox(height: 2),
                          const Text('Ideal: 120-150 WPM', style: TextStyle(fontSize: 11, color: AppConstants.textSecondary)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.record_voice_over, size: 18, color: AppConstants.warningColor),
                              SizedBox(width: 6),
                              Text('Filler Words', style: TextStyle(fontSize: 12, color: AppConstants.textSecondary)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${analysis.fillerWordCount}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: analysis.fillerWordCount <= 2 ? AppConstants.accentColor : AppConstants.warningColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text('e.g. "um", "like"', style: TextStyle(fontSize: 11, color: AppConstants.textSecondary)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 20),

            // Detailed Communication Breakdown
            if (analysis != null)
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
                      'Core Competency Breakdown',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppConstants.textPrimary),
                    ),
                    const SizedBox(height: 12),
                    MetricBar(title: 'Fluency & Pacing', score: analysis.fluencyScore, icon: Icons.waves_rounded),
                    MetricBar(title: 'Pronunciation Clarity (AI-Estimated)', score: analysis.pronunciationScore, icon: Icons.hearing_rounded),
                    MetricBar(title: 'Grammar & Syntax', score: analysis.grammarScore, icon: Icons.spellcheck_rounded),
                    MetricBar(title: 'Lexical Richness & Vocabulary', score: analysis.vocabularyScore, icon: Icons.menu_book_rounded),
                    MetricBar(title: 'Speaking Confidence (AI-Estimated)', score: analysis.confidenceScore, icon: Icons.shield_outlined),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            // Spoken Transcript Section
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
                      Icon(Icons.format_quote_rounded, color: AppConstants.primaryLight),
                      SizedBox(width: 8),
                      Text(
                        'Actual Spoken Transcript',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppConstants.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppConstants.backgroundColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      session.transcript ?? 'No transcript available',
                      style: const TextStyle(fontSize: 14, color: AppConstants.textPrimary, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // AI Feedback & Coaching Suggestions
            if (analysis != null)
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
                        Icon(Icons.lightbulb_outline_rounded, color: AppConstants.accentColor),
                        SizedBox(width: 8),
                        Text(
                          'AI Feedback & Action Plan',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppConstants.textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      analysis.feedback,
                      style: const TextStyle(fontSize: 14, color: AppConstants.textPrimary, height: 1.5),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 28),

            // Bottom Actions
            CustomButton(
              label: 'Practice Another Question',
              icon: Icons.replay_rounded,
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const PracticeScreen()),
                );
              },
            ),
            const SizedBox(height: 12),
            CustomButton(
              label: 'Return to Dashboard',
              isOutlined: true,
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
