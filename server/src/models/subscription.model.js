'use strict';

const mongoose = require('mongoose');
const {
  SUBSCRIPTION_TIERS,
  SUBSCRIPTION_STATUSES,
  SUBSCRIPTION_PROVIDERS,
} = require('./constants');

/**
 * The source of truth for a user's premium entitlement. Premium gating is
 * enforced server-side from this record (never trusted from the client). It is
 * reconciled from RevenueCat webhooks/receipts (M9); the client only reads the
 * resulting entitlement.
 */
const subscriptionSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      unique: true,
      index: true,
    },
    tier: {
      type: String,
      enum: SUBSCRIPTION_TIERS,
      default: 'free',
    },
    status: {
      type: String,
      enum: SUBSCRIPTION_STATUSES,
      default: 'active',
    },
    provider: {
      type: String,
      enum: SUBSCRIPTION_PROVIDERS,
      default: 'none',
    },
    // Provider-side identifiers, for reconciliation.
    productId: { type: String, trim: true },
    providerCustomerId: { type: String, trim: true },
    // Null for non-expiring tiers (e.g. free).
    expiresAt: { type: Date, default: null },
  },
  { timestamps: true }
);

/**
 * Whether the user is currently entitled to premium features. This is the
 * single check premium-gated endpoints should call — it accounts for tier,
 * status, and expiry together. `now` is injectable for deterministic tests.
 *
 * @param {Date} [now]
 * @returns {boolean}
 */
subscriptionSchema.methods.isPremiumActive = function isPremiumActive(now) {
  const at = now || new Date();
  if (this.tier !== 'premium') return false;
  if (this.status === 'expired' || this.status === 'cancelled') return false;
  if (this.expiresAt && this.expiresAt.getTime() <= at.getTime()) return false;
  return true;
};

module.exports =
  mongoose.models.Subscription ||
  mongoose.model('Subscription', subscriptionSchema);
