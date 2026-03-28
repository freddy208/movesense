// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserProfileModelAdapter extends TypeAdapter<UserProfileModel> {
  @override
  final int typeId = 2;

  @override
  UserProfileModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserProfileModel(
      name: fields[0] as String,
      weight: fields[1] as double,
      height: fields[2] as double,
      age: fields[3] as int,
      strideLength: fields[4] as double,
      gender: fields[5] as String,
      dailyStepGoal: fields[6] as int,
      dailyDistanceGoal: fields[7] as double,
      dailyCaloriesGoal: fields[8] as double,
      dailyDurationGoal: fields[9] as int,
      createdAt: fields[10] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, UserProfileModel obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.weight)
      ..writeByte(2)
      ..write(obj.height)
      ..writeByte(3)
      ..write(obj.age)
      ..writeByte(4)
      ..write(obj.strideLength)
      ..writeByte(5)
      ..write(obj.gender)
      ..writeByte(6)
      ..write(obj.dailyStepGoal)
      ..writeByte(7)
      ..write(obj.dailyDistanceGoal)
      ..writeByte(8)
      ..write(obj.dailyCaloriesGoal)
      ..writeByte(9)
      ..write(obj.dailyDurationGoal)
      ..writeByte(10)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfileModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
