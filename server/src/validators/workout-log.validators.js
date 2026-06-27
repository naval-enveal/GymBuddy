'use strict';

const mongoose = require('mongoose');
const { ApiError } = require('../middleware/error.middleware');

/**
 * Validation for the WorkoutLog write (`POST /workout-logs`). Built in the same
 * spirit as the profile validator: it rejects the first violation with a 400
 * `ApiError` (rendered by the shared error handler) and, on success, replaces
 * `req.body` with ONLY the declared, coerced fields so a client can't smuggle
 * extra properties (e.g. `user`) into the create.
 *
 * `startedAt` is the one required field — a log has to know when the session
 * began. Everything else is optional so a sparse summary still persists. Bounds
 * mirror `models/workout-log.model.js`.
 */

// Sanity caps so a client can't push unbounded arrays.
const MAX_EXERCISES = 100;
const MAX_SETS = 100;
const MAX_NOTES_LENGTH = 1000;
const MAX_REPS = 1000;
const MAX_EXERCISE_NAME = 200;

function isPlainObject(value) {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

/** Parse a date-ish value (ISO string or epoch ms) to a Date, or throw. */
function parseDate(value, field) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    throw new ApiError(400, `${field} must be a valid date`);
  }
  return date;
}

function numAtLeast(value, min, field) {
  if (typeof value !== 'number' || !Number.isFinite(value) || value < min) {
    throw new ApiError(400, `${field} must be a number >= ${min}`);
  }
  return value;
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

function objectId(value, field) {
  if (typeof value !== 'string' || !mongoose.isValidObjectId(value)) {
    throw new ApiError(400, `${field} must be a valid id`);
  }
  return value;
}

function cleanSet(value, idx) {
  if (!isPlainObject(value)) {
    throw new ApiError(400, `exercises set ${idx} must be an object`);
  }
  const set = {};
  if (value.reps !== undefined && value.reps !== null) {
    set.reps = intInRange(value.reps, 0, MAX_REPS, 'reps');
  }
  if (value.weightKg !== undefined && value.weightKg !== null) {
    set.weightKg = numAtLeast(value.weightKg, 0, 'weightKg');
  }
  if (value.completed !== undefined && value.completed !== null) {
    if (typeof value.completed !== 'boolean') {
      throw new ApiError(400, 'completed must be a boolean');
    }
    set.completed = value.completed;
  }
  return set;
}

function cleanExercise(value, idx) {
  if (!isPlainObject(value)) {
    throw new ApiError(400, `exercise ${idx} must be an object`);
  }
  const name = typeof value.name === 'string' ? value.name.trim() : '';
  if (name === '') {
    throw new ApiError(400, `exercise ${idx} requires a name`);
  }
  if (name.length > MAX_EXERCISE_NAME) {
    throw new ApiError(
      400,
      `exercise name must be at most ${MAX_EXERCISE_NAME} characters`
    );
  }
  const sets = value.sets === undefined ? [] : value.sets;
  if (!Array.isArray(sets)) {
    throw new ApiError(400, `exercise ${idx} sets must be an array`);
  }
  if (sets.length > MAX_SETS) {
    throw new ApiError(400, `at most ${MAX_SETS} sets per exercise allowed`);
  }
  return { name, sets: sets.map(cleanSet) };
}

function cleanExercises(value) {
  if (!Array.isArray(value)) {
    throw new ApiError(400, 'exercises must be an array');
  }
  if (value.length > MAX_EXERCISES) {
    throw new ApiError(400, `at most ${MAX_EXERCISES} exercises allowed`);
  }
  return value.map(cleanExercise);
}

function validateWorkoutLog(req, res, next) {
  const body = req.body;
  if (!isPlainObject(body)) {
    return next(new ApiError(400, 'Request body must be a JSON object'));
  }

  try {
    const clean = {};

    if (body.startedAt === undefined || body.startedAt === null) {
      throw new ApiError(400, 'startedAt is required');
    }
    clean.startedAt = parseDate(body.startedAt, 'startedAt');

    if (body.completedAt !== undefined && body.completedAt !== null) {
      clean.completedAt = parseDate(body.completedAt, 'completedAt');
    }
    if (body.durationSeconds !== undefined && body.durationSeconds !== null) {
      clean.durationSeconds = numAtLeast(
        body.durationSeconds,
        0,
        'durationSeconds'
      );
    }
    if (body.exercises !== undefined) {
      clean.exercises = cleanExercises(body.exercises);
    }
    if (body.plan !== undefined && body.plan !== null) {
      clean.plan = objectId(body.plan, 'plan');
    }
    if (body.workout !== undefined && body.workout !== null) {
      clean.workout = objectId(body.workout, 'workout');
    }
    if (body.notes !== undefined && body.notes !== null) {
      if (typeof body.notes !== 'string') {
        throw new ApiError(400, 'notes must be a string');
      }
      const notes = body.notes.trim();
      if (notes.length > MAX_NOTES_LENGTH) {
        throw new ApiError(
          400,
          `notes must be at most ${MAX_NOTES_LENGTH} characters`
        );
      }
      if (notes !== '') clean.notes = notes;
    }

    req.body = clean;
    return next();
  } catch (err) {
    return next(err);
  }
}

module.exports = { validateWorkoutLog };
