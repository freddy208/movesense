import 'package:hive/hive.dart';

part 'daily_stats_model.g.dart';

@HiveType(typeId: 3)
class DailyStatsModel extends HiveObject {
  @HiveField(0)
  late DateTime date;

  @HiveField(1)
  late int steps;

  @HiveField(2)
  late int stepGoal;

  @HiveField(3)
  late double distance;

  @HiveField(4)
  late double calories;

  @HiveField(5)
  late int duration;

  @HiveField(6)
  late double avgBpm;

  @HiveField(7)
  late int sessionsCount;

  @HiveField(8)
  late bool goalAchieved;

  @HiveField(9)
  late int xpEarned;

  @HiveField(10)
  late double healthScore;

  DailyStatsModel({
    DateTime? date,
    this.steps = 0,
    this.stepGoal = 10000,
    this.distance = 0.0,
    this.calories = 0.0,
    this.duration = 0,
    this.avgBpm = 0.0,
    this.sessionsCount = 0,
    this.goalAchieved = false,
    this.xpEarned = 0,
    this.healthScore = 0.0,
  }) : date = date ?? DateTime.now();

  double get goalProgress =>
      stepGoal > 0 ? (steps / stepGoal).clamp(0.0, 1.0) : 0.0;

  String get formattedDuration {
    final h = duration ~/ 3600;
    final m = (duration % 3600) ~/ 60;
    final s = duration % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}