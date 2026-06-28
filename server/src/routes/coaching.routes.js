'use strict';

const express = require('express');
const { generateCues } = require('../controllers/coaching.controller');
const { requireAuth } = require('../middleware/auth.middleware');
const { requirePremium } = require('../middleware/premium.middleware');
const { asyncHandler } = require('../middleware/error.middleware');
const { validateCoachingCues } = require('../validators/coaching.validators');

const router = express.Router();

// Generate short, prioritized spoken coaching cues from a sampled pose/form
// snapshot via the Claude API. Premium-gated server-side from the Subscription
// record (requirePremium) — a free user is rejected with 402 before any Claude
// call, regardless of what the client claims.
router.post(
  '/cues',
  requireAuth,
  requirePremium,
  validateCoachingCues,
  asyncHandler(generateCues)
);

module.exports = router;
