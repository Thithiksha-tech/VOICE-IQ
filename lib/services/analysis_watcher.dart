import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'notification_service.dart';

class AnalysisOutcome {
  final bool success;
  final int? sessionId;
  final String? error;

  const AnalysisOutcome({required this.success, this.sessionId, this.error});
}

class _Job {
  final String token;
  final Completer<AnalysisOutcome> completer = Completer<AnalysisOutcome>();
  final DateTime startedAt = DateTime.now();
  bool notifyWhenDone = false;

  _Job(this.token);
}

/// Polls background speech analyses. The practice screen awaits the result while it is open;
/// if the student leaves, a notification is shown when the analysis finishes.
class AnalysisWatcher extends ChangeNotifier {
  static const _pollInterval = Duration(seconds: 3);
  static const _giveUpAfter = Duration(minutes: 5);

  final ApiService _api = ApiService();
  final Map<int, _Job> _jobs = {};
  Timer? _timer;
  bool _polling = false;

  int get pendingCount => _jobs.length;

  /// Number of analyses finished so far; screens listen to refresh their data.
  int completedCount = 0;

  Future<AnalysisOutcome> track(int jobId, String token) {
    final job = _jobs.putIfAbsent(jobId, () => _Job(token));
    _timer ??= Timer.periodic(_pollInterval, (_) => _poll());
    notifyListeners();
    return job.completer.future;
  }

  /// The practice screen was closed: notify instead of returning the result to it.
  void notifyInBackground(int jobId) {
    _jobs[jobId]?.notifyWhenDone = true;
  }

  Future<void> _poll() async {
    if (_polling) return;
    _polling = true;
    try {
      for (final entry in Map.of(_jobs).entries) {
        final jobId = entry.key;
        final job = entry.value;
        AnalysisOutcome? outcome;
        try {
          final data = await _api.getAnalysisJob(jobId, job.token);
          if (data['status'] == 'done') {
            outcome = AnalysisOutcome(success: true, sessionId: data['session_id'] as int?);
          } else if (data['status'] == 'failed') {
            outcome = AnalysisOutcome(success: false, error: data['error'] as String?);
          }
        } catch (_) {
          // Network blip: keep polling until the time limit
        }
        if (outcome == null && DateTime.now().difference(job.startedAt) > _giveUpAfter) {
          outcome = const AnalysisOutcome(
            success: false,
            error: 'The analysis is taking too long. Check History later or try again.',
          );
        }
        if (outcome != null) _finish(jobId, job, outcome);
      }
    } finally {
      _polling = false;
      if (_jobs.isEmpty) {
        _timer?.cancel();
        _timer = null;
      }
    }
  }

  void _finish(int jobId, _Job job, AnalysisOutcome outcome) {
    _jobs.remove(jobId);
    if (outcome.success) completedCount++;
    if (job.notifyWhenDone) {
      NotificationService.show(
        id: jobId,
        title: outcome.success ? 'Your speech analysis is ready' : 'Speech analysis failed',
        body: outcome.success ? 'Tap to see your scores and feedback.' : (outcome.error ?? 'Please try again.'),
        sessionId: outcome.sessionId,
      );
    }
    if (!job.completer.isCompleted) job.completer.complete(outcome);
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
