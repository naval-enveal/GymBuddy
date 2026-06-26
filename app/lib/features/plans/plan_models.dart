/// Immutable view models for the workout-plan template library (M4).
///
/// These mirror the backend wire shape returned by `GET /plans/templates` — a
/// populated template `Plan` JSON annotated with a `matchScore` — decoded into
/// types the UI can render directly. Parsing is defensive: missing or
/// wrong-typed fields fall back to sensible defaults rather than throwing, so a
/// minor server-shape change degrades gracefully instead of crashing the list.
library;

/// One prescribed exercise within a training day.
///
/// [formTracked] reflects the server's per-exercise flag (the glasses are
/// first-person POV, so form correction ships only for mirror/POV-visible
/// movements) — the UI marks each exercise form-tracked vs rep-tracked-only.
class PlanExercise {
  const PlanExercise({
    required this.name,
    required this.formTracked,
    this.sets,
    this.reps,
    this.restSeconds,
    this.notes,
  });

  factory PlanExercise.fromJson(Map<String, dynamic> json) {
    return PlanExercise(
      name: json['name'] as String? ?? '',
      formTracked: json['formTracked'] == true,
      sets: (json['sets'] as num?)?.toInt(),
      reps: (json['reps'] as num?)?.toInt(),
      restSeconds: (json['restSeconds'] as num?)?.toInt(),
      notes: json['notes'] as String?,
    );
  }

  final String name;
  final bool formTracked;
  final int? sets;

  /// Target reps per set. Null means time-based or "to failure".
  final int? reps;
  final int? restSeconds;
  final String? notes;

  /// A compact "3 × 12" style prescription, or "3 sets" when reps are unset.
  String get prescription {
    if (sets == null) return '';
    if (reps == null) return '$sets ${sets == 1 ? 'set' : 'sets'}';
    return '$sets × $reps';
  }
}

/// One training day: an ordered list of [exercises].
class PlanWorkout {
  const PlanWorkout({
    required this.name,
    required this.exercises,
    this.description,
    this.estimatedMinutes,
  });

  factory PlanWorkout.fromJson(Map<String, dynamic> json) {
    final rawExercises = json['exercises'];
    return PlanWorkout(
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      estimatedMinutes: (json['estimatedMinutes'] as num?)?.toInt(),
      exercises: rawExercises is List
          ? <PlanExercise>[
              for (final e in rawExercises)
                if (e is Map<String, dynamic>) PlanExercise.fromJson(e),
            ]
          : const <PlanExercise>[],
    );
  }

  final String name;
  final String? description;
  final int? estimatedMinutes;
  final List<PlanExercise> exercises;
}

/// A ranked template plan from the library. [matchScore] is the server's
/// profile-match ranking (higher is a better fit; 0 when the user hasn't
/// onboarded yet); the list arrives best-match-first.
class PlanTemplate {
  const PlanTemplate({
    required this.id,
    required this.name,
    required this.equipment,
    required this.workouts,
    required this.matchScore,
    this.description,
    this.goal,
    this.experience,
    this.daysPerWeek,
    this.sourceTemplate,
  });

  factory PlanTemplate.fromJson(Map<String, dynamic> json) {
    final rawEquipment = json['equipment'];
    final rawWorkouts = json['workouts'];
    return PlanTemplate(
      id: json['_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      goal: json['goal'] as String?,
      experience: json['experience'] as String?,
      daysPerWeek: (json['daysPerWeek'] as num?)?.toInt(),
      matchScore: (json['matchScore'] as num?)?.toInt() ?? 0,
      sourceTemplate: json['sourceTemplate'] as String?,
      equipment: rawEquipment is List
          ? <String>[
              for (final e in rawEquipment)
                if (e is String) e,
            ]
          : const <String>[],
      workouts: rawWorkouts is List
          ? <PlanWorkout>[
              for (final w in rawWorkouts)
                if (w is Map<String, dynamic>) PlanWorkout.fromJson(w),
            ]
          : const <PlanWorkout>[],
    );
  }

  final String id;
  final String name;
  final String? description;

  /// Wire enum values (mirroring the server) — humanized for display via the
  /// label getters below.
  final String? goal;
  final String? experience;
  final int? daysPerWeek;
  final int matchScore;
  final List<String> equipment;
  final List<PlanWorkout> workouts;

  /// For a plan adopted from the library, the id of the template it was copied
  /// from; null on the templates themselves. Lets the UI tell which template is
  /// currently the user's active plan (the active plan is an owned copy with a
  /// different [id], so it's matched back to its template by this field).
  final String? sourceTemplate;

  String? get goalLabel => _humanizeWire(goal);
  String? get experienceLabel => _humanizeWire(experience);
  List<String> get equipmentLabels =>
      [for (final e in equipment) _humanizeWire(e) ?? e];
}

/// Turns a snake_case wire enum value (e.g. `lose_weight`, `full_gym`) into a
/// display label (`Lose weight`, `Full gym`). Returns null for a null input so
/// callers can omit absent fields.
String? _humanizeWire(String? wire) {
  if (wire == null || wire.isEmpty) return wire;
  final spaced = wire.replaceAll('_', ' ');
  return spaced[0].toUpperCase() + spaced.substring(1);
}
