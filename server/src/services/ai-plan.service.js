'use strict';

const { Plan, Workout, Profile, WorkoutLog, constants } = require('../models');
const { ApiError } = require('../middleware/error.middleware');
const { getClient } = require('./ai.client');
const config = require('../config/env');

const { GOALS, EXPERIENCE_LEVELS, EQUIPMENT } = constants;

// How many recent sessions to feed the model as training history.
const RECENT_LOG_LIMIT = 10;
// Output cap for the generated plan. Plans are small, well under this.
const MAX_TOKENS = 8000;

/**
 * AI plan generation (M9). Gathers the caller's onboarding Profile, recent
 * WorkoutLog history, and a client-supplied vitals snapshot (vitals live
 * on-device in HealthKit/Health Connect — the server never stores them, so
 * they arrive in the request), asks Gemini for a structured plan, sanitizes the
 * model output against our schema, and persists it as the caller's active Plan.
 *
 * The AI call goes through `ai.client` (the single key-holding seam), so this
 * whole service is unit-testable by injecting a fake client.
 *
 * NOTE: premium gating for this endpoint is a separate M9 task (enforced
 * server-side from the Subscription record) — not wired here yet.
 */

// JSON schema the model must fill. Deliberately limited to types + enums +
// `required` + `additionalProperties:false` (the constraints structured outputs
// supports); real bounds are enforced by `sanitizeGeneratedPlan` below, which
// also defends against any malformed output.
const PLAN_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  properties: {
    name: { type: 'string' },
    description: { type: 'string' },
    goal: { type: 'string', enum: GOALS },
    experience: { type: 'string', enum: EXPERIENCE_LEVELS },
    daysPerWeek: { type: 'integer' },
    equipment: { type: 'array', items: { type: 'string', enum: EQUIPMENT } },
    workouts: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        properties: {
          name: { type: 'string' },
          description: { type: 'string' },
          estimatedMinutes: { type: 'integer' },
          exercises: {
            type: 'array',
            items: {
              type: 'object',
              additionalProperties: false,
              properties: {
                name: { type: 'string' },
                sets: { type: 'integer' },
                reps: { type: ['integer', 'null'] },
                restSeconds: { type: 'integer' },
                targetWeightKg: { type: ['number', 'null'] },
                formTracked: { type: 'boolean' },
                notes: { type: 'string' },
              },
              required: ['name', 'sets'],
            },
          },
        },
        required: ['name', 'exercises'],
      },
    },
  },
  required: ['name', 'goal', 'workouts'],
};

const SYSTEM_PROMPT = [
  'You are a certified strength and conditioning coach generating a personalized',
  'weekly workout plan. Use the trainee context (onboarding profile, recent',
  'training history, and today\'s recovery vitals) to choose appropriate exercises,',
  'volume, and intensity. Respect the trainee\'s available equipment and avoid',
  'movements that aggravate listed injuries. If recovery vitals look poor (low HRV,',
  'high resting heart rate, little sleep, low readiness), reduce volume/intensity',
  'for the week. Produce exactly the requested number of training days when',
  'possible. Mark an exercise formTracked:true only for compound, POV-visible',
  'movements where joint-angle form coaching is feasible.',
].join(' ');

/** Compact a Profile document into the context object handed to the model. */
function profileContext(profile) {
  return {
    goals: profile.goals || [],
    experience: profile.experience || null,
    daysPerWeek: profile.daysPerWeek || null,
    equipment: profile.equipment || [],
    injuries: profile.injuries || [],
    bodyStats: profile.bodyStats
      ? {
          heightCm: profile.bodyStats.heightCm,
          weightKg: profile.bodyStats.weightKg,
          age: profile.bodyStats.age,
          sex: profile.bodyStats.sex,
        }
      : {},
  };
}

