import 'package:flutter/material.dart';
import '../utils/constants.dart';

class ScoreBadge extends StatelessWidget {
  final double score;
  final double size;
  final bool showLabel;

  const ScoreBadge({
    super.key,
    required this.score,
    this.size = 64.0,
    this.showLabel = true,
  });

  Color _getScoreColor(double val) {
    if (val >= 80) return AppConstants.accentColor; // Green
    if (val >= 60) return AppConstants.warningColor; // Amber
    return AppConstants.errorColor; // Red
  }

  @override
  Widget build(BuildContext context) {
    final color = _getScoreColor(score);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.12),
            border: Border.all(color: color, width: 2.5),
          ),
          alignment: Alignment.center,
          child: Text(
            score.toStringAsFixed(0),
            style: TextStyle(
              fontSize: size * 0.35,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: 4),
          Text(
            score >= 80 ? 'Proficient' : (score >= 60 ? 'Developing' : 'Needs Work'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ]
      ],
    );
  }
}

class MetricBar extends StatelessWidget {
  final String title;
  final double score;
  final IconData icon;

  const MetricBar({
    super.key,
    required this.title,
    required this.score,
    required this.icon,
  });

  Color _getColor(double val) {
    if (val >= 80) return AppConstants.accentColor;
    if (val >= 60) return AppConstants.primaryLight;
    return AppConstants.warningColor;
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor(score);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppConstants.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppConstants.textPrimary,
                  ),
                ),
              ),
              Text(
                '${score.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (score / 100.0).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}
