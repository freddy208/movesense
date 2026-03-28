import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';
import 'package:latlong2/latlong.dart';

// ═══════════════════════════════════════
// MODÈLES
// ═══════════════════════════════════════
class GpsPoint {
  final double latitude;
  final double longitude;
  final double altitude;
  final double speed;
  final DateTime timestamp;

  const GpsPoint({
    required this.latitude,
    required this.longitude,
    this.altitude = 0.0,
    this.speed = 0.0,
    required this.timestamp,
  });

  LatLng get latLng => LatLng(latitude, longitude);

  Map<String, dynamic> toMap() => {
        'lat': latitude,
        'lng': longitude,
        'alt': altitude,
        'spd': speed,
        'ts': timestamp.millisecondsSinceEpoch,
      };

  factory GpsPoint.fromMap(Map map) => GpsPoint(
        latitude: map['lat'],
        longitude: map['lng'],
        altitude: map['alt'] ?? 0.0,
        speed: map['spd'] ?? 0.0,
        timestamp: DateTime.fromMillisecondsSinceEpoch(map['ts']),
      );
}

class LiveGpsData {
  final List<GpsPoint> points;
  final double totalDistance; // km
  final double currentSpeed; // km/h
  final double currentAltitude;
  final bool isTracking;
  final GpsPoint? lastPoint;

  const LiveGpsData({
    this.points = const [],
    this.totalDistance = 0.0,
    this.currentSpeed = 0.0,
    this.currentAltitude = 0.0,
    this.isTracking = false,
    this.lastPoint,
  });

  LiveGpsData copyWith({
    List<GpsPoint>? points,
    double? totalDistance,
    double? currentSpeed,
    double? currentAltitude,
    bool? isTracking,
    GpsPoint? lastPoint,
  }) {
    return LiveGpsData(
      points: points ?? this.points,
      totalDistance: totalDistance ?? this.totalDistance,
      currentSpeed: currentSpeed ?? this.currentSpeed,
      currentAltitude: currentAltitude ?? this.currentAltitude,
      isTracking: isTracking ?? this.isTracking,
      lastPoint: lastPoint ?? this.lastPoint,
    );
  }

  List<LatLng> get polylinePoints => points.map((p) => p.latLng).toList();
}

// ═══════════════════════════════════════
// ALGORITHME HAVERSINE
// ═══════════════════════════════════════
class GeoCalculator {
  static const double _earthRadius = 6371.0; // km

  static double haversineDistance(GpsPoint p1, GpsPoint p2) {
    final lat1 = p1.latitude * pi / 180;
    final lat2 = p2.latitude * pi / 180;
    final dLat = (p2.latitude - p1.latitude) * pi / 180;
    final dLng = (p2.longitude - p1.longitude) * pi / 180;

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return _earthRadius * c;
  }

  // Douglas-Peucker pour simplifier le tracé GPS
  static List<GpsPoint> douglasPeucker(List<GpsPoint> points, double epsilon) {
    if (points.length < 3) return points;

    double maxDistance = 0;
    int maxIndex = 0;

    for (int i = 1; i < points.length - 1; i++) {
      final d = _perpendicularDistance(
        points[i],
        points.first,
        points.last,
      );
      if (d > maxDistance) {
        maxDistance = d;
        maxIndex = i;
      }
    }

    if (maxDistance > epsilon) {
      final left = douglasPeucker(points.sublist(0, maxIndex + 1), epsilon);
      final right = douglasPeucker(points.sublist(maxIndex), epsilon);
      return [...left.sublist(0, left.length - 1), ...right];
    }

    return [points.first, points.last];
  }

  static double _perpendicularDistance(
    GpsPoint point,
    GpsPoint lineStart,
    GpsPoint lineEnd,
  ) {
    final dx = lineEnd.longitude - lineStart.longitude;
    final dy = lineEnd.latitude - lineStart.latitude;

    if (dx == 0 && dy == 0) {
      return haversineDistance(point, lineStart);
    }

    final t = ((point.longitude - lineStart.longitude) * dx +
            (point.latitude - lineStart.latitude) * dy) /
        (dx * dx + dy * dy);

    final tClamped = t.clamp(0.0, 1.0);
    final closestPoint = GpsPoint(
      latitude: lineStart.latitude + tClamped * dy,
      longitude: lineStart.longitude + tClamped * dx,
      timestamp: DateTime.now(),
    );

    return haversineDistance(point, closestPoint);
  }
}

