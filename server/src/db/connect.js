'use strict';

const mongoose = require('mongoose');
const config = require('../config/env');

/**
 * Connect to MongoDB. Boot should not hard-fail when the database is
 * unreachable — the health-check surfaces DB state instead — so the caller
 * decides how to handle a rejection.
 *
 * @returns {Promise<typeof mongoose>}
 */
function connectDb() {
  mongoose.set('strictQuery', true);
  return mongoose.connect(config.mongoUri);
}

/**
 * Human-readable state of the default mongoose connection.
 * @returns {'disconnected'|'connected'|'connecting'|'disconnecting'|'unknown'}
 */
function dbState() {
  const states = {
    0: 'disconnected',
    1: 'connected',
    2: 'connecting',
    3: 'disconnecting',
  };
  return states[mongoose.connection.readyState] || 'unknown';
}

module.exports = { connectDb, dbState };
