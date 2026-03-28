import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../../../core/theme/app_theme.dart';

// ═══════════════════════════════════════
// MODÈLE ÉTAT GAMIFICATION
// ═══════════════════════════════════════
class GamificationState {
  final int totalXp;
  final int currentLevel;
  final int currentStreak;
  final int longestStreak;
  final int goalsReached;
  final int totalSessions;
  final double totalDistance;
  final int totalSteps;
  final int jokerUsedThisMonth;
  final DateTime lastActiveDate;
  final List<String> activeDays; // 'YYYY-MM-DD'

  const GamificationState({
    this.totalXp = 0,
    this.currentLevel = 1,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.goalsReached = 0,
    this.totalSessions = 0,
    this.totalDistance = 0.0,
    this.totalSteps = 0,
    this.jokerUsedThisMonth = 0,
    required this.lastActiveDate,
    this.activeDays = const [],
  });

  // XP requis par niveau
  static const List<int> levelThresholds = [
    0, 500, 1500, 3000, 6000, 10000, 15000, 22000, 30000, 50000,
  ];

  static const List<String> levelTitles = [
    'Débutant', 'Marcheur', 'Actif', 'Sportif', 'Athlète',
    'Champion', 'Expert', 'Maître', 'Légende', 'Elite Runner',
  ];

  static const List<String> levelEmojis = [
    '🌱', '🚶', '🏃', '⚡', '🔥', '🏆', '💎', '👑', '🌟', '🚀',
  ];

  static const List<Color> levelColors = [
    Color(0xFF6B7280),
    AppColors.activeBlue,
    AppColors.successGreen,
    AppColors.energyOrange,
    Color(0xFFFF6B35),
    Color(0xFFFFD700),
    Color(0xFF9B59B6),
    Color(0xFFE74C3C),
    Color(0xFF1ABC9C),
    Color(0xFFFFD700),
  ];

  double get levelProgress {
    if (currentLevel >= levelThresholds.length) return 1.0;
    final current = levelThresholds[currentLevel - 1];
    final next = levelThresholds[currentLevel];
    return ((totalXp - current) / (next - current)).clamp(0.0, 1.0);
  }

  int get xpForNextLevel {
    if (currentLevel >= levelThresholds.length) return 0;
    return levelThresholds[currentLevel] - totalXp;
  }

  String get levelTitle => currentLevel <= levelTitles.length
      ? levelTitles[currentLevel - 1]
      : 'Elite Runner';

  String get levelEmoji => currentLevel <= levelEmojis.length
      ? levelEmojis[currentLevel - 1]
      : '🚀';

  Color get levelColor => currentLevel <= levelColors.length
      ? levelColors[currentLevel - 1]
      : AppColors.energyOrange;

  GamificationState copyWith({
    int? totalXp,
    int? currentLevel,
    int? currentStreak,
    int? longestStreak,
    int? goalsReached,
    int? totalSessions,
    double? totalDistance,
    int? totalSteps,
    int? jokerUsedThisMonth,
    DateTime? lastActiveDate,
    List<String>? activeDays,
  }) {
    return GamificationState(
      totalXp: totalXp ?? this.totalXp,
      currentLevel: currentLevel ?? this.currentLevel,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      goalsReached: goalsReached ?? this.goalsReached,
      totalSessions: totalSessions ?? this.totalSessions,
      totalDistance: totalDistance ?? this.totalDistance,
      totalSteps: totalSteps ?? this.totalSteps,
      jokerUsedThisMonth: jokerUsedThisMonth ?? this.jokerUsedThisMonth,
      lastActiveDate: lastActiveDate ?? this.lastActiveDate,
      activeDays: activeDays ?? this.activeDays,
    );
  }
}

// ═══════════════════════════════════════
// GAMIFICATION SERVICE
// ═══════════════════════════════════════
class GamificationService {
  static const String _boxName = 'gamification_box';

  Future<Box> get _box async => Hive.openBox(_boxName);

