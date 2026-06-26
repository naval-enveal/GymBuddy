'use strict';

const mongoose = require('mongoose');
const { GOALS, EXPERIENCE_LEVELS, EQUIPMENT } = require('./constants');

/**
 * A workout plan: an ordered set of Workouts plus the profile attributes used
 * to match it to a user (M4). Seeded templates have `isTemplate: true` and a
 * null `owner`; a plan a user adopts/customizes is owned and not a template.
 */
const planSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true },
    description: { type: String, trim: true, maxlength: 1000 },
    goal: { type: String, enum: GOALS },
    experience: { type: String, enum: EXPERIENCE_LEVELS },
    daysPerWeek: { type: Number, min: 1, max: 7 },
    // Equipment a trainee needs to run this plan, used to match templates to a
    // profile's available equipment (M4). Empty means no special equipment.
    equipment: { type: [{ type: String, enum: EQUIPMENT }], default: [] },
    // Ordered list of training days for the week.
    workouts: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Workout',
      },
    ],
    isTemplate: { type: Boolean, default: false, index: true },
    owner: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null,
      index: true,
    },
    // For a plan adopted from the library, the template it was copied from.
    // Lets the app mark which template is currently active. Null for templates
    // themselves and any ad-hoc plan.
    sourceTemplate: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Plan',
      default: null,
    },
    // True for the single plan the owner is currently training against. One
    // active plan per user is enforced in the service, never trusted from the
    // client.
    isActive: { type: Boolean, default: false },
  },
  { timestamps: true }
);

module.exports = mongoose.models.Plan || mongoose.model('Plan', planSchema);
