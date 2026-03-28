import 'package:hive/hive.dart';

part 'badge_model.g.dart';

@HiveType(typeId: 4)
class BadgeModel extends HiveObject {
  @HiveField(0)
  late String badgeKey;

  @HiveField(1)
  late String name;

  @HiveField(2)
  late String description;

  @HiveField(3)
  late String category;

  @HiveField(4)
  late bool isUnlocked;

  @HiveField(5)
  late bool isSecret;

  @HiveField(6)
  late DateTime? unlockedAt;

  @HiveField(7)
  late int xpReward;

  @HiveField(8)
  late int requiredValue;

  BadgeModel({
    required this.badgeKey,
    required this.name,
    required this.description,
    this.category = 'steps',
    this.isUnlocked = false,
    this.isSecret = false,
    this.unlockedAt,
    this.xpReward = 50,
    this.requiredValue = 0,
  });
}