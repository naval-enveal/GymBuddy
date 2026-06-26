'use strict';

const { Profile } = require('../models');

/**
 * Profile persistence. One profile per user (enforced by the unique `user`
 * index), created lazily on the first onboarding save.
 */

/** Fetch the caller's profile, or `null` if they haven't onboarded yet. */
async function getProfile(userId) {
  return Profile.findOne({ user: userId });
}

/**
 * Upsert the caller's profile from validated onboarding answers. Only the
 * fields present in [data] are written, so a partial save (mid-onboarding)
 * doesn't clobber untouched answers. Schema validators run on the update so a
 * bad value is rejected even though the body was already validated at the edge
 * (defense in depth).
 */
async function upsertProfile(userId, data) {
  return Profile.findOneAndUpdate(
    { user: userId },
    { $set: data },
    {
      new: true,
      upsert: true,
      runValidators: true,
      setDefaultsOnInsert: true,
    }
  );
}

module.exports = { getProfile, upsertProfile };
