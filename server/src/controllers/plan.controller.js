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

async function adoptPlan(req, res) {
  const plan = await planService.adoptTemplate(req.userId, req.params.id);
  return res.status(201).json({ plan: plan.toJSON() });
}

async function getActivePlan(req, res) {
  const plan = await planService.getActivePlan(req.userId);
  return res.status(200).json({ plan: plan ? plan.toJSON() : null });
}

module.exports = { getTemplates, adoptPlan, getActivePlan };
