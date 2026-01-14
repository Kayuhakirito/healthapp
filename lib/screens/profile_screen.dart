import 'package:flutter/material.dart';
import 'package:health_app/services/mongodb_service.dart';
import 'package:health_app/utils/preferences_util.dart';
import 'package:health_app/screens/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  String? _currentUserEmail;
  bool _isLoading = true;

  // Biến cho BMI
  double _bmi = 0.0;
  String _bmiStatus = "";
  Color _bmiColor = Colors.grey;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true); // Bật loading ngay lập tức

    final email = await PreferencesUtil.getUserEmail();
    if (email == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Thêm timeout để không đợi quá lâu (5 giây)
      final userData = await MongoDatabase.getUserByEmail(email).timeout(const Duration(seconds: 5));

      if (userData != null && mounted) {
        setState(() {
          _currentUserEmail = email;
          _nameController.text = userData['name'] ?? "";
          _heightController.text = userData['height']?.toString() ?? "";
          _weightController.text = userData['weight']?.toString() ?? "";
          _calculateBMI();
        });
      }
    } catch (e) {
      // Nếu mạng quá chậm, lấy tạm dữ liệu cũ từ Hive (nếu có) hoặc báo lỗi nhẹ
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mạng chậm, chưa tải được hồ sơ mới nhất")));
    } finally {
      if (mounted) setState(() => _isLoading = false); // Tắt loading dù thành công hay thất bại
    }
  }

  // --- LOGIC TÍNH BMI ---
  void _calculateBMI() {
    double h = double.tryParse(_heightController.text) ?? 0;
    double w = double.tryParse(_weightController.text) ?? 0;

    if (h > 0 && w > 0) {
      // Công thức: BMI = Cân nặng (kg) / (Chiều cao (m) ^ 2)
      double heightInMeter = h / 100;
      double bmiValue = w / (heightInMeter * heightInMeter);

      String status;
      Color color;

      if (bmiValue < 18.5) {
        status = "Thiếu cân - Cần ăn uống điều độ hơn!";
        color = Colors.orange;
      } else if (bmiValue < 24.9) {
        status = "Bình thường - Hãy duy trì nhé!";
        color = Colors.green;
      } else if (bmiValue < 29.9) {
        status = "Thừa cân - Nên vận động nhiều hơn.";
        color = Colors.orange.shade700;
      } else {
        status = "Béo phì - Cần chế độ tập luyện ngay!";
        color = Colors.red;
      }

      setState(() {
        _bmi = bmiValue;
        _bmiStatus = status;
        _bmiColor = color;
      });
    }
  }

  Future<void> _updateInfo() async {
    if (_currentUserEmail == null) return;
    final double? height = double.tryParse(_heightController.text);
    final double? weight = double.tryParse(_weightController.text);

    if (height == null || height < 50 || height > 300) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Chiều cao không hợp lệ!")));
      return;
    }

    bool success = await MongoDatabase.updateProfile(_currentUserEmail!, _nameController.text, height!, weight!);
    if (success) {
      _calculateBMI(); // Tính lại BMI sau khi lưu
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Cập nhật thành công!"), backgroundColor: Colors.green));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("Hồ sơ sức khỏe"), elevation: 0),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Avatar & Email
            const CircleAvatar(radius: 40, backgroundColor: Colors.blueAccent, child: Icon(Icons.person, size: 50, color: Colors.white)),
            const SizedBox(height: 10),
            Text(_currentUserEmail ?? "", style: const TextStyle(color: Colors.grey)),

            const SizedBox(height: 20),

            // --- THẺ BMI (LOGIC MỚI) ---
            if (_bmi > 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                    color: _bmiColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: _bmiColor.withOpacity(0.5))
                ),
                child: Column(
                  children: [
                    const Text("Chỉ số BMI của bạn", style: TextStyle(fontSize: 16)),
                    Text(_bmi.toStringAsFixed(1), style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: _bmiColor)),
                    Text(_bmiStatus, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _bmiColor), textAlign: TextAlign.center),
                  ],
                ),
              ),

            // Form nhập liệu
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: "Họ tên", border: OutlineInputBorder(), prefixIcon: Icon(Icons.badge))),
            const SizedBox(height: 15),
            Row(children: [
              Expanded(child: TextField(controller: _heightController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Chiều cao (cm)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.height)))),
              const SizedBox(width: 15),
              Expanded(child: TextField(controller: _weightController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Cân nặng (kg)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.monitor_weight)))),
            ]),

            const SizedBox(height: 30),
            SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _updateInfo, style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent), child: const Text("CẬP NHẬT & TÍNH BMI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),

            const SizedBox(height: 20),
            TextButton(
              onPressed: () async {
                await PreferencesUtil.clearUserSession();
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
              },
              child: const Text("Đăng xuất", style: TextStyle(color: Colors.red)),
            )
          ],
        ),
      ),
    );
  }
}