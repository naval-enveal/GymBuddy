'use strict';

const express = require('express');
const healthRoutes = require('./routes/health.routes');
const authRoutes = require('./routes/auth.routes');
const profileRoutes = require('./routes/profile.routes');
const planRoutes = require('./routes/plan.routes');
const workoutLogRoutes = require('./routes/workout-log.routes');
const { errorHandler } = require('./middleware/error.middleware');

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
  app.use('/profile', profileRoutes);
  app.use('/plans', planRoutes);
  app.use('/workout-logs', workoutLogRoutes);

  // 404 fallback.
  app.use((req, res) => {
    res.status(404).json({ error: { message: 'Not found' } });
  });

  // Central error handler — owns the shared { error: { message } } shape.
  // Must be mounted last, after all routes.
  app.use(errorHandler);

  return app;
}

module.exports = createApp;
