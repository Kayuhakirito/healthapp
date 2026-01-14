import 'package:flutter/material.dart';
import '../utils/preferences_util.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController waterGoalController = TextEditingController();
  final TextEditingController stepGoalController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadSettings();
  }

  // Tải cài đặt từ SharedPreferences
  void loadSettings() async {
    final waterGoal = await PreferencesUtil.getWaterGoal();
    final stepGoal = await PreferencesUtil.getStepGoal();
    setState(() {
      waterGoalController.text = waterGoal.toString();
      stepGoalController.text = stepGoal.toString();
    });
  }

  // Lưu cài đặt vào SharedPreferences
  void saveSettings() async {
    final waterGoal = int.tryParse(waterGoalController.text) ?? 2000;
    final stepGoal = int.tryParse(stepGoalController.text) ?? 10000;

    await PreferencesUtil.setWaterGoal(waterGoal); // Sửa từ saveWaterGoal thành setWaterGoal
    await PreferencesUtil.setStepGoal(stepGoal);   // Sửa từ saveStepGoal thành setStepGoal

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Cài đặt đã được lưu!")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Cài đặt"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Mục tiêu lượng nước uống (ml):",
              style: TextStyle(fontSize: 16),
            ),
            TextField(
              controller: waterGoalController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: "Nhập mục tiêu (vd: 2000)",
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Mục tiêu số bước đi:",
              style: TextStyle(fontSize: 16),
            ),
            TextField(
              controller: stepGoalController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: "Nhập mục tiêu (vd: 10000)",
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: saveSettings,
                child: const Text("Lưu cài đặt"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}