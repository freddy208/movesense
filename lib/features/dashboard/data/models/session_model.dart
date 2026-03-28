import 'package:hive/hive.dart';

part 'session_model.g.dart';

@HiveType(typeId: 0)
class SessionModel extends HiveObject {
  @HiveField(0)
  late DateTime date;

  @HiveField(1)
  late int steps;

  @HiveField(2)
  late double distance;

  @HiveField(3)
  late double calories;

  @HiveField(4)
  late int duration;

  @HiveField(5)
  late double avgBpm;

  @HiveField(6)
  late double maxBpm;

  @HiveField(7)
  late double avgSpeed;

  @HiveField(8)
  late double avgPace;

  @HiveField(9)
  late List<GpsPointModel> gpsPoints;

  @HiveField(10)
  late bool isCompleted;

  SessionModel({
    DateTime? date,
    this.steps = 0,
    this.distance = 0.0,
    this.calories = 0.0,
    this.duration = 0,
    this.avgBpm = 0.0,
    this.maxBpm = 0.0,
    this.avgSpeed = 0.0,
    this.avgPace = 0.0,
    List<GpsPointModel>? gpsPoints,
    this.isCompleted = false,
  })  : date = date ?? DateTime.now(),
        gpsPoints = gpsPoints ?? [];
}

@HiveType(typeId: 1)
class GpsPointModel extends HiveObject {
  @HiveField(0)
  late double latitude;

  @HiveField(1)
  late double longitude;

  @HiveField(2)
  late double altitude;

  @HiveField(3)
  late DateTime timestamp;

  GpsPointModel({
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.altitude = 0.0,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}