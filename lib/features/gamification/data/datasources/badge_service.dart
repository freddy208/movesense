import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../../../core/theme/app_theme.dart';

// ═══════════════════════════════════════
// MODÈLE BADGE
// ═══════════════════════════════════════
class Badge {
  final String key;
  final String name;
  final String description;
  final String emoji;
  final String category;
  final bool isSecret;
  final int xpReward;
  final int requiredValue;
  final Color color;
  bool isUnlocked;
  DateTime? unlockedAt;

  Badge({
    required this.key,
    required this.name,
    required this.description,
    required this.emoji,
    required this.category,
    this.isSecret = false,
    this.xpReward = 50,
    this.requiredValue = 0,
    required this.color,
    this.isUnlocked = false,
    this.unlockedAt,
  });
}

// ═══════════════════════════════════════
// CATALOGUE 25 BADGES
// ═══════════════════════════════════════
class BadgeCatalog {
  static List<Badge> get all => [
    // ── ÉTAPES (Steps) ──
    Badge(
      key: 'first_step',
      name: 'Premier Pas',
      description: 'Effectuer son premier pas',
      emoji: '👟',
      category: 'steps',
      xpReward: 100,
      requiredValue: 1,
      color: AppColors.successGreen,
    ),
    Badge(
      key: 'steps_500',
      name: 'Échauffement',
      description: 'Atteindre 500 pas en une session',
      emoji: '🔥',
      category: 'steps',
      xpReward: 50,
      requiredValue: 500,
      color: const Color(0xFFFF6B35),
    ),
    Badge(
      key: 'steps_1000',
      name: 'Marcheur',
      description: 'Atteindre 1 000 pas en une session',
      emoji: '🚶',
      category: 'steps',
      xpReward: 75,
      requiredValue: 1000,
      color: AppColors.activeBlue,
    ),
    Badge(
      key: 'steps_5000',
      name: 'Randonneur',
      description: 'Atteindre 5 000 pas en une session',
      emoji: '🏃',
      category: 'steps',
      xpReward: 150,
      requiredValue: 5000,
      color: const Color(0xFF9B59B6),
    ),
    Badge(
      key: 'steps_10000',
      name: 'Elite Marcheur',
      description: 'Atteindre 10 000 pas en une journée',
      emoji: '🏆',
      category: 'steps',
      xpReward: 300,
      requiredValue: 10000,
      color: AppColors.energyOrange,
    ),
    Badge(
      key: 'steps_20000',
      name: 'Ultra Marcheur',
      description: 'Atteindre 20 000 pas en une journée',
      emoji: '⚡',
      category: 'steps',
      xpReward: 500,
      requiredValue: 20000,
      color: const Color(0xFFFFD700),
    ),
    Badge(
      key: 'steps_total_100k',
      name: 'Centurion',
      description: 'Cumuler 100 000 pas au total',
      emoji: '💯',
      category: 'steps',
      xpReward: 1000,
      requiredValue: 100000,
      color: const Color(0xFFFFD700),
    ),

    // ── DISTANCE ──
    Badge(
      key: 'distance_1km',
      name: 'Premier Kilomètre',
      description: 'Parcourir 1 km en une session',
      emoji: '📍',
      category: 'distance',
      xpReward: 100,
      requiredValue: 1,
      color: AppColors.successGreen,
    ),
    Badge(
      key: 'distance_5km',
      name: 'Routard',
      description: 'Parcourir 5 km en une session',
      emoji: '🗺️',
      category: 'distance',
      xpReward: 200,
      requiredValue: 5,
      color: AppColors.activeBlue,
    ),
    Badge(
      key: 'distance_10km',
      name: 'Explorateur',
      description: 'Parcourir 10 km en une session',
      emoji: '🌍',
      category: 'distance',
      xpReward: 400,
      requiredValue: 10,
      color: AppColors.energyOrange,
    ),
    Badge(
      key: 'distance_total_50km',
      name: 'Globe-Trotteur',
      description: 'Cumuler 50 km au total',
      emoji: '✈️',
      category: 'distance',
      xpReward: 800,
      requiredValue: 50,
      color: const Color(0xFFFFD700),
    ),

    // ── STREAK ──
    Badge(
      key: 'streak_3',
      name: 'Régulier',
      description: '3 jours consécutifs actifs',
      emoji: '📅',
      category: 'streak',
      xpReward: 150,
      requiredValue: 3,
      color: AppColors.successGreen,
    ),
    Badge(
      key: 'streak_7',
      name: 'Semaine Parfaite',
      description: '7 jours consécutifs actifs',
      emoji: '🌟',
      category: 'streak',
      xpReward: 350,
      requiredValue: 7,
      color: AppColors.energyOrange,
    ),
    Badge(
      key: 'streak_30',
      name: 'Mois de Feu',
      description: '30 jours consécutifs actifs',
      emoji: '🔥',
      category: 'streak',
      xpReward: 1500,
      requiredValue: 30,
      color: AppColors.alertRed,
    ),

    // ── SESSION ──
    Badge(
      key: 'session_10',
      name: 'Habitué',
      description: 'Compléter 10 sessions',
      emoji: '📊',
      category: 'session',
      xpReward: 200,
      requiredValue: 10,
      color: AppColors.activeBlue,
    ),
    Badge(
      key: 'session_30min',
      name: 'Endurant',
      description: 'Session de 30 minutes',
      emoji: '⏱️',
      category: 'session',
      xpReward: 150,
      requiredValue: 1800,
      color: const Color(0xFF9B59B6),
    ),
    Badge(
      key: 'session_1h',
      name: 'Marathonien',
      description: 'Session d\'1 heure non-stop',
      emoji: '🏅',
      category: 'session',
      xpReward: 400,
      requiredValue: 3600,
      color: AppColors.energyOrange,
    ),
    Badge(
      key: 'goal_reached',
      name: 'Objectif Atteint',
      description: 'Atteindre son objectif journalier',
      emoji: '🎯',
      category: 'session',
      xpReward: 200,
      requiredValue: 1,
      color: AppColors.successGreen,
    ),
    Badge(
      key: 'goal_5x',
      name: 'Consistant',
      description: 'Atteindre l\'objectif 5 fois',
      emoji: '🥇',
      category: 'session',
      xpReward: 500,
      requiredValue: 5,
      color: const Color(0xFFFFD700),
    ),

    // ── SECRETS (5) ──
    Badge(
      key: 'night_walker',
      name: 'Fantôme de la Nuit',
      description: '??? — Badge secret découvert !',
      emoji: '🌙',
      category: 'secret',
      isSecret: true,
      xpReward: 300,
      requiredValue: 0,
      color: const Color(0xFF6C3483),
    ),
    Badge(
      key: 'early_bird',
      name: 'Lève-Tôt',
      description: '??? — Badge secret découvert !',
      emoji: '🌅',
      category: 'secret',
      isSecret: true,
      xpReward: 300,
      requiredValue: 0,
      color: const Color(0xFFF39C12),
    ),
    Badge(
      key: 'speed_demon',
      name: 'Démon de Vitesse',
      description: '??? — Badge secret découvert !',
      emoji: '💨',
      category: 'secret',
      isSecret: true,
      xpReward: 400,
      requiredValue: 0,
      color: const Color(0xFF2980B9),
    ),
    Badge(
      key: 'ultra_session',
      name: 'Sans Limite',
      description: '??? — Badge secret découvert !',
      emoji: '🦾',
      category: 'secret',
      isSecret: true,
      xpReward: 600,
      requiredValue: 0,
      color: AppColors.alertRed,
    ),
    Badge(
      key: 'comeback',
      name: 'Le Retour',
      description: '??? — Badge secret découvert !',
      emoji: '🔄',
      category: 'secret',
      isSecret: true,
      xpReward: 250,
      requiredValue: 0,
      color: AppColors.activeBlue,
    ),
  ];
}

