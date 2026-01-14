import 'package:flutter/material.dart';
import 'package:heart_bpm/heart_bpm.dart';

class HeartRateScreen extends StatefulWidget {
  const HeartRateScreen({super.key});

  @override
  State<HeartRateScreen> createState() => _HeartRateScreenState();
}

class _HeartRateScreenState extends State<HeartRateScreen> {
  List<SensorValue> data = [];
  int _bpmValue = 0;
  bool _isMeasuring = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đo nhịp tim'),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey.shade100,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Khu vực hiển thị số đo
          if (_bpmValue > 0)
            Column(
              children: [
                const Icon(Icons.favorite, color: Colors.red, size: 80),
                Text(
                  "$_bpmValue BPM",
                  style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.red),
                ),
                const SizedBox(height: 10),
              ],
            )
          else
            const Icon(Icons.favorite_border, color: Colors.grey, size: 80),

          const SizedBox(height: 30),

          // Widget đo nhịp tim (Từ thư viện)
          _isMeasuring
              ? SizedBox(
            height: 200,
            width: 300, // Giới hạn khung hình
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: HeartBPMDialog(
                context: context,
                showTextValues: true,
                borderRadius: 20,
                onRawData: (value) {
                  setState(() {
                    if (data.length >= 100) data.removeAt(0);
                    data.add(value);
                  });
                },
                onBPM: (bpm) => setState(() {
                  if (bpm > 30 && bpm < 150) { // Lọc nhiễu
                    _bpmValue = bpm;
                  }
                }),
              ),
            ),
          )
              : Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Text(
              "Hãy đặt nhẹ ngón tay trỏ \nphủ kín Camera và Đèn Flash",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ),

          const SizedBox(height: 40),

          // Nút điều khiển
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_isMeasuring)
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isMeasuring = true;
                      _bpmValue = 0;
                    });
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text("BẮT ĐẦU ĐO"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  ),
                ),

              if (_isMeasuring && _bpmValue > 0)
                ElevatedButton.icon(
                  onPressed: () {
                    // Trả kết quả về màn hình chính
                    Navigator.pop(context, _bpmValue);
                  },
                  icon: const Icon(Icons.check),
                  label: const Text("LƯU KẾT QUẢ"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}