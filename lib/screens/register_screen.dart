import 'package:flutter/material.dart';
import 'package:health_app/services/mongodb_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  // Hàm hiển thị thông báo lỗi nhanh
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _register() async {
    // 1. Kiểm tra nhập trống
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty ||
        _heightController.text.isEmpty ||
        _weightController.text.isEmpty) {
      _showError("Vui lòng điền đầy đủ tất cả thông tin!");
      return;
    }

    // 2. Kiểm tra mật khẩu khớp
    if (_passwordController.text != _confirmPasswordController.text) {
      _showError("Mật khẩu xác nhận không khớp!");
      return;
    }

    // 3. Parse số liệu
    final double? height = double.tryParse(_heightController.text);
    final double? weight = double.tryParse(_weightController.text);

    // 4. KIỂM TRA GIỚI HẠN CON NGƯỜI (LOGIC MỚI)
    if (height == null || height < 50 || height > 300) {
      _showError("Chiều cao không hợp lệ! (Phải từ 50cm - 300cm)");
      return;
    }

    if (weight == null || weight < 20 || weight > 500) {
      _showError("Cân nặng không hợp lệ! (Phải từ 20kg - 500kg)");
      return;
    }

    // 5. Bắt đầu gửi dữ liệu
    setState(() => _isLoading = true);

    final result = await MongoDatabase.register(
      _emailController.text.trim(),
      _passwordController.text.trim(),
      _nameController.text.trim(),
      height: height,
      weight: weight,
    );

    setState(() => _isLoading = false);

    // 6. Xử lý kết quả
    if (result == "Success") {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ Đăng ký thành công! Hãy đăng nhập."),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context); // Quay về màn hình đăng nhập
    } else {
      _showError(result); // Hiện lỗi từ server (ví dụ: Email đã tồn tại)
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Tạo tài khoản mới"),
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person_add_outlined, size: 60, color: Colors.green.shade700),
              ),
              const SizedBox(height: 24),

              // Form nhập liệu
              _buildTextField(_nameController, "Họ và tên", Icons.person),
              const SizedBox(height: 16),
              _buildTextField(_emailController, "Email", Icons.email, type: TextInputType.emailAddress),
              const SizedBox(height: 16),

              // Hàng nhập Chiều cao & Cân nặng
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(_heightController, "Cao (cm)", Icons.height, type: TextInputType.number),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(_weightController, "Nặng (kg)", Icons.monitor_weight, type: TextInputType.number),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              _buildTextField(_passwordController, "Mật khẩu", Icons.lock, isObscure: true),
              const SizedBox(height: 16),
              _buildTextField(_confirmPasswordController, "Nhập lại mật khẩu", Icons.lock_outline, isObscure: true),

              const SizedBox(height: 32),

              // Nút Đăng ký
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("ĐĂNG KÝ NGAY", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),

              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Đã có tài khoản? Đăng nhập"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget TextField tái sử dụng cho gọn code
  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isObscure = false, TextInputType? type}) {
    return TextField(
      controller: controller,
      obscureText: isObscure,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.green.shade700),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.green.shade700, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }
}