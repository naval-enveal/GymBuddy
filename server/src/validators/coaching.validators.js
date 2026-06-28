'use strict';

const { ApiError } = require('../middleware/error.middleware');

/**
 * Validation for `POST /coaching/cues` (M9). The client supplies a snapshot of
 * what the on-device pose pipeline saw during a set: the `exercise`, the form
 * faults the `PoseFormChecker` fired (`formCues`), and how the set is going
 * (`reps`, `targetReps`, `setNumber`). Pose/form data lives on-device, so it
 * arrives in the request; the server never stores it. The caller's Profile is
 * read server-side and is not accepted from the body.
 *
 * Same spirit as the other validators: reject the first violation with a 400
 * `ApiError`, and on success replace `req.body` with ONLY the declared, coerced
 * fields so nothing else can be smuggled through.
 */

// Mirrors the Dart `FormSeverity` names (good/minor/major).
const SEVERITIES = ['good', 'minor', 'major'];

// Sanity caps so a client can't push absurd values into the prompt.
const MAX_FORM_CUES = 20;
const MAX_EXERCISE_LENGTH = 200;
const MAX_MESSAGE_LENGTH = 300;
const MAX_JOINT_LENGTH = 60;
const MAX_REPS = 1000;
const MAX_SET_NUMBER = 100;

function isPlainObject(value) {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function cleanString(value, field, maxLength) {
  if (typeof value !== 'string') {
    throw new ApiError(400, `${field} must be a string`);
  }
  const trimmed = value.trim();
  if (trimmed === '') {
    throw new ApiError(400, `${field} must not be empty`);
  }
  return trimmed.slice(0, maxLength);
}

function cleanInt(value, field, min, max) {
  if (typeof value !== 'number' || !Number.isFinite(value)) {
    throw new ApiError(400, `${field} must be a number`);
  }
  const n = Math.round(value);
  if (n < min || n > max) {
    throw new ApiError(400, `${field} must be between ${min} and ${max}`);
  }
  return n;
}

function cleanFormCue(raw, index) {
  if (!isPlainObject(raw)) {
    throw new ApiError(400, `formCues[${index}] must be an object`);
  }
  const cue = {
    message: cleanString(raw.message, `formCues[${index}].message`, MAX_MESSAGE_LENGTH),
  };
  if (raw.severity !== undefined && raw.severity !== null) {
    if (!SEVERITIES.includes(raw.severity)) {
      throw new ApiError(
        400,
        `formCues[${index}].severity must be one of ${SEVERITIES.join(', ')}`
      );
    }
    cue.severity = raw.severity;
  }
  if (raw.joint !== undefined && raw.joint !== null) {
    cue.joint = cleanString(raw.joint, `formCues[${index}].joint`, MAX_JOINT_LENGTH);
  }
  return cue;
}

function validateCoachingCues(req, res, next) {
  const body = req.body;
  if (body !== undefined && body !== null && !isPlainObject(body)) {
    return next(new ApiError(400, 'Request body must be a JSON object'));
  }

  try {
    const src = body || {};
    const clean = {
      exercise: cleanString(src.exercise, 'exercise', MAX_EXERCISE_LENGTH),
    };

    if (src.formCues !== undefined && src.formCues !== null) {
      if (!Array.isArray(src.formCues)) {
        throw new ApiError(400, 'formCues must be an array');
      }
      if (src.formCues.length > MAX_FORM_CUES) {
        throw new ApiError(400, `formCues must have at most ${MAX_FORM_CUES} entries`);
      }
      clean.formCues = src.formCues.map(cleanFormCue);
    }

    if (src.reps !== undefined && src.reps !== null) {
      clean.reps = cleanInt(src.reps, 'reps', 0, MAX_REPS);
    }
    if (src.targetReps !== undefined && src.targetReps !== null) {
      clean.targetReps = cleanInt(src.targetReps, 'targetReps', 1, MAX_REPS);
    }
    if (src.setNumber !== undefined && src.setNumber !== null) {
      clean.setNumber = cleanInt(src.setNumber, 'setNumber', 1, MAX_SET_NUMBER);
    }

    req.body = clean;
    return next();
  } catch (err) {
    return next(err);
  }
}

module.exports = { validateCoachingCues };
