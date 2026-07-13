'use strict';

const config = require('../config/env');
const { ApiError } = require('../middleware/error.middleware');

/**
 * The single seam over the Gemini SDK (M9; swapped from Anthropic for the POC —
 * Gemini's free tier removes per-call cost while the product is validated).
 * Exposes the same `messages.create({model, max_tokens, system, output_config,
 * messages})` shape the services were originally built against (returning
 * `{ content: [{ type: 'text', text }] }`), so ai-plan/coaching needed no
 * business-logic changes — only this seam translates to the Gemini SDK.
 *
 * The key is SERVER-SIDE ONLY (CLAUDE.md): it's read from `config.gemini`
 * (which reads env) and never leaves the server. When unset, `getClient()`
 * throws a 503 so callers degrade gracefully instead of returning a 500.
 */

let client = null;

/**
 * Override the AI client. Used by tests to inject a fake (no network), and
 * available as a composition seam. Pass `null` to reset to the lazy default.
 *
 * @param {object|null} instance  an object exposing `messages.create(...)`
 */
function setClient(instance) {
  client = instance;
}

// Gemini's structured-output schema is a constrained OpenAPI subset —
// uppercase type enums and a `nullable` flag instead of a `type: [T, 'null']`
// union — so the plain JSON Schema the services already define
// (PLAN_SCHEMA/CUES_SCHEMA) is converted once per call rather than
// hand-maintaining a second, Gemini-shaped copy of each schema.
const TYPE_MAP = {
  object: 'OBJECT',
  array: 'ARRAY',
  string: 'STRING',
  integer: 'INTEGER',
  number: 'NUMBER',
  boolean: 'BOOLEAN',
};

function toGeminiSchema(schema) {
  if (!schema || typeof schema !== 'object') return schema;

  const rawType = schema.type;
  const nullable = Array.isArray(rawType) && rawType.includes('null');
  const baseType = Array.isArray(rawType) ? rawType.find((t) => t !== 'null') : rawType;

  const out = {};
  if (baseType) out.type = TYPE_MAP[baseType] || baseType;
  if (nullable) out.nullable = true;
  if (schema.enum) out.enum = schema.enum;
  if (schema.properties) {
    out.properties = Object.fromEntries(
      Object.entries(schema.properties).map(([key, value]) => [
        key,
        toGeminiSchema(value),
      ])
    );
  }
  if (schema.items) out.items = toGeminiSchema(schema.items);
  if (schema.required) out.required = schema.required;
  return out;
}

/**
 * Build the real Gemini-backed client, adapting `ai.models.generateContent`
 * to the `messages.create(...)` shape callers use.
 *
 * @param {string} apiKey
 * @returns {object} a client exposing `messages.create(...)`
 */
function buildClient(apiKey) {
  // eslint-disable-next-line global-require
  const { GoogleGenAI } = require('@google/genai');
  const genAI = new GoogleGenAI({ apiKey });

  return {
    messages: {
      async create({ model, max_tokens: maxOutputTokens, system, output_config: outputConfig, messages }) {
        const response = await genAI.models.generateContent({
          model,
          contents: messages[0].content,
          config: {
            systemInstruction: system,
            maxOutputTokens,
            responseMimeType: 'application/json',
            responseSchema: toGeminiSchema(outputConfig.format.schema),
            // Newer Gemini models spend part of maxOutputTokens on an internal
            // "thinking" pass before the visible answer — for these short,
            // low-latency structured responses (a plan or a few coaching cues)
            // that reasoning budget isn't needed and only risks truncating the
            // real output, so it's disabled.
            thinkingConfig: { thinkingBudget: 0 },
          },
        });
        return { content: [{ type: 'text', text: response.text }] };
      },
    },
  };
}

/**
 * Return the AI client, constructing it lazily from the server-side API key
 * on first use. The SDK is `require`d lazily so it isn't loaded unless real
 * AI is exercised (tests inject a fake via `setClient`).
 *
 * @returns {object} a client exposing `messages.create(...)`
 * @throws {ApiError} 503 when no API key is configured and none was injected
 */
function getClient() {
  if (client) return client;
  if (!config.gemini.apiKey) {
    throw new ApiError(503, 'AI features are not configured');
  }
  client = buildClient(config.gemini.apiKey);
  return client;
}

module.exports = { getClient, setClient };
