import 'dart:io' show Platform;

import 'package:health/health.dart';

/// The health metrics the GymBuddy vitals dashboard reads (M5): resting heart
/// rate, heart-rate variability, sleep, and steps — the inputs to the readiness
/// proxy surfaced on Home.
///
/// HealthKit and Health Connect expose HRV under different types — HealthKit
/// records SDNN, Health Connect records RMSSD — so the requested set is resolved
/// per platform. Keeping this list in one place means the permission request
/// (this task) and the later data reads ask for exactly the same types.
List<HealthDataType> vitalsHealthTypes() => <HealthDataType>[
      HealthDataType.RESTING_HEART_RATE,
      Platform.isAndroid
          ? HealthDataType.HEART_RATE_VARIABILITY_RMSSD
          : HealthDataType.HEART_RATE_VARIABILITY_SDNN,
      HealthDataType.SLEEP_ASLEEP,
      HealthDataType.STEPS,
    ];
