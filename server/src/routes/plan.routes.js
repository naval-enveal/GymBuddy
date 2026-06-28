'use strict';

const express = require('express');
const {
  getTemplates,
  adoptPlan,
  getActivePlan,
  generatePlan,
} = require('../controllers/plan.controller');
const { requireAuth } = require('../middleware/auth.middleware');
const { asyncHandler } = require('../middleware/error.middleware');
const { validateGeneratePlan } = require('../validators/ai-plan.validators');

const router = express.Router();

// Template library ranked against the authenticated caller's profile.
router.get('/templates', requireAuth, asyncHandler(getTemplates));

// The caller's currently active plan (or null if none adopted).
router.get('/active', requireAuth, asyncHandler(getActivePlan));

// Generate a personalized plan via the Claude API (profile + history + vitals)
// and adopt it as the caller's active plan. Premium gating for this endpoint
// lands in a later M9 task (enforced server-side from the Subscription record).
router.post(
  '/generate',
  requireAuth,
  validateGeneratePlan,
  asyncHandler(generatePlan)
);

// Adopt a template as the caller's active plan (deactivates any prior active
// plan server-side — one active plan per user).
router.post('/:id/adopt', requireAuth, asyncHandler(adoptPlan));

module.exports = router;
