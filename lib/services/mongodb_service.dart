import 'dart:developer';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:mongo_dart/mongo_dart.dart';

class MongoDatabase {

  static const String MONGO_CONN_URL =
      "mongodb+srv://admin:admin123456@healapp.asrjaj2.mongodb.net/HealthTrackingDB?retryWrites=true&w=majority&appName=healapp";

  static const String USER_COLLECTION = "users";
  static const String HEALTH_DATA_COLLECTION = "health_data";

  static late Db db;
  static late DbCollection userCollection;
  static late DbCollection healthDataCollection;

  // --- 1. KẾT NỐI DATABASE ---
  static connect() async {
    try {
      db = await Db.create(MONGO_CONN_URL);
      await db.open();
      inspect(db);
      userCollection = db.collection(USER_COLLECTION);
      healthDataCollection = db.collection(HEALTH_DATA_COLLECTION);
      log("✅ KẾT NỐI MONGODB THÀNH CÔNG!");
    } catch (e) {
      log("❌ Lỗi kết nối MongoDB: $e");
    }
  }

  // --- HÀM MÃ HÓA MẬT KHẨU ---
  static String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  // --- 2. ĐĂNG KÝ ---
  static Future<String> register(String email, String password, String name, {double? height, double? weight}) async {
    try {
      if (db.state != State.open) await connect();

      // Check trùng Email
      final existingUser = await userCollection.findOne(where.eq('email', email));
      if (existingUser != null) {
        return "Email này đã được sử dụng!";
      }

      var id = ObjectId();
      await userCollection.insert({
        "_id": id,
        "email": email,
        "password": _hashPassword(password),
        "name": name,
        "height": height ?? 0.0,
        "weight": weight ?? 0.0,
        "createdAt": DateTime.now().toIso8601String()
      });

      // Tạo data rỗng ban đầu
      await healthDataCollection.insert({
        'email': email,
        'date': DateTime.now().toIso8601String().substring(0, 10),
        'steps': 0,
        'water': 0,
        'heartRate': 0
      });

      return "Success";
    } catch (e) {
      return "Lỗi đăng ký: $e";
    }
  }

  // --- 3. ĐĂNG NHẬP ---
  static Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      if (db.state != State.open) await connect();
      var hashedPassword = _hashPassword(password);
      var user = await userCollection.findOne(where.eq('email', email).eq('password', hashedPassword));
      return user;
    } catch (e) {
      log("Lỗi đăng nhập: $e");
      return null;
    }
  }

  // --- 4. LẤY THÔNG TIN USER ---
  static Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    try {
      if (db.state != State.open) await connect();
      return await userCollection.findOne(where.eq('email', email));
    } catch (e) {
      return null;
    }
  }

  // --- 5. CẬP NHẬT THÔNG TIN ---
  static Future<bool> updateProfile(String email, String name, double height, double weight) async {
    try {
      if (db.state != State.open) await connect();
      var res = await userCollection.update(
          where.eq('email', email),
          modify.set('name', name).set('height', height).set('weight', weight)
      );
      return res['nModified'] > 0;
    } catch (e) {
      return false;
    }
  }

  // --- 6. ĐỔI MẬT KHẨU ---
  static Future<String> changePassword(String email, String oldPassword, String newPassword) async {
    try {
      if (db.state != State.open) await connect();
      final hashedOld = _hashPassword(oldPassword);
      final user = await userCollection.findOne(where.eq('email', email).eq('password', hashedOld));

      if (user == null) return "Mật khẩu cũ sai!";

      await userCollection.update(where.eq('email', email), modify.set('password', _hashPassword(newPassword)));
      return "Success";
    } catch (e) {
      return "Lỗi server: $e";
    }
  }

  // --- 7. ĐẨY DỮ LIỆU LÊN SERVER (PUSH) ---
  static Future<bool> updateDailyStats(String email, int steps, int water, int heartRate, {String? customDate}) async {
    try {
      if (db.state != State.open) await connect();

      final dateStr = customDate ?? DateTime.now().toIso8601String().substring(0, 10);

      await healthDataCollection.update(
        where.eq('email', email).eq('date', dateStr),
        modify
            .set('steps', steps)
            .set('water', water)
            .set('heartRate', heartRate)
            .set('lastUpdated', DateTime.now().toIso8601String()),
        upsert: true,
      );
      return true;
    } catch (e) {
      log("Lỗi đồng bộ: $e");
      return false;
    }
  }

  // --- 8. LẤY DỮ LIỆU TỪ SERVER VỀ (PULL) ---
  static Future<List<Map<String, dynamic>>> getWeeklyData(String email) async {
    try {
      if (db.state != State.open) await connect();
      // Lấy 7 ngày gần nhất
      final data = await healthDataCollection
          .find(where.eq('email', email).sortBy('date', descending: true).limit(7))
          .toList();
      return data;
    } catch (e) {
      log("Lỗi lấy dữ liệu: $e");
      return [];
    }
  }
}