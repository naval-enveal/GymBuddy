'use strict';

const mongoose = require('mongoose');
const { GOALS, EXPERIENCE_LEVELS, EQUIPMENT, SEXES } = require('./constants');

/**
 * Onboarding answers and body stats for a user. One profile per user, captured
 * during the M3 onboarding flow and used to match workout plans (M4) and tune
 * AI plan generation (M9).
 */
const profileSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      unique: true,
      index: true,
    },
    goals: {
      type: [{ type: String, enum: GOALS }],
      default: [],
    },
    experience: {
      type: String,
      enum: EXPERIENCE_LEVELS,
    },
    daysPerWeek: {
      type: Number,
      min: 1,
      max: 7,
    },
    equipment: {
      type: [{ type: String, enum: EQUIPMENT }],
      default: [],
    },
    injuries: {
      type: [{ type: String, trim: true, maxlength: 120 }],
      default: [],
    },
    bodyStats: {
      heightCm: { type: Number, min: 50, max: 300 },
      weightKg: { type: Number, min: 20, max: 500 },
      age: { type: Number, min: 13, max: 120 },
      sex: { type: String, enum: SEXES },
    },
    onboardingComplete: {
      type: Boolean,
      default: false,
    },
  },
  { timestamps: true }
);

module.exports =
  mongoose.models.Profile || mongoose.model('Profile', profileSchema);
