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
  // Claude API (M9). The key is SERVER-SIDE ONLY — the app never holds it, and
  // it's read from env, never committed. AI features degrade gracefully (503)
  // when unset rather than failing to boot, so the rest of the API runs without
  // it in dev/test.
  anthropic: {
    apiKey: process.env.ANTHROPIC_API_KEY || '',
    model: process.env.ANTHROPIC_MODEL || 'claude-opus-4-8',
  },
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
