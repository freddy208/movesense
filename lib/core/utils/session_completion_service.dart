import 'package:hive/hive.dart';
import '../../features/gamification/data/datasources/badge_service.dart';
import '../../features/gamification/data/datasources/gamification_service.dart';
import '../../features/audio/data/datasources/audio_service.dart';
import '../../features/audio/data/datasources/notification_service.dart';
import '../../features/pedometer/data/datasources/pedometer_service.dart';
import '../../features/gps/data/datasources/gps_service.dart';

class SessionCompletionService {
  static final BadgeService _badgeService = BadgeService();
  static final GamificationService _gamificationService =
      GamificationService();

  static Future<void> onSessionComplete({
    required LiveSessionData session,
    required LiveGpsData gpsData,
  }) async {
    if (session.steps == 0) return;

    final box = await Hive.openBox('user_profile_box');
    final today = _todayKey();
    final goal = box.get('daily_step_goal', defaultValue: 10000) as int;

    // ── 1. SAUVEGARDE PAS + DURÉE JOURNALIERS ──
    final existingSteps =
        box.get('daily_steps_$today', defaultValue: 0) as int;
    final newTotalSteps = existingSteps + session.steps;
    await box.put('daily_steps_$today', newTotalSteps);

    final existingDuration =
        box.get('daily_duration_$today', defaultValue: 0) as int;
    await box.put(
        'daily_duration_$today', existingDuration + session.durationSeconds);

    // Calories
  final existingCalories =
      box.get('daily_calories_$today', defaultValue: 0.0) as double;
  await box.put('daily_calories_$today',
      existingCalories + session.calories);

    // ── 2. XP & STREAK via GamificationService UNIQUEMENT ──
    // GamificationService gère : total_sessions, total_steps,
    // total_distance, goals_reached, XP, level, streak, active_days
    final goalReached = newTotalSteps >= goal;
    final gamificationState =
        await _gamificationService.updateAfterSession(
      steps: session.steps,
      distance: gpsData.totalDistance,
      duration: session.durationSeconds,
      goalReached: goalReached,
    );

    // ── 3. LIT LES TOTAUX DEPUIS GamificationService (pas de doublon) ──
    final gamifBox = await Hive.openBox('gamification_box');
    final totalStepsAll =
        gamifBox.get('total_steps', defaultValue: 0) as int;
    final totalDistAll =
        gamifBox.get('total_distance', defaultValue: 0.0) as double;
    final totalSessions =
        gamifBox.get('total_sessions', defaultValue: 0) as int;
    final goalsReached =
        gamifBox.get('goals_reached', defaultValue: 0) as int;

    // ── 4. VÉRIFICATION BADGES ──
    final newBadges = await _badgeService.checkAndUnlock(
      sessionSteps: session.steps,
      sessionDistance: gpsData.totalDistance,
      sessionDuration: session.durationSeconds,
      totalSteps: totalStepsAll,
      totalDistance: totalDistAll,
      totalSessions: totalSessions,
      currentStreak: gamificationState.currentStreak,
      goalsReached: goalsReached,
      sessionSpeed: gpsData.currentSpeed,
      sessionTime: DateTime.now(),
    );

    // ── 5. AUDIO + NOTIF BADGES ──
    for (final badge in newBadges) {
      await AudioService().playSound(AppSound.badge);
      await NotificationService.notifyBadgeUnlocked(badge.name);
    }

    // ── 6. AUDIO + NOTIF NIVEAU ──
    final previousLevel =
        gamifBox.get('current_level', defaultValue: 1) as int;
    if (gamificationState.currentLevel > previousLevel) {
      await AudioService().playSound(AppSound.levelUp);
      await NotificationService.notifyLevelUp(
        gamificationState.currentLevel,
        gamificationState.levelTitle,
      );
      await gamifBox.put('current_level', gamificationState.currentLevel);
    }

    // ── 7. AUDIO + NOTIF OBJECTIF ──
    if (goalReached) {
      await AudioService().playSound(AppSound.success);
      await NotificationService.notifyGoalReached(newTotalSteps);
    }

    // ── 8. SAUVEGARDE SESSION GPS ──
    final gpsBox = await Hive.openBox('gps_sessions');
    final sessionKey = 'session_${DateTime.now().millisecondsSinceEpoch}';
    await gpsBox.put(sessionKey, {
      'date': DateTime.now().toIso8601String(),
      'points': gpsData.points.map((p) => p.toMap()).toList(),
      'distance': gpsData.totalDistance,
      'duration': session.durationSeconds,
      'steps': session.steps,
      'calories': session.calories,
      'avgBpm': 0,
    });

    // ── 9. ACTIVE DAYS ──
    final activeDays = List<String>.from(
      gamifBox.get('active_days', defaultValue: <String>[]),
    );
    if (!activeDays.contains(today)) {
      activeDays.add(today);
      await gamifBox.put('active_days', activeDays);
    }
  }

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }
}