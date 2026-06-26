'use strict';

const planService = require('../services/plan.service');

/**
 * Plan endpoints. The caller is authenticated by `requireAuth` (so `req.userId`
 * is trustworthy). Errors propagate to the central `errorHandler`.
 */

async function getTemplates(req, res) {
  const templates = await planService.getMatchedTemplates(req.userId);
  return res.status(200).json({ templates });
}

module.exports = { getTemplates };
