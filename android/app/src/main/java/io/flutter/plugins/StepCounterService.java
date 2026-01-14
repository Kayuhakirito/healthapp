package io.flutter.plugins;

import android.app.Notification;
import android.app.Service;
import android.content.Intent;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.os.IBinder;
import android.util.Log;

public class StepCounterService extends Service implements SensorEventListener {

    private static final String TAG = "StepCounterService";
    private SensorManager sensorManager;
    private Sensor stepCounterSensor;
    private int stepCount = 0;

    @Override
    public void onCreate() {
        super.onCreate();
        Log.d(TAG, "Service created");

        // Khởi tạo SensorManager và cảm biến bước chân
        sensorManager = (SensorManager) getSystemService(SENSOR_SERVICE);
        if (sensorManager != null) {
            stepCounterSensor = sensorManager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER);
            if (stepCounterSensor != null) {
                sensorManager.registerListener(this, stepCounterSensor, SensorManager.SENSOR_DELAY_NORMAL);
                Log.d(TAG, "Step Counter Sensor registered");
            } else {
                Log.e(TAG, "Step Counter Sensor not available");
            }
        } else {
            Log.e(TAG, "Sensor Manager not available");
        }
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        // Logic của Foreground Service
        Notification notification = null;
        startForeground(1, null); // Bắt buộc
        return START_STICKY;
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        if (sensorManager != null) {
            sensorManager.unregisterListener(this);
        }
        Log.d(TAG, "Service destroyed");
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    @Override
    public void onSensorChanged(SensorEvent event) {
        if (event.sensor.getType() == Sensor.TYPE_STEP_COUNTER) {
            stepCount = (int) event.values[0]; // Lấy số bước từ cảm biến
            Log.d(TAG, "Steps: " + stepCount);

            // Gửi dữ liệu bước chân về UI hoặc lưu trữ
            Intent stepIntent = new Intent("com.example.health_app.STEP_COUNT_UPDATE");
            stepIntent.putExtra("step_count", stepCount);
            sendBroadcast(stepIntent);
        }
    }

    @Override
    public void onAccuracyChanged(Sensor sensor, int accuracy) {
        // Xử lý nếu cần (không bắt buộc)
    }
}
