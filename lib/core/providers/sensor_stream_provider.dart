import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Live accelerometer stream — used by Gyro Controller (Screen 5)
final sensorStreamProvider = StreamProvider<AccelerometerEvent>((ref) {
  return accelerometerEventStream(
    samplingPeriod: const Duration(milliseconds: 50),
  );
});
