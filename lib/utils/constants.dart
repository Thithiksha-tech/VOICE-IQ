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
  //
  // 4. FOR USB-CONNECTED PHONE: run `adb reverse tcp:8000 tcp:8000`, then use
  //    static const String apiBaseUrl = 'http://127.0.0.1:8000';
  //
  // 5. HOSTED ON RENDER (default): works anywhere, no USB or Wi-Fi needed.
  //    Override for local testing: flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000
  // =========================================================================
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://voiceiq-backend-tkjn.onrender.com',
  );

  // API Endpoints
  static const String loginEndpoint = '$apiBaseUrl/api/auth/login';
  static const String forgotPasswordEndpoint = '$apiBaseUrl/api/auth/forgot-password';
  static const String resetPasswordEndpoint = '$apiBaseUrl/api/auth/reset-password';
  static const String meEndpoint = '$apiBaseUrl/api/auth/me';
  static const String emailSendCodeEndpoint = '$apiBaseUrl/api/auth/email/send-code';
  static const String emailVerifyEndpoint = '$apiBaseUrl/api/auth/email/verify';
  static const String setPasswordEndpoint = '$apiBaseUrl/api/auth/set-password';
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

  // Speaking practice question pool; the practice screen shows 5 at random
  static const int questionsPerRound = 5;
  static const List<String> questionPool = [
    // Interview & self-presentation
    "Tell me about yourself in under one minute.",
    "What are your greatest strengths, and how have they helped you?",
    "Describe a weakness you are working on and what you are doing about it.",
    "Where do you see yourself five years from now?",
    "Why should a company hire you over other candidates?",
    "Tell me about a time you worked in a team to achieve a goal.",
    "Describe a situation where you handled pressure or a tight deadline.",
    "Tell me about a mistake you made and what you learned from it.",
    // Everyday & personal
    "Describe your favourite book or movie and why you recommend it.",
    "Talk about a person who has inspired you the most.",
    "Describe a memorable trip or place you have visited.",
    "What is a hobby you enjoy, and how did you get started with it?",
    "Describe your ideal weekend from morning to night.",
    "Talk about a skill you would like to learn and why.",
    // Opinion & discussion
    "Should social media have age restrictions? Give your opinion.",
    "Is online learning as effective as classroom learning?",
    "What are the advantages and disadvantages of working from home?",
    "How can young people contribute to protecting the environment?",
    "Do you think artificial intelligence will create more jobs than it replaces?",
    "Should mobile phones be allowed in classrooms?",
    "What makes a good leader? Explain with an example.",
    // Situational
    "How would you handle a disagreement with a teammate?",
    "Explain how you would plan a college event with a small budget.",
    "You have three tasks due today. How do you decide what to do first?",
    "How would you convince a friend to start exercising regularly?",
    // Technology explained simply
    "Explain how the internet works to someone who has never used it.",
    "What is cloud computing? Explain it with an everyday example.",
    "Describe a mobile app you use daily and how you would improve it.",
    "Explain why cybersecurity matters for ordinary people.",
    "Describe a project you built and the biggest challenge you faced.",
  ];
}
