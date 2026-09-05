import 'session_model.dart';

class StudentDashboardModel {
  final int studentId;
  final String studentName;
  final String studentEmail;
  final double overallPerformance;
  final int practiceSessionsCount;
  final double? recentScore;
  final List<PracticeSessionModel> recentSessions;

  StudentDashboardModel({
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.overallPerformance,
    required this.practiceSessionsCount,
    this.recentScore,
    required this.recentSessions,
  });

  factory StudentDashboardModel.fromJson(Map<String, dynamic> json) {
    var rawList = json['recent_sessions'] as List? ?? [];
    List<PracticeSessionModel> parsedSessions = rawList
        .map((item) => PracticeSessionModel.fromJson(item))
        .toList();

    return StudentDashboardModel(
      studentId: json['student_id'] ?? 0,
      studentName: json['student_name'] ?? 'Student',
      studentEmail: json['student_email'] ?? '',
      overallPerformance: (json['overall_performance'] as num?)?.toDouble() ?? 0.0,
      practiceSessionsCount: json['practice_sessions_count'] ?? 0,
      recentScore: (json['recent_score'] as num?)?.toDouble(),
      recentSessions: parsedSessions,
    );
  }
}

class AdminDashboardModel {
  final int totalStudents;
  final int totalPracticeSessions;
  final double averagePerformance;
  final List<AdminActivityModel> recentActivity;

  AdminDashboardModel({
    required this.totalStudents,
    required this.totalPracticeSessions,
    required this.averagePerformance,
    required this.recentActivity,
  });

  factory AdminDashboardModel.fromJson(Map<String, dynamic> json) {
    var rawList = json['recent_activity'] as List? ?? [];
    List<AdminActivityModel> activities = rawList
        .map((item) => AdminActivityModel.fromJson(item))
        .toList();

    return AdminDashboardModel(
      totalStudents: json['total_students'] ?? 0,
      totalPracticeSessions: json['total_practice_sessions'] ?? 0,
      averagePerformance: (json['average_performance'] as num?)?.toDouble() ?? 0.0,
      recentActivity: activities,
    );
  }
}

class AdminActivityModel {
  final int sessionId;
  final int studentId;
  final String studentName;
  final String prompt;
  final double overallScore;
  final DateTime createdAt;

  AdminActivityModel({
    required this.sessionId,
    required this.studentId,
    required this.studentName,
    required this.prompt,
    required this.overallScore,
    required this.createdAt,
  });

  factory AdminActivityModel.fromJson(Map<String, dynamic> json) {
    return AdminActivityModel(
      sessionId: json['session_id'] ?? 0,
      studentId: json['student_id'] ?? 0,
      studentName: json['student_name'] ?? 'Student',
      prompt: json['prompt'] ?? '',
      overallScore: (json['overall_score'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class AdminStudentSummaryModel {
  final int id;
  final String name;
  final String email;
  final int sessionsCount;
  final double averageScore;

  AdminStudentSummaryModel({
    required this.id,
    required this.name,
    required this.email,
    required this.sessionsCount,
    required this.averageScore,
  });

  factory AdminStudentSummaryModel.fromJson(Map<String, dynamic> json) {
    return AdminStudentSummaryModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      sessionsCount: json['sessions_count'] ?? 0,
      averageScore: (json['average_score'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
