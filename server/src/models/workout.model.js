'use strict';

const mongoose = require('mongoose');

/**
 * A prescribed exercise within a workout. `formTracked` reflects the PLAN
 * constraint that the glasses are first-person POV: form correction ships only
 * for mirror-facing / POV-visible movements, so each exercise is explicitly
 * marked form-tracked vs rep-tracked-only rather than assumed.
 */
const exerciseSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true },
    sets: { type: Number, min: 1, max: 20, default: 3 },
    // Target reps per set. A null/absent value means "to failure" or time-based.
    reps: { type: Number, min: 1, max: 100 },
    restSeconds: { type: Number, min: 0, max: 1200, default: 60 },
    targetWeightKg: { type: Number, min: 0 },
    formTracked: { type: Boolean, default: false },
    notes: { type: String, trim: true, maxlength: 300 },
  },
  { _id: true }
);

/**
 * A single workout (one training day): an ordered list of exercises. Workouts
 * are composed into Plans. The same workout document can be referenced by
 * multiple plans (e.g. a shared "Push Day").
 */
const workoutSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true },
    description: { type: String, trim: true, maxlength: 500 },
    exercises: { type: [exerciseSchema], default: [] },
    estimatedMinutes: { type: Number, min: 1, max: 360 },
    // Owner is null for seeded template workouts (M4), set for user-authored ones.
    owner: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null,
      index: true,
    },
  },
  { timestamps: true }
);

module.exports =
  mongoose.models.Workout || mongoose.model('Workout', workoutSchema);