// ═══════════════════════════════════════
// GPS SERVICE
// ═══════════════════════════════════════
class GpsService {
  StreamSubscription<Position>? _positionSubscription;
  final _gpsController = StreamController<LiveGpsData>.broadcast();
  Stream<LiveGpsData> get gpsStream => _gpsController.stream;

  LiveGpsData _currentData = const LiveGpsData();
  final List<GpsPoint> _rawPoints = [];

  static const double _dpEpsilon = 0.00005;

  Future<bool> requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }

    if (permission == LocationPermission.deniedForever) return false;
    return true;
  }

  Future<void> startTracking() async {
    final hasPermission = await requestPermission();
    if (!hasPermission) return;

    _rawPoints.clear();
    _currentData = const LiveGpsData(isTracking: true);
    _gpsController.add(_currentData);

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // min 5 mètres entre 2 points
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(_onPositionUpdate);
  }

  void _onPositionUpdate(Position position) {
    final newPoint = GpsPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: position.altitude,
      speed: position.speed * 3.6,
      timestamp: position.timestamp,
    );

    // Filtre vitesse aberrante
    if (newPoint.speed > 60) return;

    // ── FRÉQUENCE GPS ADAPTATIVE ──
    // Lent (< 2 km/h) → filtre agressif, économie batterie
    // Rapide (> 8 km/h) → précision maximale
    if (_rawPoints.isNotEmpty) {
      final lastPoint = _rawPoints.last;
      final dist = GeoCalculator.haversineDistance(lastPoint, newPoint);
      final minDist = newPoint.speed < 2.0
          ? 0.010 // 10m minimum si lent
          : newPoint.speed > 8.0
              ? 0.003 // 3m si rapide
              : 0.005; // 5m par défaut
      if (dist < minDist) return; // Ignore si trop proche
    }

    _rawPoints.add(newPoint);

    double totalDist = 0;
    for (int i = 1; i < _rawPoints.length; i++) {
      totalDist += GeoCalculator.haversineDistance(
        _rawPoints[i - 1],
        _rawPoints[i],
      );
    }

    final simplified = _rawPoints.length > 10
        ? GeoCalculator.douglasPeucker(_rawPoints, _dpEpsilon)
        : List<GpsPoint>.from(_rawPoints);

    _currentData = _currentData.copyWith(
      points: simplified,
      totalDistance: totalDist,
      currentSpeed: newPoint.speed,
      currentAltitude: newPoint.altitude,
      lastPoint: newPoint,
      isTracking: true,
    );

    _gpsController.add(_currentData);
  }

  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;

    // Sauvegarde dans Hive
    _saveSession();

    _currentData = _currentData.copyWith(isTracking: false);
    _gpsController.add(_currentData);
  }

  void pauseTracking() {
    _positionSubscription?.pause();
  }

  void resumeTracking() {
    _positionSubscription?.resume();
  }

  Future<void> _saveSession() async {
    if (_rawPoints.isEmpty) return;

    final box = await Hive.openBox('gps_sessions');
    final sessionKey = 'session_${DateTime.now().millisecondsSinceEpoch}';

    final simplified = GeoCalculator.douglasPeucker(_rawPoints, _dpEpsilon);

    await box.put(sessionKey, {
      'date': DateTime.now().toIso8601String(),
      'points': simplified.map((p) => p.toMap()).toList(),
      'distance': _currentData.totalDistance,
      'duration': DateTime.now()
          .difference(simplified.first.timestamp)
          .inSeconds,
    });
  }

  Future<List<Map>> loadSessions() async {
    final box = await Hive.openBox('gps_sessions');
    return box.values
        .map((v) => Map<String, dynamic>.from(v))
        .toList()
        .reversed
        .toList();
  }

  LiveGpsData get currentData => _currentData;

  void dispose() {
    stopTracking();
    _gpsController.close();
  }
}

// ═══════════════════════════════════════
// PROVIDERS
// ═══════════════════════════════════════
final gpsServiceProvider = Provider<GpsService>((ref) {
  final service = GpsService();
  ref.onDispose(() => service.dispose());
  return service;
});

final liveGpsProvider = StreamProvider<LiveGpsData>((ref) {
  return ref.watch(gpsServiceProvider).gpsStream;
});