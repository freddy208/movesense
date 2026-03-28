// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_stats_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DailyStatsModelAdapter extends TypeAdapter<DailyStatsModel> {
  @override
  final int typeId = 3;

  @override
  DailyStatsModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DailyStatsModel(
      date: fields[0] as DateTime?,
      steps: fields[1] as int,
      stepGoal: fields[2] as int,
      distance: fields[3] as double,
      calories: fields[4] as double,
      duration: fields[5] as int,
      avgBpm: fields[6] as double,
      sessionsCount: fields[7] as int,
      goalAchieved: fields[8] as bool,
      xpEarned: fields[9] as int,
      healthScore: fields[10] as double,
    );
  }

  @override
  void write(BinaryWriter writer, DailyStatsModel obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.steps)
      ..writeByte(2)
      ..write(obj.stepGoal)
      ..writeByte(3)
      ..write(obj.distance)
      ..writeByte(4)
      ..write(obj.calories)
      ..writeByte(5)
      ..write(obj.duration)
      ..writeByte(6)
      ..write(obj.avgBpm)
      ..writeByte(7)
      ..write(obj.sessionsCount)
      ..writeByte(8)
      ..write(obj.goalAchieved)
      ..writeByte(9)
      ..write(obj.xpEarned)
      ..writeByte(10)
      ..write(obj.healthScore);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyStatsModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
