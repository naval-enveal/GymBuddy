'use strict';

const { Plan, Profile, Workout, constants } = require('../models');
const { ApiError } = require('../middleware/error.middleware');

const { EXPERIENCE_LEVELS } = constants;

/**
 * Plan matching (M4). Ranks the seeded template library against a user's
 * onboarding Profile so the app can surface the most relevant free plans first.
 *
 * Pure ranking logic lives here (testable, no request plumbing); the controller
 * just hands it a userId.
 */

/**
 * Expand a profile's declared equipment into everything the trainee can
 * effectively use. Bodyweight movements need no kit, so `bodyweight`/`none` are
 * always available, and a `full_gym` answer is a superset of every individual
 * piece. This keeps a fully-equipped user from being penalized against a plan
 * that only lists `barbell`, and keeps bodyweight plans runnable for everyone.
 *
 * @param {string[]} equipment
 * @returns {Set<string>}
 */
function expandEquipment(equipment) {
  const available = new Set(equipment || []);
  available.add('bodyweight');
  available.add('none');
  if (available.has('full_gym')) {
    for (const item of constants.EQUIPMENT) available.add(item);
  }
  return available;
}

/**
 * Score one template Plan against a Profile. Higher is a better match.
 *
 * Weighting reflects priority: the training goal dominates, equipment
 * feasibility (can they actually run it?) is next, then experience fit and how
 * close the plan's days/week is to the user's availability act as tie-breakers.
 * All signals are optional — a sparse profile simply contributes fewer points,
 * so every template still gets a deterministic, comparable score.
 *
 * @param {object} plan  a template Plan document
 * @param {object} profile  the caller's Profile (may be sparse)
 * @returns {number}
 */
function scoreTemplate(plan, profile) {
  let score = 0;

  // Goal — the strongest signal. The profile can list several goals; a plan
  // serving any of them is a hit.
  if (Array.isArray(profile.goals) && profile.goals.includes(plan.goal)) {
    score += 100;
  }

  // Equipment feasibility. A plan the trainee can fully run is rewarded; each
  // piece of kit they lack makes it less practical.
  const available = expandEquipment(profile.equipment);
  const required = plan.equipment || [];
  const missing = required.filter((item) => !available.has(item));
  if (missing.length === 0) {
    score += 40;
  } else {
    score -= missing.length * 15;
  }

  // Experience — exact match best, one level off still reasonable.
  const userExp = EXPERIENCE_LEVELS.indexOf(profile.experience);
  const planExp = EXPERIENCE_LEVELS.indexOf(plan.experience);
  if (userExp >= 0 && planExp >= 0) {
    score += Math.max(0, 20 - Math.abs(userExp - planExp) * 10);
  }

  // Days per week — closeness to the user's availability.
  if (
    typeof profile.daysPerWeek === 'number'
    && typeof plan.daysPerWeek === 'number'
  ) {
    score += Math.max(0, 15 - Math.abs(profile.daysPerWeek - plan.daysPerWeek) * 5);
  }

  return score;
}

/**
 * Return the template library ranked for the given user.
 *
 * Reads the caller's Profile and the seeded template Plans (with their training
 * days populated), scores each template against the profile, and returns them
 * best-match-first. Ties break on name for a stable order. When the user has no
 * profile yet (hasn't onboarded), there's nothing to rank against, so the full
 * library is returned in name order with a zero score.
 *
 * @param {string} userId
 * @returns {Promise<Array<object>>} plan JSON each annotated with `matchScore`
 */
async function getMatchedTemplates(userId) {
  const [profile, templates] = await Promise.all([
    Profile.findOne({ user: userId }),
    Plan.find({ isTemplate: true }).populate('workouts'),
  ]);

  const scored = templates.map((plan) => ({
    plan,
    score: profile ? scoreTemplate(plan, profile) : 0,
  }));

  scored.sort((a, b) => {
    if (b.score !== a.score) return b.score - a.score;
    return a.plan.name.localeCompare(b.plan.name);
  });

  return scored.map(({ plan, score }) => ({ ...plan.toJSON(), matchScore: score }));
}

/**
 * Copy a template's exercises into a plain object array suitable for a new
 * owned Workout. Embedded `_id`s and timestamps are dropped so the copy gets
 * its own; only the prescription fields carry over.
 *
 * @param {Array<object>} exercises
 * @returns {Array<object>}
 */
function copyExercises(exercises) {
  return (exercises || []).map((e) => ({
    name: e.name,
    sets: e.sets,
    reps: e.reps,
    restSeconds: e.restSeconds,
    targetWeightKg: e.targetWeightKg,
    formTracked: e.formTracked,
    notes: e.notes,
  }));
}

/**
 * Adopt a library template as the caller's active plan.
 *
 * Writes an owned, non-template Plan (a deep copy of the template's attributes
 * and its training-day Workouts, so the user's plan is self-contained and a
 * library re-seed can't dangle its references) with `isActive: true`. Enforces
 * **one active plan per user**: any previously active owned plan is deactivated
 * in the same operation — this is never trusted from the client.
 *
 * @param {string} userId
 * @param {string} templateId  the template Plan to adopt
 * @returns {Promise<object>} the new active plan, workouts populated
 */
async function adoptTemplate(userId, templateId) {
  const template = await Plan.findOne({
    _id: templateId,
    isTemplate: true,
  }).populate('workouts');
  if (!template) {
    throw new ApiError(404, 'Template plan not found');
  }

  // Copy the template's training days into owned Workouts.
  const ownedWorkouts = await Workout.create(
    template.workouts.map((w) => ({
      name: w.name,
      description: w.description,
      exercises: copyExercises(w.exercises),
      estimatedMinutes: w.estimatedMinutes,
      owner: userId,
    }))
  );

  // Enforce one active plan per user: deactivate any prior active plan before
  // activating the new one.
  await Plan.updateMany(
    { owner: userId, isActive: true },
    { $set: { isActive: false } }
  );

  const plan = await Plan.create({
    name: template.name,
    description: template.description,
    goal: template.goal,
    experience: template.experience,
    daysPerWeek: template.daysPerWeek,
    equipment: template.equipment,
    workouts: ownedWorkouts.map((w) => w._id),
    isTemplate: false,
    owner: userId,
    sourceTemplate: template._id,
    isActive: true,
  });

  return plan.populate('workouts');
}

/**
 * Return the caller's currently active plan (workouts populated), or `null` if
 * they haven't adopted one yet.
 *
 * @param {string} userId
 * @returns {Promise<object|null>}
 */
async function getActivePlan(userId) {
  return Plan.findOne({ owner: userId, isActive: true }).populate('workouts');
}

module.exports = {
  getMatchedTemplates,
  scoreTemplate,
  expandEquipment,
  adoptTemplate,
  getActivePlan,
};
