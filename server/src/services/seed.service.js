'use strict';

const { Plan, Workout } = require('../models');
const TEMPLATES = require('../seeds/templates');

/**
 * Seed the free/general workout-plan template library (M4) from
 * `seeds/templates.js`.
 *
 * Idempotent: it first removes every existing template Plan (`isTemplate`) and
 * template Workout (`owner: null`), then recreates them from the current
 * definitions. So a re-run always lands the DB in exactly the state described
 * by the data file — no duplicates, no stale exercises — regardless of what was
 * there before. User-authored workouts (which carry a real `owner`) and adopted
 * user plans (`isTemplate: false`) are never touched.
 *
 * @returns {Promise<{ plansCreated: number, workoutsCreated: number }>}
 */
async function seedTemplates() {
  await Plan.deleteMany({ isTemplate: true });
  await Workout.deleteMany({ owner: null });

  let plansCreated = 0;
  let workoutsCreated = 0;

  for (const tpl of TEMPLATES) {
    const workoutDocs = await Workout.create(
      tpl.workouts.map((w) => ({ ...w, owner: null }))
    );
    workoutsCreated += workoutDocs.length;

    await Plan.create({
      name: tpl.name,
      description: tpl.description,
      goal: tpl.goal,
      experience: tpl.experience,
      daysPerWeek: tpl.daysPerWeek,
      equipment: tpl.equipment,
      workouts: workoutDocs.map((doc) => doc._id),
      isTemplate: true,
      owner: null,
    });
    plansCreated += 1;
  }

  return { plansCreated, workoutsCreated };
}

module.exports = { seedTemplates };
