'use strict';

const authService = require('../services/auth.service');

/**
 * Auth endpoints. Request bodies are validated upstream by the `validate`
 * middleware (see auth.routes), so handlers can trust `req.body` holds the
 * declared, sanitized fields. Errors are not handled here — they propagate to
 * the central `errorHandler`, which owns the shared `{ error: { message } }`
 * shape. Each handler is wrapped in `asyncHandler` at the route layer so a
 * rejected promise reaches that handler.
 */

function authPayload({ user, accessToken, refreshToken }) {
  return { user: user.toJSON(), accessToken, refreshToken };
}

async function register(req, res) {
  const { email, password, displayName } = req.body;
  const result = await authService.register({ email, password, displayName });
  return res.status(201).json(authPayload(result));
}

async function login(req, res) {
  const { email, password } = req.body;
  const result = await authService.login({ email, password });
  return res.status(200).json(authPayload(result));
}

async function refresh(req, res) {
  const tokens = await authService.refresh(req.body.refreshToken);
  return res.status(200).json(tokens);
}

async function logout(req, res) {
  await authService.logout(req.body.refreshToken);
  return res.status(204).send();
}

module.exports = { register, login, refresh, logout };
