import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../audio/data/datasources/audio_service.dart';

// ═══════════════════════════════════════
// MODÈLES
// ═══════════════════════════════════════
enum HeartZone {
  rest,
  light,
  moderate,
  intense,
  maximum,
}

extension HeartZoneExt on HeartZone {
  String get label {
    switch (this) {
      case HeartZone.rest: return 'Repos';
      case HeartZone.light: return 'Légère';
      case HeartZone.moderate: return 'Modérée';
      case HeartZone.intense: return 'Intense';
      case HeartZone.maximum: return 'Maximum';
    }
  }

  Color get color {
    switch (this) {
      case HeartZone.rest: return const Color(0xFF3498DB);
      case HeartZone.light: return AppColors.successGreen;
      case HeartZone.moderate: return AppColors.energyOrange;
      case HeartZone.intense: return const Color(0xFFE67E22);
      case HeartZone.maximum: return AppColors.alertRed;
    }
  }

  String get emoji {
    switch (this) {
      case HeartZone.rest: return '😴';
      case HeartZone.light: return '🚶';
      case HeartZone.moderate: return '🏃';
      case HeartZone.intense: return '⚡';
      case HeartZone.maximum: return '🔥';
    }
  }

  String get description {
    switch (this) {
      case HeartZone.rest: return '< 50% FC max — Récupération';
      case HeartZone.light: return '50-60% FC max — Brûle les graisses';
      case HeartZone.moderate: return '60-70% FC max — Cardio optimal';
      case HeartZone.intense: return '70-85% FC max — Performance';
      case HeartZone.maximum: return '> 85% FC max — Effort maximal';
    }
  }
}

class HeartRateData {
  final int bpm;
  final HeartZone zone;
  final double zonePercent; // % de FC max
  final bool isAlerting;
  final List<int> history; // dernières 60 valeurs

  const HeartRateData({
    this.bpm = 72,
    this.zone = HeartZone.rest,
    this.zonePercent = 0.0,
    this.isAlerting = false,
    this.history = const [],
  });

  HeartRateData copyWith({
    int? bpm,
    HeartZone? zone,
    double? zonePercent,
    bool? isAlerting,
    List<int>? history,
  }) {
    return HeartRateData(
      bpm: bpm ?? this.bpm,
      zone: zone ?? this.zone,
      zonePercent: zonePercent ?? this.zonePercent,
      isAlerting: isAlerting ?? this.isAlerting,
      history: history ?? this.history,
    );
  }
}

// ═══════════════════════════════════════
// HEART RATE SERVICE
// ═══════════════════════════════════════
class HeartRateService {
  StreamSubscription<AccelerometerEvent>? _accelSub;
  final _controller = StreamController<HeartRateData>.broadcast();
  Stream<HeartRateData> get stream => _controller.stream;

  HeartRateData _current = const HeartRateData();
  HeartRateData get current => _current;

  // Paramètres utilisateur
  int _age = 25;
  int _maxHr = 195; // 220 - age

  // Lissage accéléromètre
  final List<double> _magnitudes = [];
  static const int _smoothWindow = 20;
  static const int _historyMax = 60;

  // Anti-spam alertes
  DateTime _lastAlert = DateTime(2000);

  void start(int age) {
    _age = age;
    _maxHr = 220 - age;
    _magnitudes.clear();

    _accelSub = accelerometerEventStream(
      samplingPeriod: SensorInterval.normalInterval,
    ).listen(_onAccel);
  }

  void _onAccel(AccelerometerEvent event) {
    final mag = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );

    _magnitudes.add(mag);
    if (_magnitudes.length > _smoothWindow) _magnitudes.removeAt(0);

    final avg = _magnitudes.reduce((a, b) => a + b) / _magnitudes.length;

    // Mapping magnitude → BPM
    // Au repos : mag ≈ 9.8 (gravité), mouvement : 10-20+
    final activity = (avg - 9.5).clamp(0.0, 12.0);
    final bpm = (60 + (activity / 12.0) * 100).toInt().clamp(55, 165);

    final zone = _getZone(bpm);
    final zonePercent = bpm / _maxHr;

    // Historique
    final newHistory = List<int>.from(_current.history);
    newHistory.add(bpm);
    if (newHistory.length > _historyMax) newHistory.removeAt(0);

    // Alerte zone maximum
    final isAlerting = zone == HeartZone.maximum;
    if (isAlerting) _triggerAlert();

    _current = _current.copyWith(
      bpm: bpm,
      zone: zone,
      zonePercent: zonePercent,
      isAlerting: isAlerting,
      history: newHistory,
    );

    _controller.add(_current);
  }

  HeartZone _getZone(int bpm) {
    final percent = bpm / _maxHr;
    if (percent < 0.50) return HeartZone.rest;
    if (percent < 0.60) return HeartZone.light;
    if (percent < 0.70) return HeartZone.moderate;
    if (percent < 0.85) return HeartZone.intense;
    return HeartZone.maximum;
  }

  Future<void> _triggerAlert() async {
    final now = DateTime.now();
    if (now.difference(_lastAlert).inSeconds < 10) return;
    _lastAlert = now;

    // Vibration
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 200));
    HapticFeedback.heavyImpact();

    // Son alerte
    await AudioService().playSound(AppSound.heartAlert);
  }

  Future<void> saveSession(int avgBpm, int maxBpm) async {
    final box = await Hive.openBox('heart_rate_box');
    final key = 'hr_${DateTime.now().millisecondsSinceEpoch}';
    await box.put(key, {
      'date': DateTime.now().toIso8601String(),
      'avgBpm': avgBpm,
      'maxBpm': maxBpm,
      'age': _age,
      'maxHr': _maxHr,
    });
  }

  void stop() {
    _accelSub?.cancel();
    _accelSub = null;
  }

  void dispose() {
    stop();
    _controller.close();
  }
}

// ═══════════════════════════════════════
// PROVIDERS
// ═══════════════════════════════════════
final heartRateServiceProvider = Provider<HeartRateService>((ref) {
  final service = HeartRateService();
  ref.onDispose(() => service.dispose());
  return service;
});

final heartRateStreamProvider = StreamProvider<HeartRateData>((ref) {
  return ref.watch(heartRateServiceProvider).stream;
});