// ═══════════════════════════════════════
// BADGE SERVICE
// ═══════════════════════════════════════
class BadgeService {
  static const String _boxName = 'badges_box';

  Future<Box> get _box async => Hive.openBox(_boxName);

  // Charge les badges avec leur état débloqué
  Future<List<Badge>> loadBadges() async {
    final box = await _box;
    final badges = BadgeCatalog.all;

    for (final badge in badges) {
      final data = box.get(badge.key);
      if (data != null) {
        badge.isUnlocked = data['unlocked'] ?? false;
        final ts = data['unlockedAt'];
        if (ts != null) {
          badge.unlockedAt = DateTime.fromMillisecondsSinceEpoch(ts);
        }
      }
    }
    return badges;
  }

  // Vérifie et débloque les badges après une session
  Future<List<Badge>> checkAndUnlock({
    required int sessionSteps,
    required double sessionDistance,
    required int sessionDuration,
    required int totalSteps,
    required double totalDistance,
    required int totalSessions,
    required int currentStreak,
    required int goalsReached,
    required double sessionSpeed,
    required DateTime sessionTime,
  }) async {
    final box = await _box;
    final badges = await loadBadges();
    final List<Badge> newlyUnlocked = [];

    for (final badge in badges) {
      if (badge.isUnlocked) continue;

      bool shouldUnlock = false;

      switch (badge.key) {
        // Steps session
        case 'first_step': shouldUnlock = sessionSteps >= 1; break;
        case 'steps_500': shouldUnlock = sessionSteps >= 500; break;
        case 'steps_1000': shouldUnlock = sessionSteps >= 1000; break;
        case 'steps_5000': shouldUnlock = sessionSteps >= 5000; break;
        case 'steps_10000': shouldUnlock = totalSteps >= 10000; break;
        case 'steps_20000': shouldUnlock = totalSteps >= 20000; break;
        case 'steps_total_100k': shouldUnlock = totalSteps >= 100000; break;

        // Distance
        case 'distance_1km': shouldUnlock = sessionDistance >= 1.0; break;
        case 'distance_5km': shouldUnlock = sessionDistance >= 5.0; break;
        case 'distance_10km': shouldUnlock = sessionDistance >= 10.0; break;
        case 'distance_total_50km': shouldUnlock = totalDistance >= 50.0; break;

        // Streak
        case 'streak_3': shouldUnlock = currentStreak >= 3; break;
        case 'streak_7': shouldUnlock = currentStreak >= 7; break;
        case 'streak_30': shouldUnlock = currentStreak >= 30; break;

        // Sessions
        case 'session_10': shouldUnlock = totalSessions >= 10; break;
        case 'session_30min': shouldUnlock = sessionDuration >= 1800; break;
        case 'session_1h': shouldUnlock = sessionDuration >= 3600; break;
        case 'goal_reached': shouldUnlock = goalsReached >= 1; break;
        case 'goal_5x': shouldUnlock = goalsReached >= 5; break;

        // Secrets
        case 'night_walker':
          shouldUnlock = sessionTime.hour >= 22 || sessionTime.hour < 5;
          break;
        case 'early_bird':
          shouldUnlock = sessionTime.hour >= 5 && sessionTime.hour < 7;
          break;
        case 'speed_demon':
          shouldUnlock = sessionSpeed >= 8.0;
          break;
        case 'ultra_session':
          shouldUnlock = sessionDuration >= 7200; // 2h
          break;
        case 'comeback':
          shouldUnlock = totalSessions > 1;
          break;
      }

      if (shouldUnlock) {
        badge.isUnlocked = true;
        badge.unlockedAt = DateTime.now();
        await box.put(badge.key, {
          'unlocked': true,
          'unlockedAt': DateTime.now().millisecondsSinceEpoch,
        });
        newlyUnlocked.add(badge);
      }
    }

    return newlyUnlocked;
  }

  Future<int> getUnlockedCount() async {
    final badges = await loadBadges();
    return badges.where((b) => b.isUnlocked).length;
  }
}