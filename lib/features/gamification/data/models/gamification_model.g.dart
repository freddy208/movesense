// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gamification_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class GamificationModelAdapter extends TypeAdapter<GamificationModel> {
  @override
  final int typeId = 5;

  @override
  GamificationModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GamificationModel(
      totalXp: fields[0] as int,
      currentLevel: fields[1] as int,
      currentStreak: fields[2] as int,
      longestStreak: fields[3] as int,
      jokerUsedThisMonth: fields[4] as int,
      lastActiveDate: fields[5] as DateTime?,
      unlockedBadgeKeys: (fields[6] as List?)?.cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, GamificationModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.totalXp)
      ..writeByte(1)
      ..write(obj.currentLevel)
      ..writeByte(2)
      ..write(obj.currentStreak)
      ..writeByte(3)
      ..write(obj.longestStreak)
      ..writeByte(4)
      ..write(obj.jokerUsedThisMonth)
      ..writeByte(5)
      ..write(obj.lastActiveDate)
      ..writeByte(6)
      ..write(obj.unlockedBadgeKeys);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GamificationModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
