import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:health_app/model/reminder.dart';
import 'package:health_app/screens/login_screen.dart';
import 'package:health_app/screens/home_screen.dart'; // Import HomeScreen
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:health_app/services/mongodb_service.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Cần thêm để check đăng nhập

late final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Khởi tạo kết nối MongoDB
  await MongoDatabase.connect();

  // 2. Khởi tạo Hive
  print("Initializing Hive...");
  await Hive.initFlutter();
  Hive.registerAdapter(ReminderAdapter());

  try {
    // Mở các box cần thiết
    await Hive.openBox<Reminder>('reminders');
    await Hive.openBox<int>('health_data');
    await Hive.openBox('history');
    await Hive.openBox('settings');
    await Hive.openBox<Map>('stepGoals');
    print("✅ Hive boxes opened successfully");
  } catch (e) {
    print("❌ Lỗi khi khởi tạo Hive: $e");
  }

  // 3. Khởi tạo timezone
  tz.initializeTimeZones();

  // 4. Khởi tạo thông báo (Cấu hình âm thanh)
  await _initializeNotifications();

  // 5. KIỂM TRA TRẠNG THÁI ĐĂNG NHẬP
  final prefs = await SharedPreferences.getInstance();
  final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  print("Starting app... Logged in: $isLoggedIn");

  // Truyền trạng thái đăng nhập vào MyApp
  runApp(MyApp(startScreen: isLoggedIn ? const HomeScreen() : const LoginScreen()));
}

Future<void> _initializeNotifications() async {
  print("Initializing notifications...");
  flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  const AndroidInitializationSettings androidSettings =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initSettings =
  InitializationSettings(android: androidSettings);

  await flutterLocalNotificationsPlugin.initialize(initSettings);

  // --- CẤU HÌNH KÊNH THÔNG BÁO CÓ TIẾNG ---
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'reminder_channel_v2', // Đổi tên ID để reset cấu hình cũ trên máy
    'Nhắc nhở sức khỏe',
    description: 'Kênh nhắc nhở sức khỏe quan trọng',
    importance: Importance.max, // Mức cao nhất để hiện popup
    playSound: true,            // Bắt buộc có tiếng
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  print("✅ Kênh thông báo đã được tạo (Có tiếng).");
}

class MyApp extends StatelessWidget {
  final Widget startScreen;

  // Nhận màn hình bắt đầu từ main
  const MyApp({super.key, required this.startScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Health App',
      theme: ThemeData(
        primarySwatch: Colors.green,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.green.shade800,
          foregroundColor: Colors.white,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.light,
      // Tự động vào Home hoặc Login tùy trạng thái
      home: startScreen,
    );
  }
}