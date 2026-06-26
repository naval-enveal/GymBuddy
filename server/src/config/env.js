'use strict';

const dotenv = require('dotenv');

dotenv.config();

const config = {
  port: parseInt(process.env.PORT, 10) || 4000,
  nodeEnv: process.env.NODE_ENV || 'development',
  mongoUri: process.env.MONGODB_URI || 'mongodb://localhost:27017/gymbuddy',
  // Auth / JWT. Secrets come from env; the fallbacks below are dev/test-only
  // and MUST be overridden in production (see assertProdSecrets()).
  jwt: {
    accessSecret: process.env.JWT_ACCESS_SECRET || 'dev-access-secret',
    refreshSecret: process.env.JWT_REFRESH_SECRET || 'dev-refresh-secret',
    accessTtl: process.env.JWT_ACCESS_TTL || '15m',
    refreshTtl: process.env.JWT_REFRESH_TTL || '30d',
  },
  bcryptRounds: parseInt(process.env.BCRYPT_ROUNDS, 10) || 12,
};

/**
 * Fail fast if real JWT secrets are missing in production — the dev fallbacks
 * must never ship. Called at boot (server.js), not at import, so tests using
 * the dev defaults are unaffected.
 */
function assertProdSecrets() {
  if (config.nodeEnv !== 'production') return;
  if (!process.env.JWT_ACCESS_SECRET || !process.env.JWT_REFRESH_SECRET) {
    throw new Error(
      'JWT_ACCESS_SECRET and JWT_REFRESH_SECRET must be set in production'
    );
  }
}

module.exports = config;
module.exports.assertProdSecrets = assertProdSecrets;
