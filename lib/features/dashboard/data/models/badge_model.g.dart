// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'badge_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BadgeModelAdapter extends TypeAdapter<BadgeModel> {
  @override
  final int typeId = 4;

  @override
  BadgeModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BadgeModel(
      badgeKey: fields[0] as String,
      name: fields[1] as String,
      description: fields[2] as String,
      category: fields[3] as String,
      isUnlocked: fields[4] as bool,
      isSecret: fields[5] as bool,
      unlockedAt: fields[6] as DateTime?,
      xpReward: fields[7] as int,
      requiredValue: fields[8] as int,
    );
  }

  @override
  void write(BinaryWriter writer, BadgeModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.badgeKey)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.category)
      ..writeByte(4)
      ..write(obj.isUnlocked)
      ..writeByte(5)
      ..write(obj.isSecret)
      ..writeByte(6)
      ..write(obj.unlockedAt)
      ..writeByte(7)
      ..write(obj.xpReward)
      ..writeByte(8)
      ..write(obj.requiredValue);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BadgeModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
