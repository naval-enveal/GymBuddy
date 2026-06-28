'use strict';

const express = require('express');
const { generateCues } = require('../controllers/coaching.controller');
const { requireAuth } = require('../middleware/auth.middleware');
const { asyncHandler } = require('../middleware/error.middleware');
const { validateCoachingCues } = require('../validators/coaching.validators');

const router = express.Router();

// Generate short, prioritized spoken coaching cues from a sampled pose/form
// snapshot via the Claude API. Premium gating for this endpoint lands in a
// later M9 task (enforced server-side from the Subscription record).
router.post(
  '/cues',
  requireAuth,
  validateCoachingCues,
  asyncHandler(generateCues)
);

module.exports = router;
