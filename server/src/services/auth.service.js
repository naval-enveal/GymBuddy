'use strict';

const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const config = require('../config/env');
const { User, Subscription, RefreshToken } = require('../models');
const {
  signAccessToken,
  signRefreshToken,
  verifyRefreshToken,
} = require('./token.service');

/**
 * Domain error for the auth flow. Carries an HTTP status so the controller can
 * map it onto the shared `{ error: { message } }` response shape. Messages are
 * intentionally generic (no "user not found" vs "wrong password") to avoid
 * leaking which accounts exist.
 */
class AuthError extends Error {
  constructor(statusCode, message) {
    super(message);
    this.name = 'AuthError';
    this.statusCode = statusCode;
  }
}

function hashPassword(plain) {
  return bcrypt.hash(plain, config.bcryptRounds);
}

function verifyPassword(plain, hash) {
  return bcrypt.compare(plain, hash);
}

/** Compute the refresh token's expiry Date from its decoded `exp` claim. */
function expiryFromToken(token) {
  const { exp } = verifyRefreshToken(token);
  return new Date(exp * 1000);
}

/**
 * Issue a fresh access/refresh pair for a user and persist the refresh token's
 * id so it can later be rotated or revoked.
 *
 * @param {string} userId
 * @returns {Promise<{ accessToken: string, refreshToken: string }>}
 */
async function issueTokens(userId) {
  const accessToken = signAccessToken(userId);
  const { token: refreshToken, jti } = signRefreshToken(userId);
  await RefreshToken.create({
    jti,
    user: userId,
    expiresAt: expiryFromToken(refreshToken),
  });
  return { accessToken, refreshToken };
}

/**
 * Register a new account: store the bcrypt password hash, create the default
 * free subscription, and issue a token pair.
 *
 * @throws {AuthError} 409 if the email is already registered.
 */
async function register({ email, password, displayName }) {
  const normalizedEmail = String(email).toLowerCase().trim();

  const existing = await User.findOne({ email: normalizedEmail });
  if (existing) {
    throw new AuthError(409, 'Email already registered');
  }

  const passwordHash = await hashPassword(password);
  const user = await User.create({
    email: normalizedEmail,
    passwordHash,
    displayName,
  });

  // Every account starts on the free tier; premium is reconciled later (M9).
  await Subscription.create({ user: user._id });

  const tokens = await issueTokens(user._id);
  return { user, ...tokens };
}

/**
 * Authenticate by email + password and issue a token pair.
 *
 * @throws {AuthError} 401 on unknown email or bad password (same message for
 * both, to avoid account enumeration).
 */
async function login({ email, password }) {
  const normalizedEmail = String(email).toLowerCase().trim();

  // passwordHash is `select: false`; pull it in explicitly for verification.
  const user = await User.findOne({ email: normalizedEmail }).select(
    '+passwordHash'
  );
  if (!user) {
    throw new AuthError(401, 'Invalid email or password');
  }

  const ok = await verifyPassword(password, user.passwordHash);
  if (!ok) {
    throw new AuthError(401, 'Invalid email or password');
  }

  const tokens = await issueTokens(user._id);
  return { user, ...tokens };
}

/**
 * Rotate a refresh token: validate it, ensure it has not been revoked, then
 * delete the old id and issue a brand-new pair. Reusing or replaying an old
 * (already-rotated or revoked) token fails.
 *
 * @throws {AuthError} 401 if the token is invalid, expired, or revoked.
 */
async function refresh(refreshToken) {
  let payload;
  try {
    payload = verifyRefreshToken(refreshToken);
  } catch (err) {
    if (err instanceof jwt.JsonWebTokenError) {
      throw new AuthError(401, 'Invalid or expired refresh token');
    }
    throw err;
  }

  // Atomically consume the stored id: if it is gone, the token was already
  // rotated, revoked, or never issued by us — reject.
  const consumed = await RefreshToken.findOneAndDelete({ jti: payload.jti });
  if (!consumed) {
    throw new AuthError(401, 'Invalid or expired refresh token');
  }

  return issueTokens(payload.sub);
}

/**
 * Revoke a refresh token (logout). Idempotent: logging out with a token that
 * is already gone is not an error.
 */
async function logout(refreshToken) {
  let payload;
  try {
    payload = verifyRefreshToken(refreshToken);
  } catch {
    // A token we can't verify can't be in our store; nothing to revoke.
    return;
  }
  await RefreshToken.deleteOne({ jti: payload.jti });
}

module.exports = {
  AuthError,
  hashPassword,
  verifyPassword,
  register,
  login,
  refresh,
  logout,
};