  // ── CHARGEMENT ──
  Future<GamificationState> loadState() async {
    final box = await _box;
    final activeDays = List<String>.from(
      box.get('active_days', defaultValue: <String>[]),
    );
    return GamificationState(
      totalXp: box.get('total_xp', defaultValue: 0),
      currentLevel: box.get('current_level', defaultValue: 1),
      currentStreak: box.get('current_streak', defaultValue: 0),
      longestStreak: box.get('longest_streak', defaultValue: 0),
      goalsReached: box.get('goals_reached', defaultValue: 0),
      totalSessions: box.get('total_sessions', defaultValue: 0),
      totalDistance: box.get('total_distance', defaultValue: 0.0),
      totalSteps: box.get('total_steps', defaultValue: 0),
      jokerUsedThisMonth: box.get('joker_used', defaultValue: 0),
      lastActiveDate: DateTime.fromMillisecondsSinceEpoch(
        box.get('last_active', defaultValue: DateTime(2000).millisecondsSinceEpoch),
      ),
      activeDays: activeDays,
    );
  }

  // ── SAUVEGARDE ──
  Future<void> _saveState(GamificationState state) async {
    final box = await _box;
    await box.putAll({
      'total_xp': state.totalXp,
      'current_level': state.currentLevel,
      'current_streak': state.currentStreak,
      'longest_streak': state.longestStreak,
      'goals_reached': state.goalsReached,
      'total_sessions': state.totalSessions,
      'total_distance': state.totalDistance,
      'total_steps': state.totalSteps,
      'joker_used': state.jokerUsedThisMonth,
      'last_active': state.lastActiveDate.millisecondsSinceEpoch,
      'active_days': state.activeDays,
    });
  }

  // ── MISE À JOUR APRÈS SESSION ──
  Future<GamificationState> updateAfterSession({
    required int steps,
    required double distance,
    required int duration,
    required bool goalReached,
  }) async {
    var state = await loadState();

    // XP calculé
    int xpEarned = steps ~/ 10; // 1 XP par 10 pas
    if (goalReached) xpEarned += 200; // bonus objectif
    if (duration >= 1800) xpEarned += 100; // bonus 30min
    if (duration >= 3600) xpEarned += 200; // bonus 1h
    if (steps >= 10000) xpEarned += 150; // bonus 10k pas

    final newXp = state.totalXp + xpEarned;
    final newLevel = _calculateLevel(newXp);
    final newSessions = state.totalSessions + 1;
    final newTotalSteps = state.totalSteps + steps;
    final newTotalDist = state.totalDistance + distance;
    final newGoals = goalReached ? state.goalsReached + 1 : state.goalsReached;

    // Streak
    final streakResult = _updateStreak(state);

    // Active days
    final today = _dateKey(DateTime.now());
    final activeDays = List<String>.from(state.activeDays);
    if (!activeDays.contains(today)) activeDays.add(today);

    final newState = state.copyWith(
      totalXp: newXp,
      currentLevel: newLevel,
      currentStreak: streakResult['streak'],
      longestStreak: streakResult['longest'],
      goalsReached: newGoals,
      totalSessions: newSessions,
      totalDistance: newTotalDist,
      totalSteps: newTotalSteps,
      lastActiveDate: DateTime.now(),
      activeDays: activeDays,
    );

    await _saveState(newState);
    return newState;
  }

  // ── CALCUL NIVEAU ──
  int _calculateLevel(int xp) {
    int level = 1;
    for (int i = 0; i < GamificationState.levelThresholds.length; i++) {
      if (xp >= GamificationState.levelThresholds[i]) level = i + 1;
    }
    return level.clamp(1, 10);
  }

  // ── CALCUL STREAK ──
  Map<String, int> _updateStreak(GamificationState state) {
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    final lastActive = state.lastActiveDate;

    final isYesterday = _dateKey(lastActive) == _dateKey(yesterday);
    final isToday = _dateKey(lastActive) == _dateKey(today);

    int newStreak = state.currentStreak;

    if (isToday) {
      // Déjà actif aujourd'hui
      newStreak = state.currentStreak;
    } else if (isYesterday) {
      // Continuation du streak
      newStreak = state.currentStreak + 1;
    } else {
      // Streak cassé — vérifie joker
      final daysMissed = today.difference(lastActive).inDays;
      if (daysMissed <= 2 && state.jokerUsedThisMonth < 1) {
        // Utilise le joker
        newStreak = state.currentStreak + 1;
      } else {
        newStreak = 1; // Repart à 1
      }
    }

    final longest = newStreak > state.longestStreak
        ? newStreak
        : state.longestStreak;

    return {'streak': newStreak, 'longest': longest};
  }

  String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}