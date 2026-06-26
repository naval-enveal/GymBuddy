'use strict';

const express = require('express');
const healthRoutes = require('./routes/health.routes');
const authRoutes = require('./routes/auth.routes');

/**
 * Build the Express application. Kept free of side effects (no listen, no DB
 * connect) so it can be imported directly by tests via supertest.
 *
 * @returns {import('express').Express}
 */
function createApp() {
  const app = express();

  app.use(express.json());

  app.use('/health', healthRoutes);
  app.use('/auth', authRoutes);

  // 404 fallback.
  app.use((req, res) => {
    res.status(404).json({ error: { message: 'Not found' } });
  });

  return app;
}

module.exports = createApp;
