import 'package:flutter/material.dart';
import 'package:pedometer/pedometer.dart';

class StepCounterScreen extends StatefulWidget {
  @override
  _StepCounterScreenState createState() => _StepCounterScreenState();
}

class _StepCounterScreenState extends State<StepCounterScreen> {
  late Stream<StepCount> _stepCountStream;
  int _steps = 0;

  @override
  void initState() {
    super.initState();
    startListening();
  }

  void startListening() {
    _stepCountStream = Pedometer.stepCountStream;
    _stepCountStream.listen(
      onStepCount,
      onError: onStepCountError,
      cancelOnError: true,
    );
  }

  void onStepCount(StepCount event) {
    setState(() {
      _steps = event.steps; // Số bước hiện tại
    });
  }

  void onStepCountError(error) {
    print('Step Count Error: $error');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Đếm bước chân"),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Số bước đã đi:',
              style: TextStyle(fontSize: 24),
            ),
            SizedBox(height: 10),
            Text(
              '$_steps',
              style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
