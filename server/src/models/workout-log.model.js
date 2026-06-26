'use strict';

const mongoose = require('mongoose');

/**
 * One performed set within a logged exercise — what the user actually did, as
 * opposed to what the plan prescribed.
 */
const loggedSetSchema = new mongoose.Schema(
  {
    reps: { type: Number, min: 0, max: 1000 },
    weightKg: { type: Number, min: 0 },
    completed: { type: Boolean, default: true },
  },
  { _id: false }
);

const loggedExerciseSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true },
    sets: { type: [loggedSetSchema], default: [] },
  },
  { _id: false }
);

/**
 * A completed (or in-progress) workout session. Captures what the user actually
 * performed so progress can be tracked over time and fed back into AI plan
 * generation (M9). Synced from the session engine on workout completion (M6).
 */
const workoutLogSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    // Optional links back to what was being followed, if anything.
    plan: { type: mongoose.Schema.Types.ObjectId, ref: 'Plan', default: null },
    workout: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Workout',
      default: null,
    },
    startedAt: { type: Date, required: true },
    completedAt: { type: Date },
    durationSeconds: { type: Number, min: 0 },
    exercises: { type: [loggedExerciseSchema], default: [] },
    notes: { type: String, trim: true, maxlength: 1000 },
  },
  { timestamps: true }
);

// Most queries fetch a user's recent sessions, newest first.
workoutLogSchema.index({ user: 1, startedAt: -1 });

module.exports =
  mongoose.models.WorkoutLog ||
  mongoose.model('WorkoutLog', workoutLogSchema);
