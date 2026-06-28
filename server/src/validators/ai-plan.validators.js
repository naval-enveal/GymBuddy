'use strict';

const { ApiError } = require('../middleware/error.middleware');

/**
 * Validation for `POST /plans/generate` (M9). The only client-supplied input is
 * an optional `vitals` snapshot (resting HR / HRV / sleep / steps / readiness),
 * read on-device from HealthKit/Health Connect — the server doesn't store
 * vitals, so they arrive in the request. Profile and history are read
 * server-side from the DB and are not accepted from the body.
 *
 * Same spirit as the other validators: reject the first violation with a 400
 * `ApiError`, and on success replace `req.body` with ONLY the declared, coerced
 * fields so nothing else can be smuggled through.
 */

// Generous upper bounds — just sanity caps so a client can't push absurd values
// into the prompt. Lower bound is 0 for all.
const VITALS_FIELDS = {
  restingHeartRate: 300,
  hrv: 1000,
  sleepHours: 24,
  steps: 200000,
  readiness: 100,
};

function isPlainObject(value) {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function cleanVitals(raw) {
  if (!isPlainObject(raw)) {
    throw new ApiError(400, 'vitals must be an object');
  }
  const clean = {};
  for (const [field, max] of Object.entries(VITALS_FIELDS)) {
    const value = raw[field];
    if (value === undefined || value === null) continue;
    if (typeof value !== 'number' || !Number.isFinite(value)) {
      throw new ApiError(400, `${field} must be a number`);
    }
    if (value < 0 || value > max) {
      throw new ApiError(400, `${field} must be between 0 and ${max}`);
    }
    clean[field] = value;
  }
  return clean;
}

function validateGeneratePlan(req, res, next) {
  const body = req.body;
  if (body !== undefined && body !== null && !isPlainObject(body)) {
    return next(new ApiError(400, 'Request body must be a JSON object'));
  }

  try {
    const clean = {};
    if (body && body.vitals !== undefined && body.vitals !== null) {
      clean.vitals = cleanVitals(body.vitals);
    }
    req.body = clean;
    return next();
  } catch (err) {
    return next(err);
  }
}

module.exports = { validateGeneratePlan };
