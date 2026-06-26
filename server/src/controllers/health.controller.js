'use strict';

const { dbState } = require('../db/connect');

/**
 * Liveness/readiness probe. Always 200 when the process is serving requests;
 * the `db` field reports MongoDB connectivity without failing the response.
 */
function getHealth(req, res) {
  res.status(200).json({
    status: 'ok',
    uptime: process.uptime(),
    timestamp: new Date().toISOString(),
    db: dbState(),
  });
}

module.exports = { getHealth };
