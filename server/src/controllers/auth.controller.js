'use strict';

const authService = require('../services/auth.service');

/**
 * Auth endpoints. Each maps the service result onto JSON, and any thrown
 * `AuthError` onto the shared `{ error: { message } }` shape with its status.
 * Thorough request validation arrives with the validation middleware (later
 * M1 task); these handlers only do the minimal guarding needed to operate
 * safely.
 */

function fail(res, statusCode, message) {
  return res.status(statusCode).json({ error: { message } });
}

function handleServiceError(res, err) {
  if (err instanceof authService.AuthError) {
    return fail(res, err.statusCode, err.message);
  }
  // Duplicate-key race on the unique email index (two registers at once).
  if (err && err.code === 11000) {
    return fail(res, 409, 'Email already registered');
  }
  // Mongoose schema validation (e.g. malformed email reaching the model).
  if (err && err.name === 'ValidationError') {
    return fail(res, 400, 'Invalid request');
  }
  throw err;
}

function authPayload({ user, accessToken, refreshToken }) {
  return { user: user.toJSON(), accessToken, refreshToken };
}

async function register(req, res) {
  const { email, password, displayName } = req.body || {};
  if (!email || !password) {
    return fail(res, 400, 'email and password are required');
  }
  try {
    const result = await authService.register({ email, password, displayName });
    return res.status(201).json(authPayload(result));
  } catch (err) {
    return handleServiceError(res, err);
  }
}

async function login(req, res) {
  const { email, password } = req.body || {};
  if (!email || !password) {
    return fail(res, 400, 'email and password are required');
  }
  try {
    const result = await authService.login({ email, password });
    return res.status(200).json(authPayload(result));
  } catch (err) {
    return handleServiceError(res, err);
  }
}

async function refresh(req, res) {
  const { refreshToken } = req.body || {};
  if (!refreshToken) {
    return fail(res, 400, 'refreshToken is required');
  }
  try {
    const tokens = await authService.refresh(refreshToken);
    return res.status(200).json(tokens);
  } catch (err) {
    return handleServiceError(res, err);
  }
}

async function logout(req, res) {
  const { refreshToken } = req.body || {};
  if (!refreshToken) {
    return fail(res, 400, 'refreshToken is required');
  }
  try {
    await authService.logout(refreshToken);
    return res.status(204).send();
  } catch (err) {
    return handleServiceError(res, err);
  }
}

module.exports = { register, login, refresh, logout };
