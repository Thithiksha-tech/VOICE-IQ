import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioService extends ChangeNotifier {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  bool _isRecording = false;
  bool _isPlaying = false;
  String? _recordedFilePath;
  int _recordingDuration = 0;
  Timer? _timer;

  bool get isRecording => _isRecording;
  bool get isPlaying => _isPlaying;
  String? get recordedFilePath => _recordedFilePath;
  int get recordingDuration => _recordingDuration;
  bool get hasRecording => _recordedFilePath != null && File(_recordedFilePath!).existsSync();

  AudioService() {
    _player.onPlayerStateChanged.listen((state) {
      _isPlaying = (state == PlayerState.playing);
      notifyListeners();
    });
  }

  /// 1. Requests actual microphone permission on the physical phone
  Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) {
      return true;
    } else if (status.isPermanentlyDenied) {
      await openAppSettings();
      return false;
    }
    return false;
  }

  /// 2. Starts recording actual physical microphone input
  Future<bool> startRecording() async {
    final hasPermission = await requestMicrophonePermission();
    if (!hasPermission) {
      return false;
    }

    try {
      // Clean up prior file if any
      await deleteRecording();

      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/voiceiq_${DateTime.now().millisecondsSinceEpoch}.m4a';

      const config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      );

      await _recorder.start(config, path: path);
      _isRecording = true;
      _recordedFilePath = path;
      _recordingDuration = 0;

      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _recordingDuration++;
        notifyListeners();
      });

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error starting audio recording: $e');
      _isRecording = false;
      notifyListeners();
      return false;
    }
  }

  /// 3. Stops recording and finalizes the audio file
  Future<String?> stopRecording() async {
    _timer?.cancel();
    if (!_isRecording) return _recordedFilePath;

    try {
      final path = await _recorder.stop();
      _isRecording = false;
      _recordedFilePath = path;
      notifyListeners();
      return path;
    } catch (e) {
      debugPrint('Error stopping audio recording: $e');
      _isRecording = false;
      notifyListeners();
      return null;
    }
  }

  /// 4. Plays the actual recorded audio file
  Future<void> playRecording() async {
    if (_recordedFilePath == null || !File(_recordedFilePath!).existsSync()) return;

    try {
      if (_isPlaying) {
        await _player.pause();
      } else {
        await _player.stop();
        await _player.play(DeviceFileSource(_recordedFilePath!));
      }
    } catch (e) {
      debugPrint('Error during audio playback: $e');
    }
  }

  /// Pauses playback
  Future<void> pausePlayback() async {
    await _player.pause();
  }

  /// Stops playback
  Future<void> stopPlayback() async {
    await _player.stop();
  }

  /// 5. Deletes the current recording from storage
  Future<void> deleteRecording() async {
    _timer?.cancel();
    await _player.stop();
    if (_isRecording) {
      try { await _recorder.stop(); } catch (_) {}
      _isRecording = false;
    }
    if (_recordedFilePath != null) {
      final file = File(_recordedFilePath!);
      if (file.existsSync()) {
        try { file.deleteSync(); } catch (_) {}
      }
      _recordedFilePath = null;
    }
    _recordingDuration = 0;
    _isPlaying = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }
}