/** Summarize recent WorkoutLogs into a compact history for the prompt. */
function historyContext(logs) {
  return logs.map((log) => ({
    date: log.startedAt ? log.startedAt.toISOString().slice(0, 10) : null,
    durationSeconds: log.durationSeconds,
    exercises: (log.exercises || []).map((e) => ({
      name: e.name,
      sets: (e.sets || []).map((s) => ({
        reps: s.reps,
        weightKg: s.weightKg,
        completed: s.completed,
      })),
    })),
  }));
}

/**
 * Build the user message for the model. Vitals are passed through as-is (the
 * caller's validated snapshot) — `null`/absent means "not available", which the
 * system prompt tells the model how to treat.
 */
function buildUserMessage({ profile, history, vitals }) {
  const context = {
    profile: profileContext(profile),
    recentHistory: history,
    vitals: vitals || null,
  };
  return [
    'Generate a weekly workout plan for this trainee. Return ONLY the plan as',
    'JSON matching the provided schema — no prose.',
    '',
    'TRAINEE CONTEXT:',
    JSON.stringify(context, null, 2),
  ].join('\n');
}

// ---- output sanitation -----------------------------------------------------

function clampInt(value, min, max, fallback) {
  const n = Math.round(Number(value));
  if (!Number.isFinite(n)) return fallback;
  return Math.min(max, Math.max(min, n));
}

function oneOf(value, allowed, fallback) {
  return allowed.includes(value) ? value : fallback;
}

function cleanString(value, maxLength) {
  if (typeof value !== 'string') return undefined;
  const trimmed = value.trim();
  if (trimmed === '') return undefined;
  return trimmed.slice(0, maxLength);
}

function sanitizeExercise(raw) {
  if (!raw || typeof raw !== 'object') return null;
  const name = cleanString(raw.name, 200);
  if (!name) return null; // an exercise without a name is unusable

  const exercise = {
    name,
    sets: clampInt(raw.sets, 1, 20, 3),
    restSeconds: clampInt(raw.restSeconds, 0, 1200, 60),
    formTracked: raw.formTracked === true,
  };
  // reps: null/absent means "to failure" / time-based — leave unset.
  if (raw.reps !== undefined && raw.reps !== null) {
    exercise.reps = clampInt(raw.reps, 1, 100, undefined);
  }
  if (typeof raw.targetWeightKg === 'number' && raw.targetWeightKg >= 0) {
    exercise.targetWeightKg = raw.targetWeightKg;
  }
  const notes = cleanString(raw.notes, 300);
  if (notes) exercise.notes = notes;
  return exercise;
}

function sanitizeWorkout(raw) {
  if (!raw || typeof raw !== 'object') return null;
  const name = cleanString(raw.name, 200);
  if (!name) return null;

  const exercises = Array.isArray(raw.exercises)
    ? raw.exercises.map(sanitizeExercise).filter(Boolean)
    : [];
  if (exercises.length === 0) return null; // a training day needs exercises

  const workout = { name, exercises };
  const description = cleanString(raw.description, 500);
  if (description) workout.description = description;
  const estimatedMinutes = clampInt(raw.estimatedMinutes, 1, 360, undefined);
  if (estimatedMinutes !== undefined) workout.estimatedMinutes = estimatedMinutes;
  return workout;
}

/**
 * Coerce raw model output into a safe plan shape. Clamps every numeric field to
 * its model bounds, drops unusable entries, and falls back to the profile's own
 * goal/experience when the model returns an out-of-vocabulary value — so a
 * malformed-but-parseable response can never throw at the Mongoose layer.
 * Throws a 502 only when there's nothing usable to persist.
 *
 * @param {object} raw  parsed JSON from the model
 * @param {object} profile  the caller's profile (for fallbacks)
 * @returns {object} a plan object ready to persist
 */
