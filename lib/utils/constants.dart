import 'package:flutter/material.dart';

class AppConstants {
  // =========================================================================
  // SINGLE CONFIGURATION POINT FOR BACKEND NETWORKING
  // =========================================================================
  // Change this single variable depending on your testing environment:
  //
  // 1. FOR PHYSICAL ANDROID PHONE (Connected to same Wi-Fi as your PC):
  //    Replace '192.168.1.100' with your computer's actual IPv4 address!
  //    (Find your IP via Windows Command Prompt: ipconfig)
  //    Example: static const String apiBaseUrl = 'http://192.168.1.100:8000';
  //
  // 2. FOR ANDROID STUDIO EMULATOR:
  //    Use 10.0.2.2 (which maps to host PC localhost):
  //    static const String apiBaseUrl = 'http://10.0.2.2:8000';
  //
  // 3. FOR WEB OR DESKTOP TESTING:
  //    static const String apiBaseUrl = 'http://127.0.0.1:8000';
  // =========================================================================
  static const String apiBaseUrl = 'http://10.0.2.2:8000';

  // API Endpoints
  static const String registerEndpoint = '$apiBaseUrl/api/auth/register';
  static const String loginEndpoint = '$apiBaseUrl/api/auth/login';
  static const String adminLoginEndpoint = '$apiBaseUrl/api/admin/login';
  static const String analyzeEndpoint = '$apiBaseUrl/api/audio/analyze';
  static const String studentDashboardEndpoint = '$apiBaseUrl/api/history/dashboard/me';
  static const String studentHistoryEndpoint = '$apiBaseUrl/api/history/student';
  static const String sessionDetailEndpoint = '$apiBaseUrl/api/history';
  static const String adminDashboardEndpoint = '$apiBaseUrl/api/admin/dashboard';
  static const String adminStudentsEndpoint = '$apiBaseUrl/api/admin/students';

  // UI Theme Colors
  static const Color primaryColor = Color(0xFF1E3A8A); // Deep Navy
  static const Color primaryLight = Color(0xFF3B82F6); // Blue
  static const Color accentColor = Color(0xFF10B981); // Emerald Green
  static const Color backgroundColor = Color(0xFFF8FAFC); // Slate light
  static const Color surfaceColor = Colors.white;
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color warningColor = Color(0xFFF59E0B);

  // Recommended MCA Viva & Placement Speaking Prompts
  static const List<String> defaultPrompts = [
    "Introduce yourself and explain the primary architecture of your MCA final year project.",
    "Explain the concept of REST APIs and how asynchronous operations are handled in distributed systems.",
    "Describe an engineering challenge you solved recently and how you debugged the root cause.",
    "How would you explain the difference between relational databases and NoSQL stores to a stakeholder?",
    "Deliver a 1-minute pitch on why voice communication analysis is critical for modern software engineers."
  ];
}
