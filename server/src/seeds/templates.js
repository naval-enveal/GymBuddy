'use strict';

/**
 * Seed data for the free/general workout-plan template library (M4).
 *
 * Pure data — no database access — so it can be imported by the seed service
 * and asserted against in tests without a live Mongo. Each entry becomes one
 * template Plan (`isTemplate: true`, `owner: null`) whose `workouts` are the
 * listed training days, created as template Workouts (`owner: null`).
 *
 * `goal` / `experience` / `daysPerWeek` / `equipment` are the attributes the
 * matching endpoint (next M4 task) uses to rank templates against a user's
 * Profile, so the set below deliberately spans all five goals and a range of
 * experience levels and equipment access.
 *
 * `formTracked` follows the PLAN constraint that the glasses are first-person
 * POV: it's true only for mirror-facing / POV-visible movements (squats,
 * lunges, hinges, curls), false for movements the glasses can't see well
 * (presses overhead, rows, planks). It is NOT a claim every device tracks
 * form — the UI marks each exercise accordingly.
 *
 * Enum values (goal/experience/equipment) mirror models/constants.js.
 */

const TEMPLATES = [
  {
    name: 'Full Body Foundations',
    description:
      'A gentle three-day full-body routine for newcomers, using only '
      + 'bodyweight. Builds the squat, hinge, and push patterns before any load.',
    goal: 'general_fitness',
    experience: 'beginner',
    daysPerWeek: 3,
    equipment: ['bodyweight'],
    workouts: [
      {
        name: 'Full Body A',
        description: 'Squat-focused full body.',
        estimatedMinutes: 30,
        exercises: [
          { name: 'Bodyweight Squat', sets: 3, reps: 12, restSeconds: 60, formTracked: true },
          { name: 'Incline Push-up', sets: 3, reps: 10, restSeconds: 60, formTracked: false },
          { name: 'Glute Bridge', sets: 3, reps: 15, restSeconds: 45, formTracked: true },
          { name: 'Front Plank', sets: 3, restSeconds: 45, formTracked: false, notes: 'Hold 20–40s.' },
        ],
      },
      {
        name: 'Full Body B',
        description: 'Hinge-focused full body.',
        estimatedMinutes: 30,
        exercises: [
          { name: 'Reverse Lunge', sets: 3, reps: 10, restSeconds: 60, formTracked: true },
          { name: 'Knee Push-up', sets: 3, reps: 10, restSeconds: 60, formTracked: false },
          { name: 'Hip Hinge', sets: 3, reps: 12, restSeconds: 60, formTracked: true },
          { name: 'Dead Bug', sets: 3, reps: 12, restSeconds: 45, formTracked: false },
        ],
      },
      {
        name: 'Full Body C',
        description: 'Mixed full body.',
        estimatedMinutes: 30,
        exercises: [
          { name: 'Split Squat', sets: 3, reps: 10, restSeconds: 60, formTracked: true },
          { name: 'Pike Push-up', sets: 3, reps: 8, restSeconds: 60, formTracked: false },
          { name: 'Superman', sets: 3, reps: 12, restSeconds: 45, formTracked: false },
          { name: 'Side Plank', sets: 2, restSeconds: 45, formTracked: false, notes: 'Hold 20–30s per side.' },
        ],
      },
    ],
  },
  {
    name: 'Dumbbell Strength Starter',
    description:
      'Three full-body days with a pair of dumbbells to build foundational '
      + 'strength on the main movement patterns.',
    goal: 'gain_strength',
    experience: 'beginner',
    daysPerWeek: 3,
    equipment: ['dumbbells'],
    workouts: [
      {
        name: 'Strength A',
        estimatedMinutes: 40,
        exercises: [
          { name: 'Goblet Squat', sets: 3, reps: 8, restSeconds: 90, formTracked: true },
          { name: 'Dumbbell Bench Press', sets: 3, reps: 8, restSeconds: 90, formTracked: false },
          { name: 'One-Arm Dumbbell Row', sets: 3, reps: 10, restSeconds: 75, formTracked: false },
          { name: 'Dumbbell Romanian Deadlift', sets: 3, reps: 10, restSeconds: 90, formTracked: true },
        ],
      },
      {
        name: 'Strength B',
        estimatedMinutes: 40,
        exercises: [
          { name: 'Dumbbell Reverse Lunge', sets: 3, reps: 8, restSeconds: 90, formTracked: true },
          { name: 'Dumbbell Overhead Press', sets: 3, reps: 8, restSeconds: 90, formTracked: false },
          { name: 'Dumbbell Floor Press', sets: 3, reps: 10, restSeconds: 75, formTracked: false },
          { name: 'Dumbbell Bicep Curl', sets: 3, reps: 12, restSeconds: 60, formTracked: true },
        ],
      },
    ],
  },
  {
    name: 'Push Pull Legs Hypertrophy',
    description:
      'A six-day full-gym split for adding muscle, training each pattern '
      + 'twice a week across push, pull, and leg days.',
    goal: 'build_muscle',
    experience: 'intermediate',
    daysPerWeek: 6,
    equipment: ['full_gym'],
    workouts: [
      {
        name: 'Push',
        estimatedMinutes: 55,
        exercises: [
          { name: 'Barbell Bench Press', sets: 4, reps: 8, restSeconds: 120, formTracked: false },
          { name: 'Overhead Press', sets: 3, reps: 10, restSeconds: 90, formTracked: false },
          { name: 'Incline Dumbbell Press', sets: 3, reps: 10, restSeconds: 90, formTracked: false },
          { name: 'Cable Triceps Pushdown', sets: 3, reps: 12, restSeconds: 60, formTracked: false },
        ],
      },
      {
        name: 'Pull',
        estimatedMinutes: 55,
        exercises: [
          { name: 'Deadlift', sets: 4, reps: 5, restSeconds: 150, formTracked: true },
          { name: 'Pull-up', sets: 3, reps: 8, restSeconds: 90, formTracked: false },
          { name: 'Barbell Row', sets: 3, reps: 10, restSeconds: 90, formTracked: false },
          { name: 'Dumbbell Bicep Curl', sets: 3, reps: 12, restSeconds: 60, formTracked: true },
        ],
      },
      {
        name: 'Legs',
        estimatedMinutes: 55,
        exercises: [
          { name: 'Back Squat', sets: 4, reps: 8, restSeconds: 150, formTracked: true },
          { name: 'Romanian Deadlift', sets: 3, reps: 10, restSeconds: 120, formTracked: true },
          { name: 'Walking Lunge', sets: 3, reps: 12, restSeconds: 90, formTracked: true },
          { name: 'Standing Calf Raise', sets: 4, reps: 15, restSeconds: 45, formTracked: false },
        ],
      },
    ],
  },
  {
    name: 'Upper Lower Power',
    description:
      'A four-day barbell-and-dumbbell upper/lower split for intermediate '
      + 'lifters chasing strength on the big lifts.',
    goal: 'gain_strength',
    experience: 'intermediate',
    daysPerWeek: 4,
    equipment: ['barbell', 'dumbbells'],
    workouts: [
      {
        name: 'Upper Power',
        estimatedMinutes: 50,
        exercises: [
          { name: 'Barbell Bench Press', sets: 4, reps: 5, restSeconds: 150, formTracked: false },
          { name: 'Barbell Row', sets: 4, reps: 6, restSeconds: 120, formTracked: false },
          { name: 'Overhead Press', sets: 3, reps: 6, restSeconds: 120, formTracked: false },
        ],
      },
      {
        name: 'Lower Power',
        estimatedMinutes: 50,
        exercises: [
          { name: 'Back Squat', sets: 4, reps: 5, restSeconds: 180, formTracked: true },
          { name: 'Deadlift', sets: 3, reps: 5, restSeconds: 180, formTracked: true },
          { name: 'Dumbbell Walking Lunge', sets: 3, reps: 10, restSeconds: 90, formTracked: true },
        ],
      },
      {
        name: 'Upper Hypertrophy',
        estimatedMinutes: 50,
        exercises: [
          { name: 'Incline Dumbbell Press', sets: 3, reps: 10, restSeconds: 90, formTracked: false },
          { name: 'One-Arm Dumbbell Row', sets: 3, reps: 12, restSeconds: 75, formTracked: false },
          { name: 'Dumbbell Bicep Curl', sets: 3, reps: 12, restSeconds: 60, formTracked: true },
        ],
      },
      {
        name: 'Lower Hypertrophy',
        estimatedMinutes: 50,
        exercises: [
          { name: 'Front Squat', sets: 3, reps: 8, restSeconds: 120, formTracked: true },
          { name: 'Romanian Deadlift', sets: 3, reps: 10, restSeconds: 120, formTracked: true },
          { name: 'Bulgarian Split Squat', sets: 3, reps: 10, restSeconds: 90, formTracked: true },
        ],
      },
    ],
  },
  {
    name: 'Lean Burn Circuit',
    description:
      'Four short, high-density circuit days mixing dumbbells and bodyweight '
      + 'to keep the heart rate up and support fat loss.',
    goal: 'lose_weight',
    experience: 'beginner',
    daysPerWeek: 4,
    equipment: ['dumbbells', 'bodyweight'],
    workouts: [
      {
        name: 'Circuit A',
        estimatedMinutes: 30,
        exercises: [
          { name: 'Goblet Squat', sets: 3, reps: 15, restSeconds: 45, formTracked: true },
          { name: 'Push-up', sets: 3, reps: 12, restSeconds: 45, formTracked: false },
          { name: 'Dumbbell Romanian Deadlift', sets: 3, reps: 12, restSeconds: 45, formTracked: true },
          { name: 'Mountain Climbers', sets: 3, restSeconds: 30, formTracked: false, notes: '30s on.' },
        ],
      },
      {
        name: 'Circuit B',
        estimatedMinutes: 30,
        exercises: [
          { name: 'Reverse Lunge', sets: 3, reps: 12, restSeconds: 45, formTracked: true },
          { name: 'Dumbbell Overhead Press', sets: 3, reps: 12, restSeconds: 45, formTracked: false },
          { name: 'Dumbbell Row', sets: 3, reps: 12, restSeconds: 45, formTracked: false },
          { name: 'Jumping Jacks', sets: 3, restSeconds: 30, formTracked: false, notes: '40s on.' },
        ],
      },
    ],
  },
  {
    name: 'Bodyweight Conditioning',
    description:
      'Three equipment-free days focused on work capacity and stamina with '
      + 'higher-rep, short-rest bodyweight movements.',
    goal: 'improve_endurance',
    experience: 'intermediate',
    daysPerWeek: 3,
    equipment: ['bodyweight'],
    workouts: [
      {
        name: 'Conditioning A',
        estimatedMinutes: 35,
        exercises: [
          { name: 'Air Squat', sets: 4, reps: 20, restSeconds: 45, formTracked: true },
          { name: 'Push-up', sets: 4, reps: 15, restSeconds: 45, formTracked: false },
          { name: 'Walking Lunge', sets: 3, reps: 20, restSeconds: 45, formTracked: true },
          { name: 'Burpee', sets: 4, reps: 10, restSeconds: 60, formTracked: false },
        ],
      },
      {
        name: 'Conditioning B',
        estimatedMinutes: 35,
        exercises: [
          { name: 'Jump Squat', sets: 4, reps: 12, restSeconds: 60, formTracked: true },
          { name: 'Pike Push-up', sets: 3, reps: 12, restSeconds: 45, formTracked: false },
          { name: 'Glute Bridge March', sets: 3, reps: 16, restSeconds: 45, formTracked: true },
          { name: 'High Knees', sets: 4, restSeconds: 45, formTracked: false, notes: '40s on.' },
        ],
      },
    ],
  },
];

module.exports = TEMPLATES;
