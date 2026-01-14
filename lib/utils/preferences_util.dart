import 'package:shared_preferences/shared_preferences.dart';

class PreferencesUtil {
  static const String _waterGoalKey = 'waterGoal';
  static const String _stepGoalKey = 'stepGoal';
  // Thêm key cho email người dùng
  static const String _userEmailKey = 'userEmail';

  // Lấy mục tiêu nước
  static Future<int> getWaterGoal() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_waterGoalKey) ?? 3500; // Thay đổi từ 3000 thành 3500 ml
  }

  // Lưu mục tiêu nước
  static Future<void> setWaterGoal(int goal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_waterGoalKey, goal);
  }

  // Lấy mục tiêu bước chân
  static Future<int> getStepGoal() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_stepGoalKey) ?? 10000; // Giá trị mặc định là 10000 bước
  }

  // Lưu mục tiêu bước chân
  static Future<void> setStepGoal(int goal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_stepGoalKey, goal);
  }

  // Lưu email người dùng khi đăng nhập thành công
  static Future<void> saveUserEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userEmailKey, email);
  }

  // Lấy email người dùng đã đăng nhập
  static Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userEmailKey);
  }

  // Xóa phiên đăng nhập (dùng cho chức năng đăng xuất)
  static Future<void> clearUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userEmailKey);
  }
}
