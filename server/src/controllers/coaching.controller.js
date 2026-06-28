'use strict';

const coachingService = require('../services/coaching.service');

/**
 * Coaching endpoints. The caller is authenticated by `requireAuth` (so
 * `req.userId` is trustworthy). Errors propagate to the central `errorHandler`.
 */

/**
 * Generate a short, prioritized list of spoken coaching cues for the caller's
 * current set from the sampled pose/form snapshot in the body. The app plays
 * them through the glasses. Returns `{ cues: [...] }` (possibly empty when the
 * set looked clean).
 */
async function generateCues(req, res) {
  const cues = await coachingService.generateCues(req.userId, req.body);
  return res.status(200).json({ cues });
}

module.exports = { generateCues };
