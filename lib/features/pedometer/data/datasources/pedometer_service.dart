import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../audio/data/datasources/audio_service.dart';
import '../../../audio/data/datasources/notification_service.dart';

// ═══════════════════════════════════════
// MODÈLE SESSION EN COURS
// ═══════════════════════════════════════
class LiveSessionData {
  final int steps;
  final double distance;
  final double calories;
  final int durationSeconds;
  final double speedKmh;
  final double paceMinkm;
  final bool isActive;

  const LiveSessionData({
    this.steps = 0,
    this.distance = 0.0,
    this.calories = 0.0,
    this.durationSeconds = 0,
    this.speedKmh = 0.0,
    this.paceMinkm = 0.0,
    this.isActive = false,
  });

  LiveSessionData copyWith({
    int? steps,
    double? distance,
    double? calories,
    int? durationSeconds,
    double? speedKmh,
    double? paceMinkm,
    bool? isActive,
  }) {
    return LiveSessionData(
      steps: steps ?? this.steps,
      distance: distance ?? this.distance,
      calories: calories ?? this.calories,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      speedKmh: speedKmh ?? this.speedKmh,
      paceMinkm: paceMinkm ?? this.paceMinkm,
      isActive: isActive ?? this.isActive,
    );
  }

  String get formattedDuration {
    final h = durationSeconds ~/ 3600;
    final m = (durationSeconds % 3600) ~/ 60;
    final s = durationSeconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

// ═══════════════════════════════════════
// PEDOMETER SERVICE — CAPTEUR NATIF
// ═══════════════════════════════════════
class PedometerService {
  StreamSubscription<StepCount>? _stepSubscription;
  StreamSubscription<PedestrianStatus>? _statusSubscription;
  Timer? _timerSubscription;

  final _sessionController =
      StreamController<LiveSessionData>.broadcast();
  Stream<LiveSessionData> get sessionStream => _sessionController.stream;

  LiveSessionData _currentData = const LiveSessionData();
  LiveSessionData get currentData => _currentData;

  // Pas de référence au démarrage de la session
  int _stepsAtSessionStart = 0;
  bool _firstStepReceived = false;

  // Profil utilisateur
  double _weight = 70.0;
  double _strideLength = 0.75;
  int _dailyGoal = 10000;

  // Auto-pause
  int _secondsSinceLastStep = 0;
  static const int _autoPauseSeconds = 120;

  // Objectif notifié
  bool _goalNotified = false;

  // Statut marche/arrêt

  void _loadProfile() {
    final box = Hive.box(AppConstants.userProfileBox);
    _weight = box.get(AppConstants.userWeightKey, defaultValue: 70.0);
    _strideLength = box.get(
      AppConstants.userStrideLengthKey,
      defaultValue: 0.75,
    );
    _dailyGoal = box.get(
      AppConstants.dailyStepGoalKey,
      defaultValue: 10000,
    );
  }

  // ── DEMANDE PERMISSION ──
  static Future<bool> requestPermission() async {
    final status = await Permission.activityRecognition.request();
    return status.isGranted;
  }

  // ── DÉMARRAGE SESSION ──
  Future<void> startSession() async {
    _loadProfile();
    _goalNotified = false;
    _secondsSinceLastStep = 0;
    _firstStepReceived = false;
    _stepsAtSessionStart = 0;
    _currentData = const LiveSessionData(isActive: true);
    _sessionController.add(_currentData);

    // Demande permission si nécessaire
    await requestPermission();

    // ── CAPTEUR PAS NATIF ──
    _stepSubscription = Pedometer.stepCountStream.listen(
      _onStepCount,
      onError: _onStepError,
      cancelOnError: false,
    );

    // ── STATUT MARCHE/ARRÊT ──
    _statusSubscription = Pedometer.pedestrianStatusStream.listen(
      _onPedestrianStatus,
      onError: (_) {},
      cancelOnError: false,
    );

    // ── TIMER 1 seconde ──
    _timerSubscription =
        Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_currentData.isActive) return;

      _secondsSinceLastStep++;

      // Auto-pause si immobile 2 minutes
      if (_secondsSinceLastStep >= _autoPauseSeconds) {
        pauseSession();
        return;
      }

      final newDuration = _currentData.durationSeconds + 1;
      final durationHours = newDuration / 3600;
      final speedKmh = durationHours > 0
          ? (_currentData.distance / durationHours)
          : 0.0;
      final paceMinkm = speedKmh > 0.5 ? (60 / speedKmh) : 0.0;
      final met = speedKmh > 6.0 ? 6.5 : 3.5;
      final calories = met * _weight * durationHours;

      _currentData = _currentData.copyWith(
        durationSeconds: newDuration,
        speedKmh: speedKmh,
        paceMinkm: paceMinkm,
        calories: calories,
      );
      _sessionController.add(_currentData);

      if (newDuration % 10 == 0) _checkGoal();
    });
  }

  void _onStepCount(StepCount event) {
    if (!_currentData.isActive) return;

    // Premier événement — mémorise la valeur de référence
    if (!_firstStepReceived) {
      _stepsAtSessionStart = event.steps;
      _firstStepReceived = true;
      return;
    }

    // Calcule les pas depuis le début de la session
    final sessionSteps = event.steps - _stepsAtSessionStart;
    if (sessionSteps < 0) return; // protection redémarrage compteur

    _secondsSinceLastStep = 0;
    final newDistance = sessionSteps * _strideLength / 1000;

    _currentData = _currentData.copyWith(
      steps: sessionSteps,
      distance: newDistance,
    );
    _sessionController.add(_currentData);

    // Jalons TTS
    _checkMilestone(sessionSteps);
    _checkGoal();
  }

  void _onStepError(error) {
    // Capteur natif non disponible — fallback silencieux
  }

  void _onPedestrianStatus(PedestrianStatus event) {
    // 'walking' ou 'stopped'
    if (event.status == 'walking') {
      _secondsSinceLastStep = 0;
      if (!_currentData.isActive) resumeSession();
    }
  }

  void _checkMilestone(int steps) {
    if (steps == 1000 || steps == 5000 || steps == 10000) {
      AudioService().speakMilestone(steps);
      HapticFeedback.mediumImpact();
    }
  }

  void _checkGoal() {
    if (_goalNotified) return;
    try {
      final box = Hive.box(AppConstants.userProfileBox);
      final dailySteps =
          box.get('daily_steps_${_todayKey()}', defaultValue: 0) as int;
      final totalSteps = dailySteps + _currentData.steps;
      if (totalSteps >= _dailyGoal && _dailyGoal > 0) {
        _goalNotified = true;
        HapticFeedback.heavyImpact();
        Future.microtask(() async {
          try {
            await AudioService().playSound(AppSound.success);
            await NotificationService.notifyGoalReached(totalSteps);
            await AudioService().speakQuote(
              'Félicitations ! Objectif de $_dailyGoal pas atteint !',
            );
          } catch (_) {}
        });
      }
    } catch (_) {}
  }

  void pauseSession() {
    _stepSubscription?.pause();
    _currentData = _currentData.copyWith(isActive: false);
    _sessionController.add(_currentData);
  }

  void resumeSession() {
    _secondsSinceLastStep = 0;
    _stepSubscription?.resume();
    _currentData = _currentData.copyWith(isActive: true);
    _sessionController.add(_currentData);
  }

  void stopSession() {
    _stepSubscription?.cancel();
    _statusSubscription?.cancel();
    _timerSubscription?.cancel();
    _stepSubscription = null;
    _statusSubscription = null;
    _timerSubscription = null;
    _currentData = const LiveSessionData(isActive: false);
    _sessionController.add(_currentData);
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  void dispose() {
    stopSession();
    _sessionController.close();
  }
}

// ═══════════════════════════════════════
// PROVIDERS
// ═══════════════════════════════════════
final pedometerServiceProvider = Provider<PedometerService>((ref) {
  final service = PedometerService();
  ref.onDispose(() => service.dispose());
  return service;
});

final liveSessionProvider = StreamProvider<LiveSessionData>((ref) {
  return ref.watch(pedometerServiceProvider).sessionStream;
});

final dailyStepsProvider = StateProvider<int>((ref) {
  final box = Hive.box(AppConstants.userProfileBox);
  return box.get('daily_steps_${_todayKey()}', defaultValue: 0);
});

final dailyGoalProvider = StateProvider<int>((ref) {
  final box = Hive.box(AppConstants.userProfileBox);
  return box.get(AppConstants.dailyStepGoalKey, defaultValue: 10000);
});

String _todayKey() {
  final now = DateTime.now();
  return '${now.year}-${now.month}-${now.day}';
}