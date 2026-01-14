import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pedometer/pedometer.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:health_app/model/reminder.dart';
import 'package:permission_handler/permission_handler.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Box<Reminder> _reminderBox = Hive.box<Reminder>('reminders');
  final Box<int> _healthBox = Hive.box<int>('health_data');
  final Box _historyBox = Hive.box('history');
  late final Box _settingsBox;
  int _waterIntake = 0;
  final int _dailyGoal = 3700;
  int _steps = 0;
  int _initialSteps = 0;
  int _stepsToday = 0;
  final int _stepGoal = 5000;
  bool _isDarkMode = true;

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    tz.initializeTimeZones();
    _initializeNotifications();
    _requestPermissions();
    _loadData();
    _settingsBox = Hive.box('settings');
    _isDarkMode = _settingsBox.get('darkMode', defaultValue: true) ?? true;
  }

  Future<void> _requestPermissions() async {
    // Yêu cầu quyền activityRecognition cho bước chân
    var activityStatus = await Permission.activityRecognition.status;
    if (!activityStatus.isGranted) {
      activityStatus = await Permission.activityRecognition.request();
      if (activityStatus.isGranted) {
        print("Quyền truy cập cảm biến bước chân đã được cấp!");
        _initStepCounter();
      } else {
        print("Quyền truy cập cảm biến bước chân bị từ chối.");
      }
    } else {
      _initStepCounter();
    }

    // Yêu cầu quyền thông báo
    var notificationStatus = await Permission.notification.status;
    if (!notificationStatus.isGranted) {
      notificationStatus = await Permission.notification.request();
      if (notificationStatus.isGranted) {
        print("Quyền thông báo đã được cấp!");
      } else {
        print("Quyền thông báo bị từ chối.");
      }
    }

    // Yêu cầu quyền SCHEDULE_EXACT_ALARM (Android 12+)
    var alarmStatus = await Permission.scheduleExactAlarm.status;
    if (!alarmStatus.isGranted) {
      alarmStatus = await Permission.scheduleExactAlarm.request();
      if (alarmStatus.isGranted) {
        print("Quyền lập lịch báo thức chính xác đã được cấp!");
      } else {
        print("Quyền lập lịch báo thức chính xác bị từ chối.");
      }
    }
  }

  void _loadData() {
    setState(() {
      _waterIntake = _healthBox.get('waterIntake', defaultValue: 0) ?? 0;
      _initialSteps = _healthBox.get('initialSteps', defaultValue: 0) ?? 0;
      _steps = _healthBox.get('steps', defaultValue: 0) ?? 0;
      _stepsToday = _steps - _initialSteps;

      final now = DateTime.now();
      final lastReset = DateTime.fromMillisecondsSinceEpoch(
          _healthBox.get('lastReset', defaultValue: 0) ?? 0);

      if (now.day != lastReset.day ||
          now.month != lastReset.month ||
          now.year != lastReset.year) {
        final yesterdayKey =
            "${lastReset.year}-${lastReset.month}-${lastReset.day}";
        _historyBox.put('water_$yesterdayKey', _waterIntake);
        _historyBox.put('steps_$yesterdayKey', _stepsToday);

        _waterIntake = 0;
        _initialSteps = _steps;
        _stepsToday = 0;
        _healthBox.put('waterIntake', _waterIntake);
        _healthBox.put('initialSteps', _initialSteps);
        _healthBox.put('lastReset', now.millisecondsSinceEpoch);
      }
    });
  }

  void _initStepCounter() {
    Pedometer.stepCountStream.listen(
          (StepCount event) {
        print("Số bước hiện tại: ${event.steps}, Thời gian: ${event.timeStamp}");
        setState(() {
          _steps = event.steps;
          _stepsToday = _steps - _initialSteps;
          _healthBox.put('steps', _steps);

          final now = DateTime.now();
          final todayKey = "${now.year}-${now.month}-${now.day}";
          _historyBox.put('steps_$todayKey', _stepsToday);
        });
      },
      onDone: () {
        print("Luồng bước chân đã kết thúc.");
      },
      onError: (error) {
        print("Lỗi đo bước chân: $error");
      },
    );
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings =
    InitializationSettings(android: androidSettings);
    bool? initialized =
    await flutterLocalNotificationsPlugin.initialize(initSettings);
    print("Khởi tạo thông báo: ${initialized == true ? 'Thành công' : 'Thất bại'}");
  }

  void _addReminder(String message, DateTime time, {String? frequency}) {
    final newReminder = Reminder(
      id: _reminderBox.length,
      message: message,
      time: time,
      frequency: frequency,
    );
    _reminderBox.add(newReminder);
    setState(() {});
    _scheduleNotification(newReminder);
  }

  Future<void> _scheduleNotification(Reminder reminder) async {
    if (!reminder.isEnabled) {
      print("Nhắc nhở ${reminder.id} không được bật, bỏ qua lập lịch.");
      return;
    }

    final scheduledTime = tz.TZDateTime.from(reminder.time, tz.local);
    print(
        "Lập lịch thông báo ID ${reminder.id} lúc ${scheduledTime.toString()} với nội dung: ${reminder.message}");

    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        reminder.id,
        "Nhắc nhở sức khỏe",
        reminder.message,
        scheduledTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'reminder_channel_v2', // <--- SỬA THÀNH 'reminder_channel_v2'
            'Nhắc nhở sức khỏe',   // <--- SỬA TÊN CHO KHỚP
            channelDescription: 'Kênh nhắc nhở sức khỏe quan trọng',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,       // Đảm bảo có tiếng
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, // Quan trọng: Cho phép báo ngay cả khi máy nghỉ
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // Quan trọng: Để lặp lại hàng ngày đúng giờ
      );
      print("✅ Đã lập lịch: ${reminder.time}");
    } catch (e) {
      print("❌ Lỗi lập lịch: $e");
    }
  }

  void _deleteReminder(int index) {
    _reminderBox.deleteAt(index);
    setState(() {});
  }

  void _addWaterIntake(int amount) {
    setState(() {
      _waterIntake += amount;
      if (_waterIntake > _dailyGoal) _waterIntake = _dailyGoal;
      _healthBox.put('waterIntake', _waterIntake);

      final now = DateTime.now();
      final todayKey = "${now.year}-${now.month}-${now.day}";
      _historyBox.put('water_$todayKey', _waterIntake);
    });
  }

  void _resetWaterIntake() {
    setState(() {
      final now = DateTime.now();
      final todayKey = "${now.year}-${now.month}-${now.day}";
      _waterIntake = 0;
      _healthBox.put('waterIntake', _waterIntake);
      _historyBox.put('water_$todayKey', _waterIntake);
    });
  }

  Future<void> _showTimePicker() async {
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
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

      String? frequency = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Chọn tần suất'),
          content: DropdownButton<String>(
            value: 'none',
            items: const [
              DropdownMenuItem(value: 'none', child: Text('Không lặp lại')),
              DropdownMenuItem(value: 'daily', child: Text('Hàng ngày')),
              DropdownMenuItem(value: 'weekly', child: Text('Hàng tuần')),
            ],
            onChanged: (value) => Navigator.pop(context, value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
          ],
        ),
      );

      if (frequency != null && frequency != 'none') {
        _addReminder('Nhắc nhở uống nước', scheduledTime, frequency: frequency);
      } else {
        _addReminder('Nhắc nhở uống nước', scheduledTime);
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
      _settingsBox.put('darkMode', _isDarkMode);
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _screens = [
      _buildWaterTracker(),
      _buildStepTracker(),
      _buildReminderList(),
    ];

    return Theme(
      data: _isDarkMode
          ? ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        cardColor: const Color(0xFF1C1C1C),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white70),
          headlineSmall:
          TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade800,
            foregroundColor: Colors.white,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF1C1C1C),
          selectedItemColor: Colors.green,
          unselectedItemColor: Colors.grey,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1C1C1C),
          foregroundColor: Colors.white,
        ),
      )
          : ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: Colors.white,
        cardColor: Colors.white,
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.black),
          headlineSmall:
          TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Theo dõi sức khỏe'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(_isDarkMode ? Icons.light_mode : Icons.dark_mode),
              onPressed: _toggleTheme,
            ),
          ],
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return ScaleTransition(
              scale: animation,
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: _screens[_selectedIndex],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.water_drop),
              label: 'Water',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.directions_walk),
              label: 'Steps',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.alarm),
              label: 'Reminders',
            ),
          ],
          type: BottomNavigationBarType.fixed,
        ),
      ),
    );
  }

  Widget _buildWaterTracker() {
    List<FlSpot> waterData = _generateWaterData();

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          color: const Color(0xFF1C1C1C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final circleSize = constraints.maxWidth * 0.3;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Lượng nước đã uống",
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: circleSize,
                            height: circleSize,
                            child: CircularProgressIndicator(
                              value: _waterIntake / _dailyGoal,
                              strokeWidth: 10,
                              backgroundColor: Colors.grey.shade800,
                              valueColor:
                              AlwaysStoppedAnimation(Colors.green.shade700),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "$_waterIntake ml",
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              ),
                              Text(
                                "/ $_dailyGoal ml",
                                style: const TextStyle(
                                    fontSize: 14, color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 150,
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: true,
                            verticalInterval: 1,
                            horizontalInterval: 1000,
                            getDrawingHorizontalLine: (value) => FlLine(
                              color: Colors.grey.withOpacity(0.2),
                              strokeWidth: 1,
                            ),
                            getDrawingVerticalLine: (value) => FlLine(
                              color: Colors.grey.withOpacity(0.2),
                              strokeWidth: 1,
                            ),
                          ),
                          lineTouchData: LineTouchData(
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipItems: (touchedSpots) => touchedSpots
                                  .map((spot) => LineTooltipItem(
                                '${spot.y.toInt()} ml',
                                const TextStyle(color: Colors.white),
                              ))
                                  .toList(),
                            ),
                          ),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                interval: 1000,
                                getTitlesWidget: (value, meta) {
                                  return Text(
                                    value.toInt().toString(),
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 12),
                                  );
                                },
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: 1,
                                getTitlesWidget: (value, meta) {
                                  int index = value.toInt();
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      ["T2", "T3", "T4", "T5", "T6", "T7", "CN"]
                                      [index],
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 12),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: waterData,
                              isCurved: true,
                              color: Colors.blueAccent.shade700,
                              dotData: FlDotData(show: true),
                              belowBarData: BarAreaData(show: false),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildWaterButton(250),
                        _buildWaterButton(500),
                        _buildWaterButton(1000),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: ElevatedButton(
                        onPressed: _resetWaterIntake,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent),
                        child: const Text("Đặt lại"),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepTracker() {
    List<FlSpot> stepData = _generateStepData();

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          color: const Color(0xFF1C1C1C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final chartHeight =
                constraints.maxHeight > 400 ? 150.0 : constraints.maxHeight * 0.3;
                final circleSize = constraints.maxWidth * 0.3;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Số bước chân hôm nay",
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: circleSize,
                            height: circleSize,
                            child: CircularProgressIndicator(
                              value: _stepsToday / _stepGoal,
                              strokeWidth: 10,
                              backgroundColor: Colors.grey.shade800,
                              valueColor:
                              AlwaysStoppedAnimation(Colors.green.shade700),
                            ),
                          ),
                          Text(
                            "$_stepsToday bước",
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: chartHeight,
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: true,
                            verticalInterval: 1,
                            horizontalInterval: 1000,
                            getDrawingHorizontalLine: (value) => FlLine(
                              color: Colors.grey.withOpacity(0.2),
                              strokeWidth: 1,
                            ),
                            getDrawingVerticalLine: (value) => FlLine(
                              color: Colors.grey.withOpacity(0.2),
                              strokeWidth: 1,
                            ),
                          ),
                          lineTouchData: LineTouchData(
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipItems: (touchedSpots) => touchedSpots
                                  .map((spot) => LineTooltipItem(
                                '${spot.y.toInt()} bước',
                                const TextStyle(color: Colors.white),
                              ))
                                  .toList(),
                            ),
                          ),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                interval: 1000,
                                getTitlesWidget: (value, meta) {
                                  return Text(
                                    value.toInt().toString(),
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 12),
                                  );
                                },
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: 1,
                                getTitlesWidget: (value, meta) {
                                  int index = value.toInt();
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      ["T2", "T3", "T4", "T5", "T6", "T7", "CN"]
                                      [index],
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 12),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: stepData,
                              isCurved: true,
                              color: Colors.blueAccent.shade700,
                              dotData: FlDotData(show: true),
                              belowBarData: BarAreaData(show: false),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReminderList() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Danh sách nhắc nhở",
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _showTimePicker,
            icon: const Icon(Icons.add),
            label: const Text("Thêm nhắc nhở"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade800,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: _reminderBox.listenable(),
              builder: (context, Box<Reminder> box, _) {
                if (box.isEmpty) {
                  return const Center(
                      child: Text(
                        'Chưa có nhắc nhở nào!',
                        style: TextStyle(color: Colors.white70),
                      ));
                }
                return ListView.builder(
                  itemCount: box.length,
                  itemBuilder: (context, index) {
                    final reminder = box.getAt(index);
                    if (reminder == null) {
                      return const SizedBox.shrink();
                    }
                    return Card(
                      color: const Color(0xFF1C1C1C),
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        leading: Icon(
                          Icons.alarm,
                          color: reminder.isEnabled ? Colors.green : Colors.grey,
                        ),
                        title: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Expanded(
                              child: Text(
                                reminder.message,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: reminder.isEnabled
                                      ? Colors.white
                                      : Colors.grey,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (reminder.frequency != null) ...[
                              const SizedBox(width: 8),
                              Chip(
                                label: Text(
                                  reminder.frequency!,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                backgroundColor: Colors.green.shade900,
                                padding:
                                const EdgeInsets.symmetric(horizontal: 4),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          "${reminder.time.hour}:${reminder.time.minute.toString().padLeft(2, '0')} - ${reminder.time.day}/${reminder.time.month}/${reminder.time.year}",
                          style: const TextStyle(color: Colors.white70),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                reminder.isEnabled
                                    ? Icons.check_circle
                                    : Icons.check_circle_outline,
                                color: reminder.isEnabled
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                              onPressed: () {
                                final updatedReminder = Reminder(
                                  id: reminder.id,
                                  message: reminder.message,
                                  time: reminder.time,
                                  isEnabled: !reminder.isEnabled,
                                  frequency: reminder.frequency,
                                );
                                _reminderBox.putAt(index, updatedReminder);
                                if (!updatedReminder.isEnabled) {
                                  flutterLocalNotificationsPlugin
                                      .cancel(reminder.id);
                                } else {
                                  _scheduleNotification(updatedReminder);
                                }
                                setState(() {});
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteReminder(index),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaterButton(int amount) {
    return ElevatedButton(
      onPressed: () => _addWaterIntake(amount),
      child: Text("+$amount ml"),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green.shade800,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 2,
        shadowColor: Colors.green.withOpacity(0.5),
      ).copyWith(
        overlayColor: WidgetStateProperty.all(Colors.green.shade900),
      ),
    );
  }

  List<FlSpot> _generateWaterData() {
    List<FlSpot> waterData = [];
    final now = DateTime.now();

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateKey = "${date.year}-${date.month}-${date.day}";
      final water = _historyBox.get('water_$dateKey', defaultValue: 0) ?? 0;
      waterData.add(FlSpot((6 - i).toDouble(), water.toDouble()));
    }
    return waterData;
  }

  List<FlSpot> _generateStepData() {
    List<FlSpot> stepData = [];
    final now = DateTime.now();

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateKey = "${date.year}-${date.month}-${date.day}";
      final steps = _historyBox.get('steps_$dateKey', defaultValue: 0) ?? 0;
      stepData.add(FlSpot((6 - i).toDouble(), steps.toDouble()));
    }
    return stepData;
  }
}