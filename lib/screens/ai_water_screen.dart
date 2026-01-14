import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:image_picker/image_picker.dart';

class AIWaterScreen extends StatefulWidget {
  final Function(int) onAddWater; // Hàm callback để báo về màn hình chính

  const AIWaterScreen({super.key, required this.onAddWater});

  @override
  State<AIWaterScreen> createState() => _AIWaterScreenState();
}

class _AIWaterScreenState extends State<AIWaterScreen> {
  File? _image;
  final ImagePicker _picker = ImagePicker();
  String _resultText = "Chụp ảnh chai hoặc cốc nước để AI nhận diện";
  bool _isAnalyzing = false;
  bool _foundWater = false;

  // Danh sách từ khóa hợp lệ
  final List<String> _validLabels = [
    'Bottle', 'Water bottle', 'Plastic bottle',
    'Cup', 'Coffee cup', 'Mug', 'Drink', 'Beverage',
    'Glass', 'Liquid', 'Water'
  ];

  // 1. Mở Camera chụp ảnh
  Future<void> _pickImage() async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        setState(() {
          _image = File(photo.path);
          _isAnalyzing = true;
          _resultText = "Đang phân tích...";
          _foundWater = false;
        });
        _processImage(InputImage.fromFilePath(photo.path));
      }
    } catch (e) {
      setState(() => _resultText = "Lỗi Camera: $e");
    }
  }

  // 2. Xử lý ảnh qua Google ML Kit
  Future<void> _processImage(InputImage inputImage) async {
    final ImageLabelerOptions options = ImageLabelerOptions(confidenceThreshold: 0.5); // Độ tin cậy > 50%
    final imageLabeler = ImageLabeler(options: options);

    try {
      final List<ImageLabel> labels = await imageLabeler.processImage(inputImage);

      bool found = false;
      String labelFound = "";

      // Duyệt qua các nhãn mà AI tìm thấy
      for (ImageLabel label in labels) {
        if (_validLabels.contains(label.label)) {
          found = true;
          labelFound = label.label; // Lấy tên vật thể (VD: Bottle)
          break;
        }
      }

      if (found) {
        setState(() {
          _foundWater = true;
          _resultText = "✅ Phát hiện: $labelFound\nBạn có muốn thêm 250ml nước?";
        });
      } else {
        setState(() {
          _foundWater = false;
          _resultText = "❌ Không thấy bình nước nào.\n(AI thấy: ${labels.isNotEmpty ? labels.first.label : 'Không rõ'})";
        });
      }
    } catch (e) {
      setState(() => _resultText = "Lỗi phân tích: $e");
    } finally {
      setState(() => _isAnalyzing = false);
      imageLabeler.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("AI Camera Scan"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Vùng hiển thị ảnh
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(20),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(20),
                border: _foundWater ? Border.all(color: Colors.green, width: 3) : null,
              ),
              child: _image == null
                  ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.camera_alt, size: 60, color: Colors.grey),
                  SizedBox(height: 10),
                  Text("Bấm nút chụp bên dưới", style: TextStyle(color: Colors.grey)),
                ],
              )
                  : ClipRRect(
                borderRadius: BorderRadius.circular(17),
                child: Image.file(_image!, fit: BoxFit.contain),
              ),
            ),
          ),

          // Vùng điều khiển
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isAnalyzing) const LinearProgressIndicator(),
                const SizedBox(height: 10),
                Text(
                  _resultText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _foundWater ? Colors.green[700] : Colors.black87
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    // Nút Chụp lại
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.camera),
                        label: const Text("CHỤP ẢNH"),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    // Nút Thêm nước (Chỉ hiện khi AI tìm thấy)
                    if (_foundWater) ...[
                      const SizedBox(width: 15),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            widget.onAddWater(250); // Cộng 250ml
                            Navigator.pop(context); // Đóng màn hình
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("🤖 AI đã tự động thêm 250ml!")),
                            );
                          },
                          icon: const Icon(Icons.check),
                          label: const Text("THÊM 250ML"),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ]
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}