function sanitizeGeneratedPlan(raw, profile) {
  if (!raw || typeof raw !== 'object') {
    throw new ApiError(502, 'AI returned an unusable plan');
  }

  const workouts = Array.isArray(raw.workouts)
    ? raw.workouts.map(sanitizeWorkout).filter(Boolean)
    : [];
  if (workouts.length === 0) {
    throw new ApiError(502, 'AI returned a plan with no usable workouts');
  }

  const goalFallback = (profile.goals && profile.goals[0]) || 'general_fitness';
  const equipment = Array.isArray(raw.equipment)
    ? raw.equipment.filter((e) => EQUIPMENT.includes(e))
    : [];

  return {
    name: cleanString(raw.name, 200) || 'Personalized Plan',
    description: cleanString(raw.description, 1000),
    goal: oneOf(raw.goal, GOALS, goalFallback),
    experience: oneOf(raw.experience, EXPERIENCE_LEVELS, profile.experience),
    daysPerWeek: clampInt(raw.daysPerWeek, 1, 7, workouts.length),
    equipment,
    workouts,
  };
}

// ---- persistence -----------------------------------------------------------

/**
 * Persist a sanitized plan as the caller's active Plan: owned Workouts plus an
 * owned, non-template Plan with `isActive:true`. Mirrors `adoptTemplate` —
 * enforces one active plan per user by deactivating any prior active plan, and
 * `sourceTemplate` is null (this plan came from the AI, not the library).
 *
 * @param {string} userId
 * @param {object} plan  sanitized plan from `sanitizeGeneratedPlan`
 * @returns {Promise<object>} the new active plan, workouts populated
 */
async function persistGeneratedPlan(userId, plan) {
  const ownedWorkouts = await Workout.create(
    plan.workouts.map((w) => ({
      name: w.name,
      description: w.description,
      exercises: w.exercises,
      estimatedMinutes: w.estimatedMinutes,
      owner: userId,
    }))
  );

  await Plan.updateMany(
    { owner: userId, isActive: true },
    { $set: { isActive: false } }
  );

  const created = await Plan.create({
    name: plan.name,
    description: plan.description,
    goal: plan.goal,
    experience: plan.experience,
    daysPerWeek: plan.daysPerWeek,
    equipment: plan.equipment,
    workouts: ownedWorkouts.map((w) => w._id),
    isTemplate: false,
    owner: userId,
    sourceTemplate: null,
    isActive: true,
  });

  return created.populate('workouts');
}

// ---- entry point -----------------------------------------------------------

/**
 * Generate and persist a personalized plan for the caller.
 *
 * @param {string} userId
 * @param {object} [input]
 * @param {object|null} [input.vitals]  client-supplied recovery snapshot
 * @returns {Promise<object>} the new active plan (workouts populated)
 */
async function generatePlan(userId, { vitals } = {}) {
  const [profile, logs] = await Promise.all([
    Profile.findOne({ user: userId }),
    WorkoutLog.find({ user: userId })
      .sort({ startedAt: -1 })
      .limit(RECENT_LOG_LIMIT),
  ]);

  if (!profile) {
    throw new ApiError(400, 'Complete onboarding before generating a plan');
  }

  const client = getClient();

  const response = await client.messages.create({
    model: config.gemini.model,
    max_tokens: MAX_TOKENS,
    system: SYSTEM_PROMPT,
    output_config: { format: { type: 'json_schema', schema: PLAN_SCHEMA } },
    messages: [
      {
        role: 'user',
        content: buildUserMessage({
          profile,
          history: historyContext(logs),
          vitals,
        }),
      },
    ],
  });

  const block = (response && response.content || []).find(
    (b) => b && b.type === 'text'
  );
  if (!block || typeof block.text !== 'string') {
    throw new ApiError(502, 'AI returned no plan');
  }

  let parsed;
  try {
    parsed = JSON.parse(block.text);
  } catch (err) {
    throw new ApiError(502, 'AI returned an invalid plan');
  }

  const plan = sanitizeGeneratedPlan(parsed, profile);
  return persistGeneratedPlan(userId, plan);
}

module.exports = {
  generatePlan,
  // exported for unit tests
  sanitizeGeneratedPlan,
  buildUserMessage,
  PLAN_SCHEMA,
};
