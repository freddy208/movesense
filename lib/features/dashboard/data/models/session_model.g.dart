// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SessionModelAdapter extends TypeAdapter<SessionModel> {
  @override
  final int typeId = 0;

  @override
  SessionModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SessionModel(
      date: fields[0] as DateTime?,
      steps: fields[1] as int,
      distance: fields[2] as double,
      calories: fields[3] as double,
      duration: fields[4] as int,
      avgBpm: fields[5] as double,
      maxBpm: fields[6] as double,
      avgSpeed: fields[7] as double,
      avgPace: fields[8] as double,
      gpsPoints: (fields[9] as List?)?.cast<GpsPointModel>(),
      isCompleted: fields[10] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, SessionModel obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.steps)
      ..writeByte(2)
      ..write(obj.distance)
      ..writeByte(3)
      ..write(obj.calories)
      ..writeByte(4)
      ..write(obj.duration)
      ..writeByte(5)
      ..write(obj.avgBpm)
      ..writeByte(6)
      ..write(obj.maxBpm)
      ..writeByte(7)
      ..write(obj.avgSpeed)
      ..writeByte(8)
      ..write(obj.avgPace)
      ..writeByte(9)
      ..write(obj.gpsPoints)
      ..writeByte(10)
      ..write(obj.isCompleted);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class GpsPointModelAdapter extends TypeAdapter<GpsPointModel> {
  @override
  final int typeId = 1;

  @override
  GpsPointModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GpsPointModel(
      latitude: fields[0] as double,
      longitude: fields[1] as double,
      altitude: fields[2] as double,
      timestamp: fields[3] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, GpsPointModel obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.latitude)
      ..writeByte(1)
      ..write(obj.longitude)
      ..writeByte(2)
      ..write(obj.altitude)
      ..writeByte(3)
      ..write(obj.timestamp);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GpsPointModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
