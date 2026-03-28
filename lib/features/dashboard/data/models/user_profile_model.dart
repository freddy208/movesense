import 'package:hive/hive.dart';

part 'user_profile_model.g.dart';

@HiveType(typeId: 2)
class UserProfileModel extends HiveObject {
  @HiveField(0)
  late String name;

  @HiveField(1)
  late double weight;

  @HiveField(2)
  late double height;

  @HiveField(3)
  late int age;

  @HiveField(4)
  late double strideLength;

  @HiveField(5)
  late String gender;

  @HiveField(6)
  late int dailyStepGoal;

  @HiveField(7)
  late double dailyDistanceGoal;

  @HiveField(8)
  late double dailyCaloriesGoal;

  @HiveField(9)
  late int dailyDurationGoal;

  @HiveField(10)
  late DateTime createdAt;

  UserProfileModel({
    this.name = '',
    this.weight = 70.0,
    this.height = 170.0,
    this.age = 25,
    this.strideLength = 0.75,
    this.gender = 'male',
    this.dailyStepGoal = 10000,
    this.dailyDistanceGoal = 7.0,
    this.dailyCaloriesGoal = 500.0,
    this.dailyDurationGoal = 60,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  static double calculateStrideLength(double heightCm, String gender) {
    return gender == 'male'
        ? heightCm * 0.415 / 100
        : heightCm * 0.413 / 100;
  }
}