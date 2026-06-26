'use strict';

const express = require('express');
const { getTemplates } = require('../controllers/plan.controller');
const { requireAuth } = require('../middleware/auth.middleware');
const { asyncHandler } = require('../middleware/error.middleware');

const router = express.Router();

// Template library ranked against the authenticated caller's profile.
router.get('/templates', requireAuth, asyncHandler(getTemplates));

module.exports = router;
