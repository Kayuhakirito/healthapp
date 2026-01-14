import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pedometer/pedometer.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:health_app/model/reminder.dart';
import 'package:health_app/utils/preferences_util.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:health_app/main.dart';
import 'package:health_app/screens/login_screen.dart';
import 'package:health_app/screens/profile_screen.dart';
import 'package:health_app/services/mongodb_service.dart';
import 'package:health_app/screens/history_screen.dart';
import 'package:health_app/screens/heart_rate_screen.dart';
import 'package:health_app/screens/ai_chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final String apiKey = "AIzaSyAUwsVlB1CXypXKIbA6XYq-Ti1QAabCTyY";

  late Box<Reminder> _reminderBox;
  late Box<int> _healthBox;
  late Box _historyBox;
  late Box _settingsBox;


  int _waterIntake = 0;
  int _steps = 0;
  int _initialSteps = -1;
  int _stepsToday = 0;
  int _caloriesBurned = 0;
  int _heartRate = 0;
  int _selectedIndex = 0;
  bool _isLoading = true;
  bool _isAnalyzingImage = false;
  int _dailyWaterGoal = 2000;
  int _dailyStepGoal = 10000;

  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    tz.initializeTimeZones();
    _initData();
    _requestPermissions();

    _syncTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _syncData(isSilent: true);
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> _initData() async {
    if (!Hive.isBoxOpen('reminders')) await Hive.openBox<Reminder>('reminders');
    if (!Hive.isBoxOpen('health_data')) await Hive.openBox<int>('health_data');
    if (!Hive.isBoxOpen('history')) await Hive.openBox('history');
    if (!Hive.isBoxOpen('settings')) await Hive.openBox('settings');

    _reminderBox = Hive.box<Reminder>('reminders');
    _healthBox = Hive.box<int>('health_data');
    _historyBox = Hive.box('history');
    _settingsBox = Hive.box('settings');

    _dailyWaterGoal = await PreferencesUtil.getWaterGoal();
    _dailyStepGoal = await PreferencesUtil.getStepGoal();

    _loadLocalData();
    _syncData(isSilent: true);

    if (mounted) setState(() => _isLoading = false);
  }

  void _loadLocalData() {
    if (!mounted) return;
    setState(() {
      _waterIntake = _healthBox.get('waterIntake', defaultValue: 0) ?? 0;
      _heartRate = _healthBox.get('heartRate', defaultValue: 0) ?? 0;
      _initialSteps = _healthBox.get('initialSteps', defaultValue: -1) ?? -1;
      _steps = _healthBox.get('steps', defaultValue: 0) ?? 0;

      if (_initialSteps == -1) {
        _stepsToday = 0;
      } else {
        if (_steps < _initialSteps) {
          _initialSteps = _steps;
          _healthBox.put('initialSteps', _initialSteps);
        }
        _stepsToday = (_steps - _initialSteps).clamp(0, 99999);
      }
      _caloriesBurned = (_stepsToday * 0.04).toInt();
    });
  }

  Future<void> _syncData({bool isSilent = false}) async {
    final email = await PreferencesUtil.getUserEmail();
    if (email == null) return;

    if (!isSilent) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đang đồng bộ..."), duration: Duration(seconds: 1)));
    }

    bool hasError = false;

    try {
      String todayKey = _getDateKey(0);
      await MongoDatabase.updateDailyStats(email, _stepsToday, _waterIntake, _heartRate, customDate: todayKey);
      final serverData = await MongoDatabase.getWeeklyData(email);

      if (serverData.isNotEmpty) {
        for (var item in serverData) {
          String date = item['date'];
          int s = item['steps'] ?? 0;
          int w = item['water'] ?? 0;
          int hr = item['heartRate'] ?? 0;

          _historyBox.put('steps_$date', s);
          _historyBox.put('water_$date', w);

          if (date == todayKey) {
            if (mounted) {
              setState(() {
                if (s > _stepsToday) {
                  _stepsToday = s;
                  _initialSteps = _steps - _stepsToday;
                  _healthBox.put('initialSteps', _initialSteps);
                }
                if (w > _waterIntake) {
                  _waterIntake = w;
                  _healthBox.put('waterIntake', w);
                }
                if (hr > 0) {
                  _heartRate = hr;
                  _healthBox.put('heartRate', hr);
                }
              });
            }
          }
        }
      }
    } catch (e) {
      hasError = true;
      print("Sync Error: $e");
    }

    if (!isSilent) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (!hasError) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Đã đồng bộ!"), backgroundColor: Colors.green));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("⚠️ Lỗi kết nối Server"), backgroundColor: Colors.orange));
      }
    }
  }

  Future<void> _scanWaterBottle() async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 50);
    if (photo != null) {
      setState(() => _isAnalyzingImage = true);

      try {
        final model = GenerativeModel(
          model: 'gemini-1.5-flash',
          apiKey: apiKey,
        );

        final imageBytes = await File(photo.path).readAsBytes();
        final prompt = TextPart("Hãy nhìn bức ảnh này. Nếu đây là chai nước, ly nước hoặc bình nước, hãy ước lượng dung tích của nó bằng ml. Chỉ trả về một con số duy nhất (ví dụ: 300). Nếu không phải bình nước hoặc không xác định được, trả về 0.");
        final imagePart = DataPart('image/jpeg', imageBytes);
        final response = await model.generateContent([
          Content.multi([prompt, imagePart])
        ]);
        final text = response.text?.trim() ?? "0";
        final int estimatedMl = int.tryParse(RegExp(r'\d+').firstMatch(text)?.group(0) ?? "0") ?? 0;

        if (estimatedMl > 0) {
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("AI Nhận diện"),
              content: Text("AI đoán đây là bình nước khoảng $estimatedMl ml.\nBạn có muốn thêm vào nhật ký không?"),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Sai rồi")),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _waterIntake += estimatedMl;
                      _healthBox.put('waterIntake', _waterIntake);
                    });
                    _syncData(isSilent: true);
                    Navigator.pop(ctx);
                  },
                  child: const Text("Thêm ngay"),
                )
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("⚠️ AI không nhìn thấy bình nước nào rõ ràng!")));
        }

      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi AI: $e")));
      } finally {
        setState(() => _isAnalyzingImage = false);
      }
    }
  }
  Future<void> _requestPermissions() async {
    await [Permission.activityRecognition, Permission.notification, Permission.scheduleExactAlarm, Permission.camera].request();
    _initStepCounter();
  }

  void _initStepCounter() {
    Pedometer.stepCountStream.listen((StepCount event) {
      if (!mounted) return;
      setState(() {
        if (_initialSteps == -1) {
          _initialSteps = event.steps;
          _healthBox.put('initialSteps', _initialSteps);
        }
        _steps = event.steps;

        final lastSyncDate = DateTime.fromMillisecondsSinceEpoch(_healthBox.get('last_reset_time', defaultValue: 0) ?? 0);
        final now = DateTime.now();
        if (lastSyncDate.day != now.day) {
          _initialSteps = _steps;
          _healthBox.put('initialSteps', _initialSteps);
          _healthBox.put('last_reset_time', now.millisecondsSinceEpoch);
          _waterIntake = 0;
          _healthBox.put('waterIntake', 0);
          _heartRate = 0;
          _healthBox.put('heartRate', 0);
        }

        _stepsToday = (_steps - _initialSteps).clamp(0, 99999);
        _caloriesBurned = (_stepsToday * 0.04).toInt();

        final key = _getDateKey(0);
        _historyBox.put('steps_$key', _stepsToday);
        _historyBox.put('water_$key', _waterIntake);
      });
    }, onError: (e) => print("Lỗi Pedometer: $e"));
  }

  Future<void> _editGoal(String type) async {
    TextEditingController controller = TextEditingController();
    String title = type == 'step' ? "bước chân" : "nước uống";
    String unit = type == 'step' ? "bước" : "ml";

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Sửa mục tiêu $title"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: "Nhập số $unit"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Hủy")),
          ElevatedButton(
            onPressed: () {
              int? val = int.tryParse(controller.text);
              if (val != null && val > 0) {
                setState(() {
                  if (type == 'step') {
                    _dailyStepGoal = val;
                    PreferencesUtil.setStepGoal(val);
                  } else {
                    _dailyWaterGoal = val;
                    PreferencesUtil.setWaterGoal(val);
                  }
                });
                Navigator.pop(context);
                _syncData(isSilent: true);
              }
            },
            child: const Text("Lưu"),
          )
        ],
      ),
    );
  }

  Future<void> _showTimePicker() async {
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      helpText: "CHỌN GIỜ NHẮC",
    );

    if (selectedTime != null) {
      final now = DateTime.now();
      var scheduledTime = DateTime(
        now.year,
        now.month,
        now.day,
        selectedTime.hour,
        selectedTime.minute,
      );

      if (scheduledTime.isBefore(now)) {
        scheduledTime = scheduledTime.add(const Duration(days: 1));
      }

      if (!mounted) return;

      String messageInput = "Uống nước nhé!";
      String frequencyInput = "daily";

      await showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text("Cài đặt nhắc nhở"),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      onChanged: (value) => messageInput = value,
                      decoration: const InputDecoration(
                        labelText: "Nội dung nhắc nhở",
                        hintText: "Ví dụ: Uống thuốc, Đi chạy bộ...",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.edit_note),
                      ),
                      controller: TextEditingController(text: messageInput),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        const Text("Lặp lại: ",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 10),
                        DropdownButton<String>(
                          value: frequencyInput,
                          items: const [
                            DropdownMenuItem(value: 'none', child: Text('Một lần')),
                            DropdownMenuItem(value: 'daily', child: Text('Hằng ngày')),
                            DropdownMenuItem(value: 'weekly', child: Text('Hằng tuần')),
                          ],
                          onChanged: (value) {
                            setDialogState(() {
                              frequencyInput = value!;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      _addReminderWithDetails(
                          messageInput.isEmpty ? "Nhắc nhở sức khỏe" : messageInput,
                          scheduledTime,
                          frequencyInput);
                      Navigator.pop(context);
                    },
                    child: const Text('Lưu'),
                  ),
                ],
              );
            },
          );
        },
      );
    }
  }

  void _addReminderWithDetails(String message, DateTime time, String frequency) {
    final newReminder = Reminder(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      message: message,
      time: time,
      isEnabled: true,
      frequency: frequency,
    );
    _reminderBox.add(newReminder);
    _scheduleNotification(newReminder);
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Đã đặt: $message lúc ${time.hour}:${time.minute.toString().padLeft(2, '0')}")));
  }

  void _deleteReminder(int index) {
    final r = _reminderBox.getAt(index);
    if (r != null) flutterLocalNotificationsPlugin.cancel(r.id);
    _reminderBox.deleteAt(index);
    setState(() {});
  }

  Future<void> _scheduleNotification(Reminder reminder) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'reminder_channel_v2', 'Nhắc nhở sức khỏe',
        importance: Importance.max, priority: Priority.high,
        playSound: true, enableVibration: true,
      ),
    );
    var scheduledDate = tz.TZDateTime.from(reminder.time, tz.local);
    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    DateTimeComponents? match;
    if (reminder.frequency == 'daily') match = DateTimeComponents.time;
    if (reminder.frequency == 'weekly') match = DateTimeComponents.dayOfWeekAndTime;

    await flutterLocalNotificationsPlugin.zonedSchedule(
      reminder.id, "Health Tracker", reminder.message, scheduledDate, details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: match,
    );
  }
  String _getDateKey(int daysAgo) {
    final date = DateTime.now().subtract(Duration(days: daysAgo));
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final List<Widget> screens = [
      _buildDashboardTab(),
      _buildReminderTab(),
      _buildHistoryTab(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Theo dõi sức khỏe cá nhân", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: Colors.purple),
            tooltip: "Hỏi đáp AI",
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AIChatScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.cloud_sync, color: Colors.green),
            tooltip: "Đồng bộ ngay",
            onPressed: () => _syncData(isSilent: false),
          ),
          IconButton(
            icon: const Icon(Icons.person, color: Colors.blue),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
          ),
        ],
      ),
      body: Stack(
        children: [
          screens[_selectedIndex],
          if (_isAnalyzingImage)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 10),
                    Text("AI đang nhìn bình nước của bạn...", style: TextStyle(color: Colors.white, fontSize: 16)),
                  ],
                ),
              ),
            )
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        backgroundColor: Colors.white,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Tổng quan'),
          NavigationDestination(icon: Icon(Icons.alarm_outlined), selectedIcon: Icon(Icons.alarm), label: 'Nhắc nhở'),
          NavigationDestination(icon: Icon(Icons.insights), selectedIcon: Icon(Icons.insights), label: 'Lịch sử'),
        ],
      ),
    );
  }

  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Hôm nay", style: TextStyle(color: Colors.grey)),
          const Text("Hoạt động của bạn", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),

          _buildStatCard(
            title: "Bước chân", value: "$_stepsToday", unit: "bước",
            subValue: "🔥 $_caloriesBurned kcal", goal: _dailyStepGoal,
            color: const Color(0xFF6B48FF), icon: Icons.directions_walk,
            onEditGoal: () => _editGoal('step'),
          ),
          const SizedBox(height: 15),

          _buildStatCard(
            title: "Thuốc", value: "$_waterIntake", unit: "ml",
            subValue: "${(_waterIntake / _dailyWaterGoal * 100).toInt()}%", goal: _dailyWaterGoal,
            color: const Color(0xFF00C6FF), icon: Icons.favorite, isWater: true,
            onEditGoal: () => _editGoal('water'),
          ),
          const SizedBox(height: 15),

          _buildStatCard(
            title: "Nhịp tim",
            value: _heartRate == 0 ? "--" : "$_heartRate",
            unit: "BPM",
            subValue: _heartRate > 0 ? "Đo gần nhất" : "Chưa có dữ liệu",
            goal: 100,
            color: Colors.redAccent,
            icon: Icons.favorite,
            isHeartRate: true,
            onEditGoal: () async {
              final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const HeartRateScreen()));
              if (result != null && result is int) {
                setState(() {
                  _heartRate = result;
                  _healthBox.put('heartRate', _heartRate);
                });
                _syncData(isSilent: true);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReminderTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              ElevatedButton.icon(
                onPressed: () => _showTimePicker(),
                icon: const Icon(Icons.add_alarm),
                label: const Text("Thêm giờ nhắc uống nước"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)),
              ),
              TextButton(
                onPressed: () => openAppSettings(),
                child: const Text("Không thấy báo thức kêu? Bấm vào đây", style: TextStyle(color: Colors.red, fontSize: 12)),
              )
            ],
          ),
        ),
        Expanded(
          child: ValueListenableBuilder(
            valueListenable: _reminderBox.listenable(),
            builder: (context, Box<Reminder> box, _) {
              if (box.isEmpty) return const Center(child: Text("Chưa có nhắc nhở nào", style: TextStyle(color: Colors.grey)));
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: box.length,
                itemBuilder: (context, index) {
                  final r = box.getAt(index);
                  if (r == null) return const SizedBox.shrink();

                  String freqText = "Một lần";
                  if (r.frequency == 'daily') freqText = "Hằng ngày";
                  if (r.frequency == 'weekly') freqText = "Hằng tuần";

                  return Card(
                    elevation: 2, margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: CircleAvatar(backgroundColor: Colors.blue.withValues(alpha: 0.1), child: const Icon(Icons.alarm, color: Colors.blue)),
                      title: Text("${r.time.hour.toString().padLeft(2, '0')}:${r.time.minute.toString().padLeft(2, '0')}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      subtitle: Text("${r.message}\nLặp lại: $freqText"),
                      isThreeLine: true,
                      trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteReminder(index)),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Align(alignment: Alignment.centerLeft, child: Text("Biểu đồ tuần qua", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          const SizedBox(height: 15),
          Container(
            height: 300, padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true, drawVerticalLine: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (val, meta) {
                    final date = DateTime.now().subtract(Duration(days: 6 - val.toInt()));
                    return Padding(padding: const EdgeInsets.only(top: 8.0), child: Text("${date.day}/${date.month}", style: const TextStyle(fontSize: 10, color: Colors.grey)));
                  }, interval: 1)),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(7, (i) {
                      final key = _getDateKey(6-i);
                      final val = (i == 6 ? _stepsToday : (_historyBox.get('steps_$key') ?? 0)).toDouble();
                      return FlSpot(i.toDouble(), val);
                    }),
                    isCurved: true, color: Colors.purple, barWidth: 3, dotData: FlDotData(show: true),
                  ),
                  LineChartBarData(
                    spots: List.generate(7, (i) {
                      final key = _getDateKey(6-i);
                      final val = (i == 6 ? _waterIntake : (_historyBox.get('water_$key') ?? 0)).toDouble();
                      return FlSpot(i.toDouble(), val);
                    }),
                    isCurved: true, color: Colors.blue.withValues(alpha: 0.5), barWidth: 2, dotData: FlDotData(show: false),
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity, height: 50,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen())),
              icon: const Icon(Icons.history), label: const Text("XEM LỊCH SỬ CHI TIẾT"),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.blue), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title, required String value, required String unit, required String subValue,
    required int goal, required Color color, required IconData icon,
    bool isWater = false, bool isHeartRate = false, required VoidCallback onEditGoal
  }) {
    double progress = (double.tryParse(value) ?? 0) / (goal == 0 ? 1 : goal);

    return GestureDetector(
      onTap: isHeartRate ? onEditGoal : null,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))]),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 28)),
              const SizedBox(width: 15),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                Row(children: [
                  Text("$value $unit", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
                  if (!isHeartRate)
                    IconButton(icon: Icon(Icons.edit, size: 16, color: Colors.grey.shade400), onPressed: onEditGoal)
                ]),
                Text(isHeartRate ? subValue : "Mục tiêu: $goal", style: const TextStyle(color: Colors.orange, fontSize: 13)),
              ]),
            ]),
            SizedBox(height: 50, width: 50, child: CircularProgressIndicator(value: progress.clamp(0.0, 1.0), backgroundColor: Colors.grey.shade200, color: color, strokeWidth: 6)),
          ]),
          if (isWater) ...[
            const SizedBox(height: 20),
            Wrap(
              spacing: 15, runSpacing: 10, alignment: WrapAlignment.center,
              children: [
                _waterBtn(250, color),
                _waterBtn(500, color),

                ElevatedButton.icon(
                  onPressed: _scanWaterBottle,
                  icon: const Icon(Icons.camera_alt, size: 18),
                  label: const Text("AI Scan"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
                ),
                // -----------------------------

                ElevatedButton.icon(
                  onPressed: () async {
                    TextEditingController customWaterController = TextEditingController();
                    await showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("Nhập lượng nước (ml)"),
                        content: TextField(
                          controller: customWaterController,
                          keyboardType: TextInputType.number,
                          autofocus: true,
                          decoration: const InputDecoration(hintText: "Ví dụ: 330", suffixText: "ml", border: OutlineInputBorder()),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Hủy")),
                          ElevatedButton(
                            onPressed: () {
                              int? amount = int.tryParse(customWaterController.text);
                              if (amount != null && amount > 0) {
                                setState(() { _waterIntake += amount; _healthBox.put('waterIntake', _waterIntake); });
                                _syncData(isSilent: true);
                                Navigator.pop(context);
                              }
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            child: const Text("Thêm", style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit, size: 18), label: const Text("Khác"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade800, foregroundColor: Colors.white),
                ),
                IconButton(icon: const Icon(Icons.refresh, color: Colors.red), tooltip: "Đặt lại về 0", onPressed: () { setState(() { _waterIntake = 0; _healthBox.put('waterIntake', 0); }); _syncData(isSilent: true); })
              ],
            )
          ],
          if (isHeartRate) ...[
            const SizedBox(height: 10),
            const Text("Chạm để đo ngay", style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic)),
          ]
        ]),
      ),
    );
  }

  Widget _waterBtn(int amount, Color color) {
    return ElevatedButton(
      onPressed: () {
        setState(() { _waterIntake += amount; _healthBox.put('waterIntake', _waterIntake); });
        _syncData(isSilent: true);
      },
      style: ElevatedButton.styleFrom(backgroundColor: color.withValues(alpha: 0.1), foregroundColor: color, elevation: 0),
      child: Text("+$amount ml"),
    );
  }
}