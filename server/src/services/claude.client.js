'use strict';

const config = require('../config/env');
const { ApiError } = require('../middleware/error.middleware');

/**
 * The single seam over the Anthropic SDK (M9). All Claude calls go through the
 * client returned here so the API key lives in exactly one place (server env)
 * and AI features can be unit-tested without the network.
 *
 * The key is SERVER-SIDE ONLY (CLAUDE.md): it's read from `config.anthropic`
 * (which reads env) and never leaves the server. When unset, `getClient()`
 * throws a 503 so callers degrade gracefully instead of returning a 500.
 */

let client = null;

/**
 * Override the Anthropic client. Used by tests to inject a fake (no network),
 * and available as a composition seam. Pass `null` to reset to the lazy default.
 *
 * @param {object|null} instance  an object exposing `messages.create(...)`
 */
function setClient(instance) {
  client = instance;
}

/**
 * Return the Anthropic client, constructing it lazily from the server-side API
 * key on first use. The SDK is `require`d lazily so it isn't loaded unless real
 * AI is exercised (tests inject a fake via `setClient`).
 *
 * @returns {object} an Anthropic client (`messages.create`)
 * @throws {ApiError} 503 when no API key is configured and none was injected
 */
function getClient() {
  if (client) return client;
  if (!config.anthropic.apiKey) {
    throw new ApiError(503, 'AI features are not configured');
  }
  // eslint-disable-next-line global-require
  const Anthropic = require('@anthropic-ai/sdk');
  client = new Anthropic({ apiKey: config.anthropic.apiKey });
  return client;
}

module.exports = { getClient, setClient };
