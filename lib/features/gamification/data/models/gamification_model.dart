import 'package:hive/hive.dart';

part 'gamification_model.g.dart';

@HiveType(typeId: 5)
class GamificationModel extends HiveObject {
  @HiveField(0)
  late int totalXp;

  @HiveField(1)
  late int currentLevel;

  @HiveField(2)
  late int currentStreak;

  @HiveField(3)
  late int longestStreak;

  @HiveField(4)
  late int jokerUsedThisMonth;

  @HiveField(5)
  late DateTime lastActiveDate;

  @HiveField(6)
  late List<String> unlockedBadgeKeys;

  GamificationModel({
    this.totalXp = 0,
    this.currentLevel = 1,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.jokerUsedThisMonth = 0,
    DateTime? lastActiveDate,
    List<String>? unlockedBadgeKeys,
  })  : lastActiveDate = lastActiveDate ?? DateTime(2000),
        unlockedBadgeKeys = unlockedBadgeKeys ?? [];

  static const List<int> levelThresholds = [
    0, 500, 1500, 3000, 6000, 10000, 15000, 22000, 30000, 50000,
  ];

  static const List<String> levelTitles = [
    'Débutant', 'Marcheur', 'Actif', 'Sportif', 'Athlète',
    'Champion', 'Expert', 'Maître', 'Légende', 'Elite Runner',
  ];

  double get levelProgress {
    if (currentLevel >= levelThresholds.length) return 1.0;
    final current = levelThresholds[currentLevel - 1];
    final next = levelThresholds[currentLevel];
    return ((totalXp - current) / (next - current)).clamp(0.0, 1.0);
  }

  String get levelTitle => currentLevel <= levelTitles.length
      ? levelTitles[currentLevel - 1]
      : 'Elite Runner';
}