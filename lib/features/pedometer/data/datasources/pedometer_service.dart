import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:sensors_plus/sensors_plus.dart';
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
// PEAK DETECTION — VERSION OPTIMISÉE
// ═══════════════════════════════════════
class PeakDetector {
  static const double _threshold = 10.5;
  static const int _minStepIntervalMs = 250;
  static const int _smoothingWindow = 5;

  final List<double> _magnitudeBuffer = [];
  DateTime _lastStepTime =
      DateTime.now().subtract(const Duration(seconds: 2));
  double _lastMagnitude = 0.0;
  bool _isPeak = false;

  bool processAccelerometer(AccelerometerEvent event) {
    final magnitude = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );

    _magnitudeBuffer.add(magnitude);
    if (_magnitudeBuffer.length > _smoothingWindow) {
      _magnitudeBuffer.removeAt(0);
    }
    final smoothed = _magnitudeBuffer.reduce((a, b) => a + b) /
        _magnitudeBuffer.length;

    bool stepDetected = false;

    if (!_isPeak && smoothed > _threshold && smoothed > _lastMagnitude) {
      _isPeak = true;
    } else if (_isPeak && smoothed < _threshold) {
      _isPeak = false;
      final now = DateTime.now();
      final elapsed = now.difference(_lastStepTime).inMilliseconds;
      if (elapsed >= _minStepIntervalMs) {
        _lastStepTime = now;
        stepDetected = true;
      }
    }

    _lastMagnitude = smoothed;
    return stepDetected;
  }

  void reset() {
    _magnitudeBuffer.clear();
    _lastStepTime =
        DateTime.now().subtract(const Duration(seconds: 2));
    _lastMagnitude = 0.0;
    _isPeak = false;
  }
}

// ═══════════════════════════════════════
// PEDOMETER SERVICE — OPTIMISÉ BATTERIE
// ═══════════════════════════════════════
class PedometerService {
  final PeakDetector _peakDetector = PeakDetector();

  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  Timer? _timerSubscription;

  final _sessionController =
      StreamController<LiveSessionData>.broadcast();
  Stream<LiveSessionData> get sessionStream => _sessionController.stream;

  LiveSessionData _currentData = const LiveSessionData();

  // Profil
  double _weight = 70.0;
  double _strideLength = 0.75;
  int _dailyGoal = 10000;

  // Inactivité (auto-pause)
  int _secondsSinceLastStep = 0;
  static const int _autoPauseSeconds = 120;

  // Anti-double step
  int _lastStepCount = 0;

  // Objectif atteint notifié
  bool _goalNotified = false;

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

  void startSession() {
    _loadProfile();
    _peakDetector.reset();
    _goalNotified = false;
    _secondsSinceLastStep = 0;
    _currentData = const LiveSessionData(isActive: true);
    _sessionController.add(_currentData);

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

      // Vitesse et allure
      final speedKmh = durationHours > 0
          ? (_currentData.distance / durationHours)
          : 0.0;
      final paceMinkm =
          speedKmh > 0.5 ? (60 / speedKmh) : 0.0;

      // Calories MET adaptatif
      final met = speedKmh > 6.0 ? 6.5 : 3.5;
      final calories = met * _weight * durationHours;

      _currentData = _currentData.copyWith(
        durationSeconds: newDuration,
        speedKmh: speedKmh,
        paceMinkm: paceMinkm,
        calories: calories,
      );
      _sessionController.add(_currentData);

      // Vérifie objectif toutes les 10 secondes
      if (newDuration % 10 == 0) _checkGoal();
    });

    // ── ACCÉLÉROMÈTRE — fréquence optimisée ──
    _accelSubscription = accelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen(
      (event) {
        if (!_currentData.isActive) return;
        try {
          final stepDetected = _peakDetector.processAccelerometer(event);
          if (stepDetected) {
            _secondsSinceLastStep = 0;
            _addStep();
          }
        } catch (_) {}
      },
      onError: (_) {},
      cancelOnError: false,
    );
  }

  void _addStep() {
    final newSteps = _currentData.steps + 1;

    // Anti-doublon : ignore si même valeur
    if (newSteps == _lastStepCount) return;
    _lastStepCount = newSteps;

    final newDistance = newSteps * _strideLength / 1000;

    _currentData = _currentData.copyWith(
      steps: newSteps,
      distance: newDistance,
    );
    _sessionController.add(_currentData);

    // Jalons TTS
    _checkMilestone(newSteps);
    _checkGoal(); // ← ajoute cette ligne
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
    _accelSubscription?.pause();
    _currentData = _currentData.copyWith(isActive: false);
    _sessionController.add(_currentData);
  }

  void resumeSession() {
    _secondsSinceLastStep = 0;
    _accelSubscription?.resume();
    _currentData = _currentData.copyWith(isActive: true);
    _sessionController.add(_currentData);
  }

  void stopSession() {
    _accelSubscription?.cancel();
    _timerSubscription?.cancel();
    _accelSubscription = null;
    _timerSubscription = null;
    // Remet à zéro après sauvegarde
    _currentData = const LiveSessionData(isActive: false);
    _sessionController.add(_currentData);
  }

  void _saveDailySteps() {
    final box = Hive.box(AppConstants.userProfileBox);
    final today = _todayKey();
    final existing =
        box.get('daily_steps_$today', defaultValue: 0) as int;
    box.put('daily_steps_$today', existing + _currentData.steps);
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  LiveSessionData get currentData => _currentData;

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
  final service = ref.watch(pedometerServiceProvider);
  return service.sessionStream;
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