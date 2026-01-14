import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _historyData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {

    final historyBox = await Hive.openBox('history');

    List<Map<String, dynamic>> tempList = [];


    final keys = historyBox.keys.cast<String>().where((k) => k.startsWith('steps_')).toList();

    for (var key in keys) {
      try {

        String dateStr = key.replaceAll('steps_', '');



        List<String> parts = dateStr.split('-');
        if (parts.length == 3) {
          String y = parts[0];
          String m = parts[1].padLeft(2, '0');
          String d = parts[2].padLeft(2, '0');
          dateStr = "$y-$m-$d";
        }

        DateTime date = DateTime.parse(dateStr);

        // Lấy dữ liệu tương ứng
        int steps = historyBox.get('steps_${key.replaceAll('steps_', '')}', defaultValue: 0);
        int water = historyBox.get('water_${key.replaceAll('steps_', '')}', defaultValue: 0);

        if (steps > 0 || water > 0) {
          tempList.add({
            'date': date,
            'steps': steps,
            'water': water,
          });
        }
      } catch (e) {
        print("Lỗi đọc dữ liệu ngày $key: $e");
      }
    }

    // Sắp xếp ngày mới nhất lên đầu
    tempList.sort((a, b) => b['date'].compareTo(a['date']));

    if (mounted) {
      setState(() {
        _historyData = tempList;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Lịch sử hoạt động", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _historyData.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off, size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 10),
            const Text("Chưa có dữ liệu lịch sử", style: TextStyle(color: Colors.grey)),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _historyData.length,
        itemBuilder: (context, index) {
          final item = _historyData[index];
          final date = item['date'] as DateTime;

          return Card(
            color: Colors.white,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Cột Ngày
                  Row(
                    children: [
                      Container(
                        width: 50, height: 50,
                        decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12)
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(DateFormat('dd').format(date), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue)),
                            Text(DateFormat('MM').format(date), style: const TextStyle(fontSize: 12, color: Colors.blue)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 15),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getDayName(date), // Hàm lấy thứ
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(DateFormat('yyyy').format(date), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),

                  // Cột Số liệu
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(children: [
                        Icon(Icons.directions_walk, size: 16, color: Colors.purple.shade300),
                        const SizedBox(width: 4),
                        Text("${item['steps']} bước", style: const TextStyle(fontWeight: FontWeight.w600)),
                      ]),
                      const SizedBox(height: 5),
                      Row(children: [
                        Icon(Icons.local_drink, size: 16, color: Colors.blue.shade300),
                        const SizedBox(width: 4),
                        Text("${item['water']} ml", style: const TextStyle(fontWeight: FontWeight.w600)),
                      ]),
                    ],
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Hàm chuyển đổi thứ sang tiếng Việt
  String _getDayName(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return "Hôm nay";
    }
    switch (date.weekday) {
      case 1: return "Thứ Hai";
      case 2: return "Thứ Ba";
      case 3: return "Thứ Tư";
      case 4: return "Thứ Năm";
      case 5: return "Thứ Sáu";
      case 6: return "Thứ Bảy";
      case 7: return "Chủ Nhật";
      default: return "";
    }
  }
}