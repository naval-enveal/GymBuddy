'use strict';

const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const config = require('../config/env');

const ISSUER = 'gymbuddy';

/**
 * JWT signing/verification for the auth flow. Two token types:
 *  - access  — short-lived, sent in the Authorization header, stateless.
 *  - refresh — long-lived, carries a unique `jti` so it can be tracked and
 *              revoked server-side (see refresh-token.model + auth.service).
 *
 * Each type is signed with its own secret so an access token can never be
 * replayed as a refresh token (or vice versa) even if a secret leaks.
 */

function signAccessToken(userId) {
  return jwt.sign({ type: 'access' }, config.jwt.accessSecret, {
    subject: String(userId),
    issuer: ISSUER,
    expiresIn: config.jwt.accessTtl,
  });
}

/**
 * Sign a refresh token. Returns both the token and its `jti` so the caller can
 * persist the id for revocation/rotation.
 *
 * @param {string} userId
 * @returns {{ token: string, jti: string }}
 */
function signRefreshToken(userId) {
  const jti = crypto.randomUUID();
  const token = jwt.sign({ type: 'refresh' }, config.jwt.refreshSecret, {
    subject: String(userId),
    issuer: ISSUER,
    expiresIn: config.jwt.refreshTtl,
    jwtid: jti,
  });
  return { token, jti };
}

/** Verify an access token. Throws (jwt error) if invalid/expired/wrong type. */
function verifyAccessToken(token) {
  const payload = jwt.verify(token, config.jwt.accessSecret, {
    issuer: ISSUER,
  });
  if (payload.type !== 'access') {
    throw new jwt.JsonWebTokenError('invalid token type');
  }
  return payload;
}

/** Verify a refresh token. Throws (jwt error) if invalid/expired/wrong type. */
function verifyRefreshToken(token) {
  const payload = jwt.verify(token, config.jwt.refreshSecret, {
    issuer: ISSUER,
  });
  if (payload.type !== 'refresh') {
    throw new jwt.JsonWebTokenError('invalid token type');
  }
  return payload;
}

module.exports = {
  signAccessToken,
  signRefreshToken,
  verifyAccessToken,
  verifyRefreshToken,
};
