'use strict';

const { Subscription } = require('../models');
const { ApiError } = require('./error.middleware');

/**
 * Premium-entitlement gate. Mount AFTER `requireAuth` (it reads `req.userId`):
 * the user's `Subscription` record is the server-side source of truth for
 * premium access, reconciled from RevenueCat (M9). The client's
 * `PremiumService`/`isPremiumProvider` is informational UX only and is NEVER
 * trusted here — a free user is rejected with `402 Payment Required` regardless
 * of what the client claims.
 *
 * Entitlement is decided by `Subscription.isPremiumActive()` (tier + status +
 * expiry together), so a cancelled/expired premium subscription is gated out
 * even while the row still says `tier: 'premium'`. A user with no subscription
 * row at all (defense in depth — registration creates a free one) is treated as
 * free and rejected.
 */
async function requirePremium(req, res, next) {
  let subscription;
  try {
    subscription = await Subscription.findOne({ user: req.userId });
  } catch (err) {
    return next(err);
  }

  if (!subscription || !subscription.isPremiumActive()) {
    return next(new ApiError(402, 'Premium subscription required'));
  }

  return next();
}

module.exports = { requirePremium };
