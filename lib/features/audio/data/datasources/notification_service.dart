import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive/hive.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  static const String _boxName = 'notifications_box';
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  // ── INITIALISATION ──
  static Future<void> initialize() async {
    if (_initialized) return;
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    _initialized = true;
  }

  // ── CANAL ANDROID ──
  static AndroidNotificationDetails get _androidChannel =>
      AndroidNotificationDetails(
        'movesense_channel',
        'MoveSense',
        channelDescription: 'Notifications MoveSense',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        color: const Color(0xFFE87722),
        enableVibration: true,
        playSound: true,
      );

  // ── NOTIFICATION IMMÉDIATE ──
  static Future<void> showInstant({
    required int id,
    required String title,
    required String body,
  }) async {
    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(android: _androidChannel),
    );
  }

  // ── OBJECTIF ATTEINT ──
  static Future<void> notifyGoalReached(int steps) async {
    await showInstant(
      id: 1,
      title: '🎯 Objectif atteint !',
      body: 'Félicitations ! Tu as atteint $steps pas aujourd\'hui !',
    );
  }

  // ── BADGE DÉBLOQUÉ ──
  static Future<void> notifyBadgeUnlocked(String badgeName) async {
    await showInstant(
      id: 2,
      title: '🏆 Badge débloqué !',
      body: 'Tu as obtenu le badge "$badgeName". Bravo !',
    );
  }

  // ── NIVEAU SUPÉRIEUR ──
  static Future<void> notifyLevelUp(int level, String levelTitle) async {
    await showInstant(
      id: 3,
      title: '⬆️ Niveau $level atteint !',
      body: 'Tu es maintenant "$levelTitle". Continue !',
    );
  }

  // ── RAPPEL QUOTIDIEN ──
  static Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    await _plugin.cancelAll();

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      10,
      '👟 Il est temps de bouger !',
      'Tu n\'as pas encore atteint ton objectif. Allez, quelques pas !',
      scheduled,
      NotificationDetails(android: _androidChannel),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    final box = await Hive.openBox(_boxName);
    await box.putAll({
      'reminder_hour': hour,
      'reminder_minute': minute,
      'reminder_enabled': true,
    });
  }

  // ── ANNULER TOUT ──
  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
    final box = await Hive.openBox(_boxName);
    await box.put('reminder_enabled', false);
  }

  // ── CHARGER PARAMÈTRES ──
  static Future<Map<String, dynamic>> loadSettings() async {
    final box = await Hive.openBox(_boxName);
    return {
      'enabled': box.get('reminder_enabled', defaultValue: false),
      'hour': box.get('reminder_hour', defaultValue: 8),
      'minute': box.get('reminder_minute', defaultValue: 0),
    };
  }
}