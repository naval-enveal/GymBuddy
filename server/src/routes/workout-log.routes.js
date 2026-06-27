'use strict';

const express = require('express');
const { createLog } = require('../controllers/workout-log.controller');
const { requireAuth } = require('../middleware/auth.middleware');
const { validateWorkoutLog } = require('../validators/workout-log.validators');
const { asyncHandler } = require('../middleware/error.middleware');

const router = express.Router();

// Persist a completed workout for the authenticated caller (synced by the
// session engine on completion).
router.post('/', requireAuth, validateWorkoutLog, asyncHandler(createLog));

module.exports = router;
