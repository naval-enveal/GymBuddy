import 'dart:io' show Platform;

import 'package:health/health.dart';

/// The health metrics the GymBuddy vitals dashboard reads (M5): resting heart
/// rate, heart-rate variability, sleep, and steps — the inputs to the readiness
/// proxy surfaced on Home.
///
/// HealthKit and Health Connect expose HRV under different types — HealthKit
/// records SDNN, Health Connect records RMSSD — so the requested set is resolved
/// per platform. Keeping these in one place means the permission request and the
/// data reads (the M5 read layer) ask for exactly the same types.

/// Resting heart rate, in bpm.
const HealthDataType restingHeartRateType = HealthDataType.RESTING_HEART_RATE;

/// Heart-rate variability, in ms. HealthKit records SDNN; Health Connect records
/// RMSSD — resolved per platform so the request and the reads agree.
HealthDataType get hrvType => Platform.isAndroid
    ? HealthDataType.HEART_RATE_VARIABILITY_RMSSD
    : HealthDataType.HEART_RATE_VARIABILITY_SDNN;

/// Time asleep — segments summed into a night's total.
const HealthDataType sleepAsleepType = HealthDataType.SLEEP_ASLEEP;

/// Step count.
const HealthDataType stepsType = HealthDataType.STEPS;

/// The full set of [HealthDataType]s the dashboard requests and reads.
List<HealthDataType> vitalsHealthTypes() => <HealthDataType>[
      restingHeartRateType,
      hrvType,
      sleepAsleepType,
      stepsType,
    ];
