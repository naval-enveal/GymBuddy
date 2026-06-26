'use strict';

const express = require('express');
const {
  getMyProfile,
  putMyProfile,
} = require('../controllers/profile.controller');
const { requireAuth } = require('../middleware/auth.middleware');
const { validateProfile } = require('../validators/profile.validators');
const { asyncHandler } = require('../middleware/error.middleware');

const router = express.Router();

// Both endpoints operate on the authenticated caller's own profile.
router.get('/', requireAuth, asyncHandler(getMyProfile));
router.put('/', requireAuth, validateProfile, asyncHandler(putMyProfile));

module.exports = router;
