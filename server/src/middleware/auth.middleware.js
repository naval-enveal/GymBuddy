'use strict';

const jwt = require('jsonwebtoken');
const { verifyAccessToken } = require('../services/token.service');
const { User } = require('../models');

/**
 * Authentication middleware. Verifies the `Authorization: Bearer <access>`
 * header, loads the owning user, and attaches it to `req.user` for downstream
 * handlers. Any failure — missing header, malformed scheme, invalid/expired
 * token, or a user that no longer exists — is rejected with `401` and the
 * shared `{ error: { message } }` response shape.
 *
 * Built on `verifyAccessToken` (token.service): only access tokens pass; a
 * refresh token presented here fails the `type` check and is rejected.
 */
function unauthorized(res, message) {
  return res.status(401).json({ error: { message } });
}

/** Extract the bearer token from the Authorization header, or null. */
function bearerToken(header) {
  if (typeof header !== 'string') return null;
  const match = /^Bearer (.+)$/.exec(header.trim());
  return match ? match[1].trim() : null;
}

async function requireAuth(req, res, next) {
  const token = bearerToken(req.headers.authorization);
  if (!token) {
    return unauthorized(res, 'Authentication required');
  }

  let payload;
  try {
    payload = verifyAccessToken(token);
  } catch (err) {
    if (err instanceof jwt.JsonWebTokenError) {
      return unauthorized(res, 'Invalid or expired token');
    }
    return next(err);
  }

  let user;
  try {
    user = await User.findById(payload.sub);
  } catch (err) {
    return next(err);
  }
  if (!user) {
    // Token was valid but the account is gone (deleted/disabled).
    return unauthorized(res, 'Invalid or expired token');
  }

  req.user = user;
  req.userId = String(user._id);
  return next();
}

module.exports = { requireAuth };
