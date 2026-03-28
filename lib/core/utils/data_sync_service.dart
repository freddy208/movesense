import 'package:hive/hive.dart';

/// Service central qui assure la cohérence des données
/// entre tous les modules de MoveSense
class DataSyncService {
  static const String _profileBox = 'user_profile_box';

  // ── CLÉ UNIQUE POUR AUJOURD'HUI ──
  static String get todayKey {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  static String dateKey(DateTime date) =>
      '${date.year}-${date.month}-${date.day}';

  // ── SAUVEGARDE PAS JOURNALIERS ──
  static Future<void> saveDailySteps(int steps) async {
    final box = await Hive.openBox(_profileBox);
    final existing =
        box.get('daily_steps_$todayKey', defaultValue: 0) as int;
    await box.put('daily_steps_$todayKey', existing + steps);
  }

  // ── LIT LES PAS D'UN JOUR ──
  static Future<int> getDailySteps({DateTime? date}) async {
    final box = await Hive.openBox(_profileBox);
    final key = dateKey(date ?? DateTime.now());
    return box.get('daily_steps_$key', defaultValue: 0) as int;
  }

  // ── LIT L'OBJECTIF ──
  static Future<int> getDailyGoal() async {
    final box = await Hive.openBox(_profileBox);
    return box.get('daily_step_goal', defaultValue: 10000) as int;
  }

  // ── LIT LE PROFIL COMPLET ──
  static Future<Map<String, dynamic>> getProfile() async {
    final box = await Hive.openBox(_profileBox);
    return {
      'name': box.get('user_name', defaultValue: 'Athlète'),
      'weight': box.get('user_weight', defaultValue: 70.0),
      'height': box.get('user_height', defaultValue: 170.0),
      'age': box.get('user_age', defaultValue: 25),
      'gender': box.get('user_gender', defaultValue: 'male'),
      'strideLength': box.get('user_stride_length', defaultValue: 0.75),
      'stepGoal': box.get('daily_step_goal', defaultValue: 10000),
      'distanceGoal': box.get('daily_distance_goal', defaultValue: 7.0),
      'caloriesGoal': box.get('daily_calories_goal', defaultValue: 500.0),
      'durationGoal': box.get('daily_duration_goal', defaultValue: 60),
    };
  }

  // ── STATISTIQUES 30 JOURS ──
  static Future<Map<String, dynamic>> getLast30DaysStats() async {
    final box = await Hive.openBox(_profileBox);
    final goal =
        box.get('daily_step_goal', defaultValue: 10000) as int;

    int totalSteps = 0;
    int activeDays = 0;
    int goalsReached = 0;
    int streak = 0;
    int currentStreak = 0;

    for (int i = 29; i >= 0; i--) {
      final date = DateTime.now().subtract(Duration(days: i));
      final key = dateKey(date);
      final steps = box.get('daily_steps_$key', defaultValue: 0) as int;

      totalSteps += steps;
      if (steps > 0) {
        activeDays++;
        if (i == 0 || currentStreak > 0) currentStreak++;
      } else {
        if (currentStreak > streak) streak = currentStreak;
        currentStreak = 0;
      }
      if (steps >= goal) goalsReached++;
    }

    if (currentStreak > streak) streak = currentStreak;

    return {
      'totalSteps': totalSteps,
      'activeDays': activeDays,
      'goalsReached': goalsReached,
      'longestStreak': streak,
      'avgSteps': activeDays > 0 ? totalSteps ~/ 30 : 0,
      'goal': goal,
    };
  }

  // ── VÉRIFIE SI OBJECTIF ATTEINT AUJOURD'HUI ──
  static Future<bool> isTodayGoalReached() async {
    final steps = await getDailySteps();
    final goal = await getDailyGoal();
    return steps >= goal;
  }
}