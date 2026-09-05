import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/audio_service.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../widgets/custom_button.dart';
import 'analysis_result_screen.dart';

class PracticeScreen extends StatefulWidget {
  final String? initialPrompt;

  const PracticeScreen({super.key, this.initialPrompt});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  late AudioService _audioService;
  final ApiService _apiService = ApiService();
  late String _selectedPrompt;
  bool _isSubmitting = false;
  String? _statusMessage;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _audioService = AudioService();
    _selectedPrompt = widget.initialPrompt ?? AppConstants.defaultPrompts.first;
  }

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }

  void _cyclePrompt() {
    final list = AppConstants.defaultPrompts;
    final currentIndex = list.indexOf(_selectedPrompt);
    final nextIndex = (currentIndex + 1) % list.length;
    setState(() {
      _selectedPrompt = list[nextIndex];
    });
  }

  Future<void> _handleSubmit() async {
    if (!_audioService.hasRecording) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please record your response before submitting.')),
      );
      return;
    }

    final auth = Provider.of<AuthService>(context, listen: false);
    final token = auth.currentUser?.token;
    if (token == null) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _statusMessage = 'Uploading your voice recording...';
    });

    try {
      // Step 1: Upload and perform real AI processing
      setState(() {
        _statusMessage = 'Transcribing speech & analyzing communication metrics...';
      });

      final session = await _apiService.uploadAndAnalyzeAudio(
        audioPath: _audioService.recordedFilePath!,
        prompt: _selectedPrompt,
        durationSec: _audioService.recordingDuration.toDouble(),
        token: token,
      );

      if (mounted) {
        // Clean up local temp recording
        await _audioService.deleteRecording();

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AnalysisResultScreen(session: session),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _statusMessage = null;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _audioService,
      builder: (context, child) {
        final isRecording = _audioService.isRecording;
        final hasRecording = _audioService.hasRecording;
        final isPlaying = _audioService.isPlaying;
        final duration = _audioService.recordingDuration;

        return Scaffold(
          backgroundColor: AppConstants.backgroundColor,
          appBar: AppBar(
            title: const Text('Voice Practice Session'),
            backgroundColor: Colors.white,
            foregroundColor: AppConstants.textPrimary,
            elevation: 0.5,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Speaking Prompt Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blue.shade100, width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.psychology_outlined, color: AppConstants.primaryLight, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Speaking Prompt',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppConstants.primaryLight),
                                ),
                              ],
                            ),
                            if (!isRecording && !_isSubmitting)
                              IconButton(
                                icon: const Icon(Icons.shuffle, size: 18, color: AppConstants.textSecondary),
                                tooltip: 'Next Prompt',
                                onPressed: _cyclePrompt,
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _selectedPrompt,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: AppConstants.textPrimary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Tip: Speak clearly for at least 15 to 30 seconds. Explain your thought process in complete sentences.',
                          style: TextStyle(fontSize: 12, color: AppConstants.textSecondary, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Recording Visual Stage
                  Center(
                    child: Column(
                      children: [
                        // Animated Pulse Circle
                        GestureDetector(
                          onTap: _isSubmitting
                              ? null
                              : () async {
                                  if (isRecording) {
                                    await _audioService.stopRecording();
                                  } else {
                                    await _audioService.startRecording();
                                  }
                                },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: isRecording ? 130 : 110,
                            height: isRecording ? 130 : 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isRecording
                                  ? AppConstants.errorColor.withOpacity(0.9)
                                  : (hasRecording ? AppConstants.primaryLight : AppConstants.primaryColor),
                              boxShadow: [
                                BoxShadow(
                                  color: (isRecording ? AppConstants.errorColor : AppConstants.primaryColor).withOpacity(0.3),
                                  blurRadius: isRecording ? 24 : 12,
                                  spreadRadius: isRecording ? 6 : 2,
                                ),
                              ],
                            ),
                            child: Icon(
                              isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                              size: isRecording ? 54 : 46,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Status & Duration Timer
                        Text(
                          isRecording
                              ? 'Recording... ${duration ~/ 60}:${(duration % 60).toString().padLeft(2, '0')}'
                              : (hasRecording ? 'Recording Ready (${duration}s)' : 'Tap Microphone to Speak'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isRecording ? AppConstants.errorColor : AppConstants.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isRecording ? 'Tap stop button when finished' : (hasRecording ? 'Listen or submit for analysis' : 'Allow microphone permission if prompted'),
                          style: const TextStyle(fontSize: 13, color: AppConstants.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Playback and Delete Controls (if audio recorded)
                  if (hasRecording && !isRecording && !_isSubmitting)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                                  size: 38,
                                  color: AppConstants.primaryColor,
                                ),
                                onPressed: () => _audioService.playRecording(),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isPlaying ? 'Playing actual audio...' : 'Review your recording',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                  const Text(
                                    'Uses device speaker',
                                    style: TextStyle(fontSize: 11, color: AppConstants.textSecondary),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppConstants.errorColor),
                            tooltip: 'Delete recording',
                            onPressed: () => _audioService.deleteRecording(),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Error Message Banner
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppConstants.errorColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppConstants.errorColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: AppConstants.errorColor),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: AppConstants.errorColor, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Loading State Indicator
                  if (_isSubmitting)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 14),
                          Text(
                            _statusMessage ?? 'Processing...',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppConstants.primaryColor),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'AI is transcribing audio and evaluating oral communication parameters.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: AppConstants.textSecondary),
                          ),
                        ],
                      ),
                    ),

                  // Submit Action Button
                  if (!_isSubmitting && hasRecording && !isRecording)
                    CustomButton(
                      label: 'Analyze My Speech with AI',
                      icon: Icons.analytics_outlined,
                      isLoading: _isSubmitting,
                      onPressed: _handleSubmit,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
