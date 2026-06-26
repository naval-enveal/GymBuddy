'use strict';

const express = require('express');
const {
  register,
  login,
  refresh,
  logout,
} = require('../controllers/auth.controller');
const { validate } = require('../middleware/validate.middleware');
const { asyncHandler } = require('../middleware/error.middleware');
const schemas = require('../validators/auth.validators');

const router = express.Router();

router.post('/register', validate(schemas.register), asyncHandler(register));
router.post('/login', validate(schemas.login), asyncHandler(login));
router.post('/refresh', validate(schemas.refresh), asyncHandler(refresh));
router.post('/logout', validate(schemas.logout), asyncHandler(logout));

module.exports = router;
