'use strict';

const mongoose = require('mongoose');

/**
 * Server-side record of an issued refresh token, keyed by its JWT id (`jti`).
 * Refresh tokens are JWTs, but they are also tracked here so they can be
 * revoked: logout deletes the row, and refresh rotates it (delete old, insert
 * new). A presented refresh token is only honored if its `jti` is still here.
 *
 * The token string itself is never stored — only its id — so a leak of this
 * collection does not expose usable tokens. The `expiresAt` TTL index lets
 * Mongo reap rows once the underlying token has expired.
 */
const refreshTokenSchema = new mongoose.Schema(
  {
    jti: {
      type: String,
      required: true,
      unique: true,
      index: true,
    },
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    // Mongo removes the document once this time passes (TTL index).
    expiresAt: {
      type: Date,
      required: true,
      index: { expires: 0 },
    },
  },
  { timestamps: true }
);

module.exports =
  mongoose.models.RefreshToken ||
  mongoose.model('RefreshToken', refreshTokenSchema);
