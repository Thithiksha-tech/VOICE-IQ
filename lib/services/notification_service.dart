import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Local "your analysis is ready" notifications. Tapping one calls [onOpenSession].
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static void Function(int sessionId)? onOpenSession;

  static const _channel = AndroidNotificationDetails(
    'analysis_results',
    'Speech analysis results',
    channelDescription: 'Tells you when your speech analysis is ready',
    importance: Importance.high,
    priority: Priority.high,
  );

  static Future<void> init() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) {
        final sessionId = int.tryParse(response.payload ?? '');
        if (sessionId != null) onOpenSession?.call(sessionId);
      },
    );
  }

  /// Asks for permission on Android 13+; earlier versions allow notifications by default.
  static Future<void> requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> show({required int id, required String title, required String body, int? sessionId}) async {
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(android: _channel),
        payload: sessionId?.toString(),
      );
    } catch (e) {
      debugPrint('Notification failed: $e');
    }
  }
}
