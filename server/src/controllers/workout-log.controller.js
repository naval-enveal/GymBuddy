'use strict';

const workoutLogService = require('../services/workout-log.service');

/**
 * WorkoutLog endpoints. The body is validated/sanitized upstream by
 * `validateWorkoutLog`, and the caller is authenticated by `requireAuth` (so
 * `req.userId` is trustworthy). Errors propagate to the central `errorHandler`.
 */

async function createLog(req, res) {
  const log = await workoutLogService.createLog(req.userId, req.body);
  return res.status(201).json({ log: log.toJSON() });
}

module.exports = { createLog };
