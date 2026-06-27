'use strict';

const { WorkoutLog } = require('../models');

/**
 * WorkoutLog persistence (M6). The session engine syncs a finished workout's
 * summary here on completion so progress can be tracked over time and fed back
 * into AI plan generation (M9).
 *
 * The request body is validated/sanitized upstream by `validateWorkoutLog`, so
 * this just stamps the owning user and writes.
 */

/**
 * Persist a completed workout for the given user.
 *
 * @param {string} userId  the authenticated caller (never trusted from the body)
 * @param {object} payload  validated log fields (startedAt + optional summary)
 * @returns {Promise<object>} the created WorkoutLog document
 */
async function createLog(userId, payload) {
  return WorkoutLog.create({ ...payload, user: userId });
}

module.exports = { createLog };
