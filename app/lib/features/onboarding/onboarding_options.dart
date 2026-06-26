/// Onboarding answer vocabularies, mirrored from the server's shared enums
/// (`server/src/models/constants.js`) so the client and the Profile API speak
/// the same language. Each option pairs the [wire] value persisted to the
/// backend with a human [label] shown in the flow.
library;

/// Primary training goals (multi-select). Mirrors server `GOALS`.
enum FitnessGoal {
  loseWeight('lose_weight', 'Lose weight'),
  buildMuscle('build_muscle', 'Build muscle'),
  gainStrength('gain_strength', 'Gain strength'),
  improveEndurance('improve_endurance', 'Improve endurance'),
  generalFitness('general_fitness', 'General fitness');

  const FitnessGoal(this.wire, this.label);

  /// The value persisted to the Profile API.
  final String wire;

  /// The label shown in the onboarding flow.
  final String label;
}

/// Self-reported training experience (single-select). Mirrors server
/// `EXPERIENCE_LEVELS`.
enum ExperienceLevel {
  beginner('beginner', 'Beginner', 'New to training or returning after a break'),
  intermediate(
    'intermediate',
    'Intermediate',
    'Train consistently and know the basics',
  ),
  advanced('advanced', 'Advanced', 'Years of structured training');

  const ExperienceLevel(this.wire, this.label, this.description);

  final String wire;
  final String label;

  /// A short clarifying line shown under the [label].
  final String description;
}

/// Equipment the user can train with (multi-select). Mirrors server
/// `EQUIPMENT`.
enum Equipment {
  none('none', 'None'),
  bodyweight('bodyweight', 'Bodyweight'),
  dumbbells('dumbbells', 'Dumbbells'),
  barbell('barbell', 'Barbell'),
  kettlebell('kettlebell', 'Kettlebell'),
  resistanceBands('resistance_bands', 'Resistance bands'),
  machines('machines', 'Machines'),
  fullGym('full_gym', 'Full gym');

  const Equipment(this.wire, this.label);

  final String wire;
  final String label;
}

/// Biological sex, used to tune plans and vitals targets (single-select,
/// optional). Mirrors server `SEXES`.
enum BiologicalSex {
  male('male', 'Male'),
  female('female', 'Female'),
  other('other', 'Other'),
  preferNotToSay('prefer_not_to_say', 'Prefer not to say');

  const BiologicalSex(this.wire, this.label);

  final String wire;
  final String label;
}
