class SpeechAnalysisModel {
  final int id;
  final int practiceSessionId;
  final double fluencyScore;
  final double pronunciationScore;
  final double grammarScore;
  final double vocabularyScore;
  final double confidenceScore;
  final double wordsPerMinute;
  final int fillerWordCount;
  final String feedback;
  final DateTime? createdAt;

  SpeechAnalysisModel({
    required this.id,
    required this.practiceSessionId,
    required this.fluencyScore,
    required this.pronunciationScore,
    required this.grammarScore,
    required this.vocabularyScore,
    required this.confidenceScore,
    required this.wordsPerMinute,
    required this.fillerWordCount,
    required this.feedback,
    this.createdAt,
  });

  factory SpeechAnalysisModel.fromJson(Map<String, dynamic> json) {
    return SpeechAnalysisModel(
      id: json['id'] ?? 0,
      practiceSessionId: json['practice_session_id'] ?? 0,
      fluencyScore: (json['fluency_score'] as num?)?.toDouble() ?? 0.0,
      pronunciationScore: (json['pronunciation_score'] as num?)?.toDouble() ?? 0.0,
      grammarScore: (json['grammar_score'] as num?)?.toDouble() ?? 0.0,
      vocabularyScore: (json['vocabulary_score'] as num?)?.toDouble() ?? 0.0,
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.0,
      wordsPerMinute: (json['words_per_minute'] as num?)?.toDouble() ?? 0.0,
      fillerWordCount: json['filler_word_count'] ?? 0,
      feedback: json['feedback'] ?? '',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
    );
  }
}
