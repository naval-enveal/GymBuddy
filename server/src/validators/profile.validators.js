'use strict';

const { ApiError } = require('../middleware/error.middleware');
const {
  GOALS,
  EXPERIENCE_LEVELS,
  EQUIPMENT,
  SEXES,
} = require('../models/constants');

/**
 * Validation for the Profile upsert (`PUT /profile`). The generic
 * `validate(schema)` middleware only understands scalar string/email fields,
 * whereas a profile carries enum arrays, a nested body-stats object, and
 * numeric ranges — so this is a dedicated validator built in the same spirit:
 * it rejects the first violation with a 400 `ApiError` (rendered by the shared
 * error handler) and, on success, replaces `req.body` with ONLY the declared,
 * coerced fields so a client can't smuggle extra properties into the upsert.
 *
 * Every field is optional (a partial profile is valid mid-onboarding), but any
 * field that IS present must be well-formed. Bounds mirror
 * `models/profile.model.js`.
 */

// Per-injury cap matches the model's `maxlength`. The list cap is a sanity
// bound so a client can't push an unbounded array.
const MAX_INJURY_LENGTH = 120;
const MAX_INJURIES = 50;

function isPlainObject(value) {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

/** Coerce + dedupe an array whose every member must be in [allowed]. */
function enumArray(value, allowed, field) {
  if (!Array.isArray(value)) {
    throw new ApiError(400, `${field} must be an array`);
  }
  const out = [];
  for (const item of value) {
    if (typeof item !== 'string' || !allowed.includes(item)) {
      throw new ApiError(400, `${field} contains an invalid value`);
    }
    if (!out.includes(item)) out.push(item);
  }
  return out;
}

function intInRange(value, min, max, field) {
  if (
    typeof value !== 'number' ||
    !Number.isInteger(value) ||
    value < min ||
    value > max
  ) {
    throw new ApiError(
      400,
      `${field} must be an integer between ${min} and ${max}`
    );
  }
  return value;
}

function numInRange(value, min, max, field) {
  if (
    typeof value !== 'number' ||
    !Number.isFinite(value) ||
    value < min ||
    value > max
  ) {
    throw new ApiError(400, `${field} must be between ${min} and ${max}`);
  }
  return value;
}

function cleanInjuries(value) {
  if (!Array.isArray(value)) {
    throw new ApiError(400, 'injuries must be an array');
  }
  const out = [];
  for (const item of value) {
    if (typeof item !== 'string') {
      throw new ApiError(400, 'injuries must contain only strings');
    }
    const trimmed = item.trim();
    if (trimmed === '') continue; // drop blanks rather than reject the whole list
    if (trimmed.length > MAX_INJURY_LENGTH) {
      throw new ApiError(
        400,
        `each injury must be at most ${MAX_INJURY_LENGTH} characters`
      );
    }
    if (!out.includes(trimmed)) out.push(trimmed);
  }
  if (out.length > MAX_INJURIES) {
    throw new ApiError(400, `at most ${MAX_INJURIES} injuries allowed`);
  }
  return out;
}

function cleanBodyStats(value) {
  if (!isPlainObject(value)) {
    throw new ApiError(400, 'bodyStats must be an object');
  }
  const stats = {};
  if (value.heightCm !== undefined && value.heightCm !== null) {
    stats.heightCm = numInRange(value.heightCm, 50, 300, 'heightCm');
  }
  if (value.weightKg !== undefined && value.weightKg !== null) {
    stats.weightKg = numInRange(value.weightKg, 20, 500, 'weightKg');
  }
  if (value.age !== undefined && value.age !== null) {
    stats.age = intInRange(value.age, 13, 120, 'age');
  }
  if (value.sex !== undefined && value.sex !== null) {
    if (!SEXES.includes(value.sex)) {
      throw new ApiError(400, 'sex is invalid');
    }
    stats.sex = value.sex;
  }
  return stats;
}

function validateProfile(req, res, next) {
  const body = req.body;
  if (!isPlainObject(body)) {
    return next(new ApiError(400, 'Request body must be a JSON object'));
  }

  try {
    const clean = {};

    if (body.goals !== undefined) {
      clean.goals = enumArray(body.goals, GOALS, 'goals');
    }
    if (body.equipment !== undefined) {
      clean.equipment = enumArray(body.equipment, EQUIPMENT, 'equipment');
    }
    if (body.experience !== undefined && body.experience !== null) {
      if (!EXPERIENCE_LEVELS.includes(body.experience)) {
        throw new ApiError(400, 'experience is invalid');
      }
      clean.experience = body.experience;
    }
    if (body.daysPerWeek !== undefined && body.daysPerWeek !== null) {
      clean.daysPerWeek = intInRange(body.daysPerWeek, 1, 7, 'daysPerWeek');
    }
    if (body.injuries !== undefined) {
      clean.injuries = cleanInjuries(body.injuries);
    }
    if (body.bodyStats !== undefined && body.bodyStats !== null) {
      clean.bodyStats = cleanBodyStats(body.bodyStats);
    }
    if (body.onboardingComplete !== undefined) {
      if (typeof body.onboardingComplete !== 'boolean') {
        throw new ApiError(400, 'onboardingComplete must be a boolean');
      }
      clean.onboardingComplete = body.onboardingComplete;
    }

    req.body = clean;
    return next();
  } catch (err) {
    return next(err);
  }
}

module.exports = { validateProfile };
