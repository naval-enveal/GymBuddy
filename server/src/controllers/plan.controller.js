'use strict';

const planService = require('../services/plan.service');
const aiPlanService = require('../services/ai-plan.service');

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

/**
 * Generate a personalized plan with the Claude API from the caller's profile +
 * recent history + the vitals snapshot in the body, persist it as their active
 * plan, and return it. `req.body.vitals` is the validated snapshot (or absent).
 */
async function generatePlan(req, res) {
  const plan = await aiPlanService.generatePlan(req.userId, {
    vitals: req.body.vitals,
  });
  return res.status(201).json({ plan: plan.toJSON() });
}

module.exports = { getTemplates, adoptPlan, getActivePlan, generatePlan };
