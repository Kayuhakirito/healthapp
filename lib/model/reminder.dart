import 'package:hive/hive.dart';

part 'reminder.g.dart';

@HiveType(typeId: 0)
class Reminder extends HiveObject {
  @HiveField(0)
  int id;

  @HiveField(1)
  String message;

  @HiveField(2)
  DateTime time;

  @HiveField(3)
  bool isEnabled;

  @HiveField(4)
  String? frequency;

  @HiveField(5) // Thêm trường mới
  int waterAmount; // Lượng nước (ml) cần uống

  Reminder({
    required this.id,
    required this.message,
    required this.time,
    bool? isEnabled, // Cho phép isEnabled nhận null từ dữ liệu cũ
    this.frequency,
    this.waterAmount = 250, // Giá trị mặc định là 250 ml
  }) : isEnabled = isEnabled ?? true; // Giá trị mặc định là true nếu null
}