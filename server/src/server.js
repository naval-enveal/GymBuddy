'use strict';

const createApp = require('./app');
const { connectDb } = require('./db/connect');
const config = require('./config/env');

const app = createApp();

/**
 * Boot the HTTP server. The DB connection is attempted but a failure does not
 * prevent the server from serving requests (the health-check reports state).
 */
function start() {
  config.assertProdSecrets();

  connectDb()
    .then(() => {
      // eslint-disable-next-line no-console
      console.log('MongoDB connected');
    })
    .catch((err) => {
      // eslint-disable-next-line no-console
      console.error('MongoDB connection failed:', err.message);
    });

  app.listen(config.port, () => {
    // eslint-disable-next-line no-console
    console.log(`GymBuddy server listening on port ${config.port}`);
  });
}

if (require.main === module) {
  start();
}

module.exports = { app, start };
