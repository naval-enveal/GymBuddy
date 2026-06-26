'use strict';

/**
 * Shared enum vocabularies for the domain models. Centralized so the Profile a
 * user fills out (M3) and the Plans matched to it (M4) speak the same language.
 */

const GOALS = [
  'lose_weight',
  'build_muscle',
  'gain_strength',
  'improve_endurance',
  'general_fitness',
];

const EXPERIENCE_LEVELS = ['beginner', 'intermediate', 'advanced'];

const EQUIPMENT = [
  'none',
  'bodyweight',
  'dumbbells',
  'barbell',
  'kettlebell',
  'resistance_bands',
  'machines',
  'full_gym',
];

const SEXES = ['male', 'female', 'other', 'prefer_not_to_say'];

const SUBSCRIPTION_TIERS = ['free', 'premium'];

const SUBSCRIPTION_STATUSES = [
  'active',
  'in_grace_period',
  'expired',
  'cancelled',
];

const SUBSCRIPTION_PROVIDERS = ['none', 'revenuecat'];

module.exports = {
  GOALS,
  EXPERIENCE_LEVELS,
  EQUIPMENT,
  SEXES,
  SUBSCRIPTION_TIERS,
  SUBSCRIPTION_STATUSES,
  SUBSCRIPTION_PROVIDERS,
};
