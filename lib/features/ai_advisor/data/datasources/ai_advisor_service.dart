import 'dart:math';
import 'package:hive/hive.dart';

// ═══════════════════════════════════════
// MODÈLES
// ═══════════════════════════════════════
class AIAdvice {
  final String title;
  final String message;
  final String emoji;
  final String category;
  final int priority;

  const AIAdvice({
    required this.title,
    required this.message,
    required this.emoji,
    required this.category,
    this.priority = 0,
  });
}

class AIReport {
  final int healthScore;
  final String healthLabel;
  final List<AIAdvice> advices;
  final double goalPrediction; // 0.0 - 1.0
  final String predictionMessage;
  final List<int> weeklySteps; // 7 derniers jours
  final List<double> weeklyScores; // scores 7 derniers jours
  final double trend; // positif = amélioration

  const AIReport({
    required this.healthScore,
    required this.healthLabel,
    required this.advices,
    required this.goalPrediction,
    required this.predictionMessage,
    required this.weeklySteps,
    required this.weeklyScores,
    required this.trend,
  });
}

// ═══════════════════════════════════════
// AI ADVISOR SERVICE
// ═══════════════════════════════════════
class AIAdvisorService {
  // ── GÉNÈRE LE RAPPORT COMPLET ──
  Future<AIReport> generateReport() async {
    final history = await _loadHistory();
    final profile = await _loadProfile();

    final weeklySteps = _getWeeklySteps(history);
    final weeklyScores = _calculateWeeklyScores(weeklySteps, profile['goal']);
    final healthScore = _calculateHealthScore(weeklySteps, profile);
    final prediction = _predictGoal(weeklySteps, profile['goal']);
    final advices = _generateAdvices(weeklySteps, history, profile);
    final trend = _calculateTrend(weeklyScores);

    return AIReport(
      healthScore: healthScore,
      healthLabel: _getHealthLabel(healthScore),
      advices: advices,
      goalPrediction: prediction['probability'],
      predictionMessage: prediction['message'],
      weeklySteps: weeklySteps,
      weeklyScores: weeklyScores,
      trend: trend,
    );
  }

  // ── CHARGEMENT DONNÉES ──
  Future<Map<String, dynamic>> _loadHistory() async {
    final box = await Hive.openBox('user_profile_box');
    final Map<String, dynamic> history = {};

    for (int i = 0; i < 30; i++) {
      final date = DateTime.now().subtract(Duration(days: i));
      final key = 'daily_steps_${date.year}-${date.month}-${date.day}';
      final steps = box.get(key, defaultValue: 0) as int;
      history[key] = steps;
    }

    return history;
  }

  Future<Map<String, dynamic>> _loadProfile() async {
    final box = await Hive.openBox('user_profile_box');
    return {
      'goal': box.get('daily_step_goal', defaultValue: 10000) as int,
      'weight': box.get('user_weight', defaultValue: 70.0) as double,
      'age': box.get('user_age', defaultValue: 25) as int,
      'name': box.get('user_name', defaultValue: 'Athlète') as String,
    };
  }

  // ── STEPS 7 DERNIERS JOURS ──
  List<int> _getWeeklySteps(Map<String, dynamic> history) {
    final steps = <int>[];
    for (int i = 6; i >= 0; i--) {
      final date = DateTime.now().subtract(Duration(days: i));
      final key = 'daily_steps_${date.year}-${date.month}-${date.day}';
      steps.add(history[key] ?? 0);
    }
    return steps;
  }

  // ── SCORES HEBDOMADAIRES ──
  List<double> _calculateWeeklyScores(List<int> steps, int goal) {
    return steps.map((s) {
      if (goal == 0) return 0.0;
      return (s / goal * 100).clamp(0.0, 100.0);
    }).toList();
  }

  // ── SCORE SANTÉ 0-100 ──
  int _calculateHealthScore(
      List<int> weeklySteps, Map<String, dynamic> profile) {
    final goal = profile['goal'] as int;
    if (goal == 0) return 0;

    // Composante 1 : moyenne hebdomadaire (40%)
    final avg = weeklySteps.isEmpty
        ? 0
        : weeklySteps.reduce((a, b) => a + b) / weeklySteps.length;
    final avgScore = (avg / goal * 100).clamp(0.0, 100.0) * 0.40;

    // Composante 2 : régularité (jours actifs sur 7) (30%)
    final activeDays = weeklySteps.where((s) => s > 0).length;
    final regularityScore = (activeDays / 7 * 100) * 0.30;

    // Composante 3 : objectifs atteints (30%)
    final goalsHit = weeklySteps.where((s) => s >= goal).length;
    final goalScore = (goalsHit / 7 * 100) * 0.30;

    return (avgScore + regularityScore + goalScore).toInt().clamp(0, 100);
  }

  String _getHealthLabel(int score) {
    if (score >= 80) return 'Excellent 🔥';
    if (score >= 60) return 'Très bien 💪';
    if (score >= 40) return 'Bien 👍';
    if (score >= 20) return 'À améliorer 📈';
    return 'Débutant 🌱';
  }

