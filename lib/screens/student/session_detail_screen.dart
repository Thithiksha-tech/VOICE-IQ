import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../models/session_model.dart';
import '../../utils/constants.dart';
import 'analysis_result_screen.dart';

class SessionDetailScreen extends StatefulWidget {
  final int sessionId;

  const SessionDetailScreen({super.key, required this.sessionId});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  final ApiService _apiService = ApiService();
  PracticeSessionModel? _session;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final auth = Provider.of<AuthService>(context, listen: false);
    final token = auth.currentUser?.token;

    if (token == null) {
      setState(() {
        _isLoading = false;
        _error = 'User not authenticated.';
      });
      return;
    }

    try {
      final session = await _apiService.getSessionDetail(widget.sessionId, token);
      if (mounted) {
        setState(() {
          _session = session;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Session Evaluation')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Session Evaluation')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 44, color: AppConstants.errorColor),
                const SizedBox(height: 12),
                Text(_error ?? 'Unable to find session', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _loadDetail, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    return AnalysisResultScreen(session: _session!);
  }
}
