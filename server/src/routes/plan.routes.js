'use strict';

const express = require('express');
const {
  getTemplates,
  adoptPlan,
  getActivePlan,
} = require('../controllers/plan.controller');
const { requireAuth } = require('../middleware/auth.middleware');
const { asyncHandler } = require('../middleware/error.middleware');

const router = express.Router();

// Template library ranked against the authenticated caller's profile.
router.get('/templates', requireAuth, asyncHandler(getTemplates));

// The caller's currently active plan (or null if none adopted).
router.get('/active', requireAuth, asyncHandler(getActivePlan));

// Adopt a template as the caller's active plan (deactivates any prior active
// plan server-side — one active plan per user).
router.post('/:id/adopt', requireAuth, asyncHandler(adoptPlan));

module.exports = router;
