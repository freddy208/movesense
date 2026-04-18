import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
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
// PEDOMETER SERVICE
// Priorité : capteur natif → fallback accéléromètre si aucun pas après 5s
// ═══════════════════════════════════════
class PedometerService {
  // Capteur natif
  StreamSubscription<StepCount>? _stepSubscription;
  StreamSubscription<PedestrianStatus>? _statusSubscription;

  // Fallback accéléromètre
  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  bool _useNative = true;
  int _accelStepBuffer = 0;
  double _gravity = 9.81;
  DateTime? _lastAccelPeak;

  // Timer
  Timer? _timerSubscription;
  Timer? _fallbackTimer;

  final _sessionController = StreamController<LiveSessionData>.broadcast();
  Stream<LiveSessionData> get sessionStream => _sessionController.stream;

  LiveSessionData _currentData = const LiveSessionData();
  LiveSessionData get currentData => _currentData;

  int _stepsAtSessionStart = 0;
  bool _firstStepReceived = false;

  // Profil
  double _weight = 70.0;
  double _strideLength = 0.75;
  int _dailyGoal = 10000;

  // Auto-pause
  int _secondsSinceLastStep = 0;
  static const int _autoPauseSeconds = 120;

  // Objectif notifié
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

  static Future<bool> requestPermission() async {
    final status = await Permission.activityRecognition.request();
    return status.isGranted;
  }

  Future<void> startSession() async {
    _loadProfile();
    _goalNotified = false;
    _secondsSinceLastStep = 0;
    _firstStepReceived = false;
    _stepsAtSessionStart = 0;
    _useNative = true;
    _accelStepBuffer = 0;
    _gravity = 9.81;
    _lastAccelPeak = null;
    _currentData = const LiveSessionData(isActive: true);
    _sessionController.add(_currentData);

    final granted = await requestPermission();
    if (!granted) {
      print('Pedometer permission denied');
      return;
    }

    // ── 1. CAPTEUR NATIF ──
    _stepSubscription = Pedometer.stepCountStream
        .distinct((prev, next) => prev.steps == next.steps)
        .listen(
      (event) {
        if (!_useNative) return; // Ignore si fallback actif
        _onNativeStep(event);
      },
      onError: (e) => print('StepCount error: $e'),
      cancelOnError: false,
    );

    // ── 2. STATUT MARCHE ──
    _statusSubscription = Pedometer.pedestrianStatusStream.listen(
      (event) {
        if (event.status == 'walking') {
          _secondsSinceLastStep = 0;
        }
      },
      onError: (e) => print('PedestrianStatus error: $e'),
      cancelOnError: false,
    );

    // ── 3. TIMER ──
    _timerSubscription =
        Timer.periodic(const Duration(seconds: 1), (_) => _tick());

    // ── 4. FALLBACK DETECTION ──
    // Si aucun pas natif reçu après 5s → bascule accéléromètre
    _fallbackTimer = Timer(const Duration(seconds: 5), () {
      if (_useNative && !_firstStepReceived && _currentData.isActive) {
        print('No native steps after 5s → switching to accelerometer fallback');
        _switchToFallback();
      }
    });
  }

  void _onNativeStep(StepCount event) {
    if (!_currentData.isActive) return;

    // Annule le timer de fallback car on a reçu un pas natif
    _fallbackTimer?.cancel();

    if (!_firstStepReceived) {
      _stepsAtSessionStart = event.steps;
      _firstStepReceived = true;
      return;
    }

    int realSteps = event.steps - _stepsAtSessionStart;
    if (realSteps < 0) {
      // Reset du capteur
      _stepsAtSessionStart = event.steps;
      return;
    }

    _secondsSinceLastStep = 0;

    final newDistance = realSteps * _strideLength / 1000;
    _currentData = _currentData.copyWith(
      steps: realSteps,
      distance: newDistance,
    );
    _sessionController.add(_currentData);

    _checkMilestone(realSteps);
    _checkGoal();
  }

  // ═══════════════════════════════════════
  // FALLBACK ACCÉLÉROMÈTRE
  // ═══════════════════════════════════════
  void _switchToFallback() {
    _useNative = false;
    // Annule le capteur natif (economie & évite double-comptage)
    _stepSubscription?.cancel();
    _stepSubscription = null;
    // Conserve les pas déjà comptés éventuels (0 la plupart du temps)
    _accelStepBuffer = _currentData.steps;
    _lastAccelPeak = DateTime.now();

    _accelSubscription = accelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen(_onAccelerometer);

    print('Accelerometer fallback activated');
  }

  void _onAccelerometer(AccelerometerEvent event) {
    if (!_currentData.isActive) return;

    final magnitude =
        sqrt(event.x * event.x + event.y * event.y + event.z * event.z);

    // Filtre passe-bas pour estimer la gravité
    _gravity = 0.92 * _gravity + 0.08 * magnitude;
    final linearAcc = magnitude - _gravity;

    final now = DateTime.now();
    if (linearAcc > 2.0 &&
        _lastAccelPeak != null &&
        now.difference(_lastAccelPeak!).inMilliseconds > 300) {
      _lastAccelPeak = now;
      _accelStepBuffer++;

      _secondsSinceLastStep = 0;

      final newDistance = _accelStepBuffer * _strideLength / 1000;
      _currentData = _currentData.copyWith(
        steps: _accelStepBuffer,
        distance: newDistance,
      );
      _sessionController.add(_currentData);

      _checkMilestone(_accelStepBuffer);
      _checkGoal();
    }
  }

  // ═══════════════════════════════════════
  // TIMER & MÉTRIQUES
  // ═══════════════════════════════════════
  void _tick() {
    if (!_currentData.isActive) return;
    _secondsSinceLastStep++;

    if (_secondsSinceLastStep >= _autoPauseSeconds) {
      pauseSession();
      return;
    }

    final newDuration = _currentData.durationSeconds + 1;
    final hours = newDuration / 3600;
    final speedKmh = hours > 0 ? _currentData.distance / hours : 0.0;
    final paceMinkm = speedKmh > 0.5 ? 60 / speedKmh : 0.0;
    final met = speedKmh > 6.0 ? 6.5 : 3.5;
    final calories = met * _weight * hours;

    _currentData = _currentData.copyWith(
      durationSeconds: newDuration,
      speedKmh: speedKmh,
      paceMinkm: paceMinkm,
      calories: calories,
    );
    _sessionController.add(_currentData);

    if (newDuration % 10 == 0) _checkGoal();
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
    _accelSubscription?.pause();
    _currentData = _currentData.copyWith(isActive: false);
    _sessionController.add(_currentData);
  }

  void resumeSession() {
    _secondsSinceLastStep = 0;
    _stepSubscription?.resume();
    _accelSubscription?.resume();
    _currentData = _currentData.copyWith(isActive: true);
    _sessionController.add(_currentData);
  }

  void stopSession() {
    _stepSubscription?.cancel();
    _statusSubscription?.cancel();
    _accelSubscription?.cancel();
    _timerSubscription?.cancel();
    _fallbackTimer?.cancel();
    _stepSubscription = null;
    _statusSubscription = null;
    _accelSubscription = null;
    _timerSubscription = null;
    _fallbackTimer = null;
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
  final today = _todayKey();
  return box.get('daily_steps_$today', defaultValue: 0);
});

final dailyGoalProvider = StateProvider<int>((ref) {
  final box = Hive.box(AppConstants.userProfileBox);
  return box.get(AppConstants.dailyStepGoalKey, defaultValue: 10000);
});

String _todayKey() {
  final now = DateTime.now();
  return '${now.year}-${now.month}-${now.day}';
}