  // ── PRÉDICTION OBJECTIF (régression linéaire) ──
  Map<String, dynamic> _predictGoal(List<int> weeklySteps, int goal) {
    if (weeklySteps.isEmpty || goal == 0) {
      return {'probability': 0.5, 'message': 'Pas assez de données'};
    }

    // Régression linéaire simple sur 7 jours
    final n = weeklySteps.length;
    final xMean = (n - 1) / 2;
    final yMean =
        weeklySteps.reduce((a, b) => a + b) / n;

    double numerator = 0;
    double denominator = 0;
    for (int i = 0; i < n; i++) {
      numerator += (i - xMean) * (weeklySteps[i] - yMean);
      denominator += pow(i - xMean, 2);
    }

    final slope = denominator != 0 ? numerator / denominator : 0;
    final intercept = yMean - slope * xMean;
    final predicted = (intercept + slope * n).clamp(0.0, double.infinity);

    final probability = (predicted / goal).clamp(0.0, 1.0);

    String message;
    if (probability >= 0.9) {
      message = 'Vous allez très probablement atteindre votre objectif ! 🎯';
    } else if (probability >= 0.6) {
      message = 'Bonne progression, continuez à ce rythme ! 💪';
    } else if (probability >= 0.3) {
      message = 'Encore un effort, vous pouvez le faire ! ⚡';
    } else {
      message = 'Commencez dès maintenant pour rattraper ! 🚀';
    }

    return {'probability': probability, 'message': message};
  }

  // ── TENDANCE ──
  double _calculateTrend(List<double> scores) {
    if (scores.length < 2) return 0;
    final recent = scores.sublist(scores.length ~/ 2);
    final older = scores.sublist(0, scores.length ~/ 2);
    final recentAvg = recent.reduce((a, b) => a + b) / recent.length;
    final olderAvg = older.reduce((a, b) => a + b) / older.length;
    return recentAvg - olderAvg;
  }

  // ═══════════════════════════════════════
  // MOTEUR DE RÈGLES — 3 CONSEILS
  // ═══════════════════════════════════════
  List<AIAdvice> _generateAdvices(
    List<int> weeklySteps,
    Map<String, dynamic> history,
    Map<String, dynamic> profile,
  ) {
    final List<AIAdvice> candidates = [];
    final goal = profile['goal'] as int;
    final avg = weeklySteps.isEmpty
        ? 0
        : weeklySteps.reduce((a, b) => a + b) / weeklySteps.length;
    final activeDays = weeklySteps.where((s) => s > 0).length;
    final goalsHit = weeklySteps.where((s) => s >= goal).length;
    final today = weeklySteps.isNotEmpty ? weeklySteps.last : 0;

    // Règle 1 : Moyenne en dessous de l'objectif
    if (avg < goal * 0.7) {
      candidates.add(const AIAdvice(
        title: 'Augmentez votre rythme',
        message:
            'Votre moyenne hebdomadaire est en dessous de votre objectif. '
            'Essayez d\'ajouter une marche de 15 minutes après le repas.',
        emoji: '📈',
        category: 'motivation',
        priority: 3,
      ));
    }

    // Règle 2 : Très bonne moyenne
    if (avg >= goal * 1.1) {
      candidates.add(AIAdvice(
        title: 'Performance excellente !',
        message:
            'Vous dépassez régulièrement votre objectif. '
            'Envisagez d\'augmenter votre objectif à ${(goal * 1.1).toInt()} pas.',
        emoji: '🚀',
        category: 'progression',
        priority: 2,
      ));
    }

    // Règle 3 : Peu de jours actifs
    if (activeDays <= 3) {
      candidates.add(const AIAdvice(
        title: 'Soyez plus régulier',
        message:
            'Vous n\'avez été actif que quelques jours cette semaine. '
            'La régularité est plus importante que l\'intensité.',
        emoji: '📅',
        category: 'regularite',
        priority: 3,
      ));
    }

    // Règle 4 : Objectifs souvent atteints
    if (goalsHit >= 5) {
      candidates.add(const AIAdvice(
        title: 'Constance remarquable',
        message:
            'Vous atteignez votre objectif presque chaque jour. '
            'Votre discipline est exemplaire, continuez !',
        emoji: '🏆',
        category: 'felicitation',
        priority: 1,
      ));
    }

    // Règle 5 : Aujourd'hui en retard
    if (today < goal * 0.3) {
      candidates.add(const AIAdvice(
        title: 'Démarrez votre journée',
        message:
            'Vous avez encore beaucoup de pas à faire aujourd\'hui. '
            'Une marche de 20 minutes peut vous relancer.',
        emoji: '⏰',
        category: 'urgence',
        priority: 4,
      ));
    }

    // Règle 6 : Inactivité plusieurs jours
    final lastDays = weeklySteps.sublist(
        weeklySteps.length > 3 ? weeklySteps.length - 3 : 0);
    if (lastDays.every((s) => s < 1000)) {
      candidates.add(const AIAdvice(
        title: 'Reprenez l\'activité',
        message:
            'Vous n\'avez pas beaucoup bougé ces derniers jours. '
            'Même une courte marche de 10 minutes fait la différence.',
        emoji: '💡',
        category: 'relance',
        priority: 5,
      ));
    }

    // Règle 7 : Progression en hausse
    final trend = _calculateTrend(
      _calculateWeeklyScores(weeklySteps, goal),
    );
    if (trend > 10) {
      candidates.add(const AIAdvice(
        title: 'Tendance positive !',
        message:
            'Votre activité est en hausse cette semaine. '
            'Gardez cette énergie et maintenez le cap !',
        emoji: '📊',
        category: 'tendance',
        priority: 2,
      ));
    }

    // Conseil santé générique si peu de données
    if (candidates.isEmpty) {
      candidates.add(const AIAdvice(
        title: 'Commencez votre aventure',
        message:
            'Démarrez votre première session pour que MoveSense '
            'analyse vos habitudes et vous guide personnellement.',
        emoji: '🌟',
        category: 'decouverte',
        priority: 1,
      ));
    }

    // Tri par priorité et retourne les 3 meilleurs
    candidates.sort((a, b) => b.priority.compareTo(a.priority));
    return candidates.take(3).toList();
  }
}