import 'analysis_model.dart';

class PracticeSessionModel {
  final int id;
  final int studentId;
  final String prompt;
  final String? audioPath;
  final String? transcript;
  final double? overallScore;
  final DateTime createdAt;
  final SpeechAnalysisModel? analysis;

  PracticeSessionModel({
    required this.id,
    required this.studentId,
    required this.prompt,
    this.audioPath,
    this.transcript,
    this.overallScore,
    required this.createdAt,
    this.analysis,
  });

  factory PracticeSessionModel.fromJson(Map<String, dynamic> json) {
    return PracticeSessionModel(
      id: json['id'] ?? json['session_id'] ?? 0,
      studentId: json['student_id'] ?? 0,
      prompt: json['prompt'] ?? '',
      audioPath: json['audio_path'],
      transcript: json['transcript'],
      overallScore: (json['overall_score'] as num?)?.toDouble(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
      analysis: json['analysis'] != null ? SpeechAnalysisModel.fromJson(json['analysis']) : null,
    );
  }
}
