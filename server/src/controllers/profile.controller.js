'use strict';

const profileService = require('../services/profile.service');

/**
 * Profile endpoints. The body is validated/sanitized upstream by
 * `validateProfile`, and the caller is authenticated by `requireAuth` (so
 * `req.userId` is trustworthy). Errors propagate to the central `errorHandler`.
 */

async function getMyProfile(req, res) {
  const profile = await profileService.getProfile(req.userId);
  return res.status(200).json({ profile: profile ? profile.toJSON() : null });
}

async function putMyProfile(req, res) {
  const profile = await profileService.upsertProfile(req.userId, req.body);
  return res.status(200).json({ profile: profile.toJSON() });
}

module.exports = { getMyProfile, putMyProfile };
