import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  UserModel? _currentUser;
  bool _isLoading = true;
  bool _sessionChecked = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null && _currentUser!.token != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;
  bool get isLoading => _isLoading;
  /// True only while the saved session is restored at app start.
  bool get isInitializing => !_sessionChecked;
  String? get errorMessage => _errorMessage;

  AuthService() {
    loadSavedSession();
  }

  Future<void> loadSavedSession() async {
    _isLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataStr = prefs.getString('voiceiq_user');
      if (userDataStr != null) {
        final data = jsonDecode(userDataStr);
        _currentUser = UserModel.fromJson(data, token: data['access_token']);
      }
    } catch (e) {
      _currentUser = null;
    } finally {
      _isLoading = false;
      _sessionChecked = true;
      notifyListeners();
    }
  }

  /// [username] is a register number (students) or an email (admin).
  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _apiService.login(username, password);
      _currentUser = user;
      await _persistSession(user);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }


  /// Applies a profile returned by the server (e.g. after email verification). Uses the new
  /// token when the server issued one (password changes invalidate older sign-ins).
  Future<void> applyProfile(Map<String, dynamic> profile) async {
    final token = profile['access_token'] as String? ?? _currentUser?.token;
    if (token == null) return;
    _currentUser = UserModel.fromJson(profile, token: token);
    await _persistSession(_currentUser!);
    notifyListeners();
  }

  Future<void> _persistSession(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('voiceiq_user', jsonEncode(user.toJson()));
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('voiceiq_user');
    _currentUser = null;
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
