import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import '../models/user_model.dart';
import '../models/session_model.dart';
import '../models/dashboard_model.dart';

class ApiService {
  final http.Client _client = http.Client();

  Map<String, String> _headers(String? token) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // --- Authentication ---

  Future<UserModel> register(String name, String email, String password) async {
    try {
      final response = await _client.post(
        Uri.parse(AppConstants.registerEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name.trim(),
          'email': email.trim().toLowerCase(),
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return UserModel.fromJson(data);
      } else {
        throw Exception(data['detail'] ?? 'Registration failed. Please try again.');
      }
    } on SocketException {
      throw Exception('Cannot connect to backend server at ${AppConstants.apiBaseUrl}. Please verify your network connection and server IP.');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Unexpected error: $e');
    }
  }

  Future<UserModel> login(String email, String password) async {
    try {
      final response = await _client.post(
        Uri.parse(AppConstants.loginEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim().toLowerCase(),
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return UserModel.fromJson(data);
      } else {
        throw Exception(data['detail'] ?? 'Invalid email or password.');
      }
    } on SocketException {
      throw Exception('Cannot reach backend server. Please ensure the FastAPI server is running on ${AppConstants.apiBaseUrl}.');
    }
  }

  Future<UserModel> adminLogin(String email, String password) async {
    try {
      final response = await _client.post(
        Uri.parse(AppConstants.adminLoginEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim().toLowerCase(),
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return UserModel.fromJson(data);
      } else {
        throw Exception(data['detail'] ?? 'Admin authentication failed.');
      }
    } on SocketException {
      throw Exception('Cannot reach backend server. Verify ${AppConstants.apiBaseUrl}.');
    }
  }

  // --- Real Audio Upload & AI Analysis ---

  Future<PracticeSessionModel> uploadAndAnalyzeAudio({
    required String audioPath,
    required String prompt,
    required double durationSec,
    required String token,
  }) async {
    try {
      final file = File(audioPath);
      if (!await file.exists()) {
        throw Exception('Recorded audio file was not found on the device.');
      }

      final uri = Uri.parse(AppConstants.analyzeEndpoint);
      final request = http.MultipartRequest('POST', uri);

      request.headers['Authorization'] = 'Bearer $token';
      request.fields['prompt'] = prompt;
      request.fields['duration'] = durationSec.toStringAsFixed(1);

      request.files.add(
        await http.MultipartFile.fromPath(
          'audio',
          audioPath,
          filename: audioPath.split(Platform.pathSeparator).last,
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return PracticeSessionModel.fromJson(data);
      } else {
        throw Exception(data['detail'] ?? 'Failed to analyze recording. Please retry.');
      }
    } on SocketException {
      throw Exception('Network error while uploading audio. Verify Wi-Fi and server IP.');
    }
  }

  // --- Student Data ---

  Future<StudentDashboardModel> getStudentDashboard(String token) async {
    try {
      final response = await _client.get(
        Uri.parse(AppConstants.studentDashboardEndpoint),
        headers: _headers(token),
      );

      final data = jsonDecode(response.body);
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

      final data = jsonDecode(response.body);
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

      final data = jsonDecode(response.body);
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

      final data = jsonDecode(response.body);
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

      final data = jsonDecode(response.body);
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
