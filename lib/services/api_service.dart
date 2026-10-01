import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import '../models/user_model.dart';
import '../models/session_model.dart';
import '../models/dashboard_model.dart';

class ApiService {
  /// Called when the server rejects the saved login (expired or invalid token).
  static void Function()? onUnauthorized;

  final http.Client _client = http.Client();

  void _checkSession(http.Response response) {
    if (response.statusCode == 401) {
      onUnauthorized?.call();
      throw Exception('Your session has expired. Please sign in again.');
    }
  }

  Map<String, String> _headers(String? token) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // --- Authentication ---

  /// [username] is a register number (students) or an email (admin).
  Future<UserModel> login(String username, String password) async {
    try {
      final response = await _client.post(
        Uri.parse(AppConstants.loginEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username.trim(),
          'password': password,
        }),
      );

      final data = _decodeJson(response);
      if (response.statusCode == 200) {
        return UserModel.fromJson(data);
      } else {
        throw Exception(data['detail'] ?? 'Invalid register number or password.');
      }
    } on SocketException {
      throw Exception('Cannot reach the server. Please check your internet connection.');
    }
  }

  /// Emails a 6-digit reset code to the account's verified email.
  Future<String> forgotPassword(String username) async {
    final data = await _post(
      AppConstants.forgotPasswordEndpoint,
      {'username': username.trim()},
      'Could not send the reset code. Please try again.',
    );
    return data['message'] as String;
  }

  /// Sets a new password using the emailed code.
  Future<String> resetPassword(String username, String code, String newPassword) async {
    final data = await _post(
      AppConstants.resetPasswordEndpoint,
      {'username': username.trim(), 'code': code.trim(), 'new_password': newPassword},
      'Could not reset the password. Please try again.',
    );
    return data['message'] as String;
  }

  // --- First-login account setup ---

  Future<String> sendEmailCode(String email, String token) async {
    final data = await _post(
      AppConstants.emailSendCodeEndpoint,
      {'email': email.trim().toLowerCase()},
      'Could not send the verification code. Please try again.',
      token: token,
    );
    return data['message'] as String;
  }

  /// Returns the updated profile (email_verified, must_change_password).
  Future<Map<String, dynamic>> verifyEmail(String code, String token) {
    return _post(
      AppConstants.emailVerifyEndpoint,
      {'code': code.trim()},
      'Could not verify the code. Please try again.',
      token: token,
    );
  }

  Future<Map<String, dynamic>> setPassword(String newPassword, String token) {
    return _post(
      AppConstants.setPasswordEndpoint,
      {'new_password': newPassword},
      'Could not save the new password. Please try again.',
      token: token,
    );
  }

  // --- Admin ---

  /// Default password, email removed, first-login setup again; signs the student out everywhere.
  Future<String> adminResetStudentLogin(int studentId, String token) async {
    final data = await _post(
      '${AppConstants.adminStudentsEndpoint}/$studentId/reset-login',
      {},
      'Could not reset the login. Please try again.',
      token: token,
    );
    return data['message'] as String;
  }

  Future<Map<String, dynamic>> _post(
    String url,
    Map<String, String> body,
    String fallbackError, {
    String? token,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse(url),
        headers: _headers(token),
        body: jsonEncode(body),
      );
      if (token != null) _checkSession(response);

      final data = _decodeJson(response);
      if (response.statusCode == 200) {
        return data as Map<String, dynamic>;
      }
      final detail = data['detail'];
      throw Exception(detail is String ? detail : fallbackError);
    } on SocketException {
      throw Exception('Cannot reach the server. Please check your internet connection.');
    }
  }

  // --- Real Audio Upload & AI Analysis ---

  /// Uploads a recording for background analysis and returns the job id at once.
  Future<int> startAnalysis({
    required String audioPath,
    required String prompt,
    required double durationSec,
    required String token,
  }) async {
    final file = File(audioPath);
    if (!await file.exists()) {
      throw Exception('Recorded audio file was not found on the device.');
    }

    final request = http.MultipartRequest('POST', Uri.parse(AppConstants.analyzeAsyncEndpoint));
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['prompt'] = prompt;
    request.fields['duration'] = durationSec.toStringAsFixed(1);
    request.files.add(
      await http.MultipartFile.fromPath('audio', audioPath, filename: audioPath.split(Platform.pathSeparator).last),
    );

    try {
      // Generous limit: the free server may need up to a minute to wake up
      final streamed = await request.send().timeout(const Duration(seconds: 90));
      final response = await http.Response.fromStream(streamed);
      _checkSession(response);
      final data = _decodeJson(response) as Map<String, dynamic>;
      if (response.statusCode == 200) return data['job_id'] as int;
      throw Exception(data['detail'] ?? 'Could not upload your recording. Please retry.');
    } on SocketException {
      throw Exception('No internet connection. Please check your network and try again.');
    } on TimeoutException {
      throw Exception('The server is taking too long to respond. Please try again in a minute.');
    }
  }

  /// Returns {status: processing|done|failed, error, session_id} for a background analysis.
  Future<Map<String, dynamic>> getAnalysisJob(int jobId, String token) async {
    final response = await _client
        .get(Uri.parse('${AppConstants.analysisJobsEndpoint}/$jobId'), headers: _headers(token))
        .timeout(const Duration(seconds: 30));
    _checkSession(response);
    final data = _decodeJson(response) as Map<String, dynamic>;
    if (response.statusCode == 200) return data;
    throw Exception(data['detail'] ?? 'Could not check the analysis.');
  }

  /// Parses a JSON reply; a non-JSON reply (e.g. a gateway error page) becomes a readable error.
  dynamic _decodeJson(http.Response response) {
    try {
      return jsonDecode(response.body);
    } on FormatException {
      throw Exception('The server is busy right now (error ${response.statusCode}). Please try again in a minute.');
    }
  }

  // --- Student Data ---

  Future<StudentDashboardModel> getStudentDashboard(String token) async {
    try {
      final response = await _client.get(
        Uri.parse(AppConstants.studentDashboardEndpoint),
        headers: _headers(token),
      );

      _checkSession(response);
      final data = _decodeJson(response);
      if (response.statusCode == 200) {
        return StudentDashboardModel.fromJson(data);
      } else {
        throw Exception(data['detail'] ?? 'Could not load student dashboard.');
      }
    } on SocketException {
      throw Exception('Failed to connect to backend server.');
    }
  }

  Future<List<PracticeSessionModel>> getStudentHistory(int studentId, String token) async {
    try {
      final response = await _client.get(
        Uri.parse('${AppConstants.studentHistoryEndpoint}/$studentId'),
        headers: _headers(token),
      );

      _checkSession(response);
      final data = _decodeJson(response);
      if (response.statusCode == 200) {
        return (data as List).map((i) => PracticeSessionModel.fromJson(i)).toList();
      } else {
        throw Exception(data['detail'] ?? 'Could not load practice history.');
      }
    } on SocketException {
      throw Exception('Network connection failed.');
    }
  }

  Future<PracticeSessionModel> getSessionDetail(int sessionId, String token) async {
    try {
      final response = await _client.get(
        Uri.parse('${AppConstants.sessionDetailEndpoint}/$sessionId'),
        headers: _headers(token),
      );

      _checkSession(response);
      final data = _decodeJson(response);
      if (response.statusCode == 200) {
        return PracticeSessionModel.fromJson(data);
      } else {
        throw Exception(data['detail'] ?? 'Could not load session details.');
      }
    } on SocketException {
      throw Exception('Network connection failed.');
    }
  }

  // --- Admin Endpoints ---

  Future<AdminDashboardModel> getAdminDashboard(String token) async {
    try {
      final response = await _client.get(
        Uri.parse(AppConstants.adminDashboardEndpoint),
        headers: _headers(token),
      );

      _checkSession(response);
      final data = _decodeJson(response);
      if (response.statusCode == 200) {
        return AdminDashboardModel.fromJson(data);
      } else {
        throw Exception(data['detail'] ?? 'Could not load admin dashboard.');
      }
    } on SocketException {
      throw Exception('Cannot connect to backend server.');
    }
  }

  Future<List<AdminStudentSummaryModel>> getAdminStudents(String token) async {
    try {
      final response = await _client.get(
        Uri.parse(AppConstants.adminStudentsEndpoint),
        headers: _headers(token),
      );

      _checkSession(response);
      final data = _decodeJson(response);
      if (response.statusCode == 200) {
        return (data as List).map((i) => AdminStudentSummaryModel.fromJson(i)).toList();
      } else {
        throw Exception(data['detail'] ?? 'Could not load students list.');
      }
    } on SocketException {
      throw Exception('Cannot connect to backend server.');
    }
  }
}
