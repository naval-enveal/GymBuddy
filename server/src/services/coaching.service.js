'use strict';

const { Profile } = require('../models');
const { ApiError } = require('../middleware/error.middleware');
const { getClient } = require('./claude.client');
const config = require('../config/env');

/**
 * Real-time form coaching (M9). Takes a snapshot of what the on-device pose
 * pipeline saw during a set — the exercise, the form faults the
 * `PoseFormChecker` fired, and how the set is going — and asks Claude for a
 * SHORT, prioritized list of spoken cues. The app then plays them through the
 * glasses via `MetaGlassesSensorSource.playCue`.
 *
 * The Claude call goes through `claude.client` (the single key-holding seam),
 * so this whole service is unit-testable by injecting a fake client — the
 * Claude API key never leaves the server (CLAUDE.md).
 *
 * Vitals/pose live on-device, so the sampled faults arrive in the request body;
 * the caller's Profile (experience + injuries) is read server-side to
 * personalize and keep the wearer safe. Premium gating for this endpoint is a
 * separate M9 task (enforced server-side from the Subscription record) — not
 * wired here yet.
 */

// At most this many spoken cues come back — short and prioritized so the
// glasses never overwhelm the lifter mid-set.
const MAX_CUES = 3;
// One spoken sentence per cue; clamp so a runaway cue can't be pushed to the
// speakers.
const MAX_CUE_LENGTH = 160;
// Cues are tiny; this is ample and keeps latency low for a mid-set round-trip.
const MAX_TOKENS = 400;

// Structured-output schema. The model returns an ordered list (most important
// first); array/length bounds aren't expressible in json_schema, so MAX_CUES /
// MAX_CUE_LENGTH are enforced by `sanitizeCues` below, which also defends
// against malformed output.
const CUES_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  properties: {
    cues: {
      type: 'array',
      items: { type: 'string' },
    },
  },
  required: ['cues'],
};

const SYSTEM_PROMPT = [
  'You are a strength coach speaking to a lifter through smart glasses while',
  'they train. You receive the exercise, the form faults detected from their',
  'body pose during the set, and how the set is going. Reply with a SHORT,',
  'prioritized list of spoken cues — most important first, at most three.',
  'Each cue is ONE short spoken sentence the lifter can act on immediately, in',
  'plain, encouraging language: no jargon, no rep/angle numbers, no medical',
  'advice. Address the most dangerous or form-breaking fault first. If a listed',
  'injury makes the movement risky, cue them to ease off or stop. If form looks',
  'good and there are no faults, return an empty list rather than inventing a',
  'correction.',
].join(' ');

/** Compact a Profile document into the context object handed to the model. */
function profileContext(profile) {
  if (!profile) return {};
  return {
    experience: profile.experience || null,
    injuries: profile.injuries || [],
  };
}

/**
 * Build the user message for the model from the validated request body. The
 * faults are passed through as-is (already cleaned by the validator); an empty
 * fault list is a legitimate "set looked clean" signal.
 */
function buildUserMessage({ exercise, formCues, reps, targetReps, setNumber, profile }) {
  const context = {
    exercise,
    set: {
      number: setNumber !== undefined ? setNumber : null,
      reps: reps !== undefined ? reps : null,
      targetReps: targetReps !== undefined ? targetReps : null,
    },
    formFaults: formCues || [],
    trainee: profileContext(profile),
  };
  return [
    'Coach this set. Return ONLY the spoken cues as JSON matching the provided',
    'schema — no prose.',
    '',
    'SET CONTEXT:',
    JSON.stringify(context, null, 2),
  ].join('\n');
}

/**
 * Coerce raw model output into a safe, short, prioritized cue list. Trims each
 * cue, drops blank entries, clamps cue length, preserves model order (priority)
 * and caps the count — so a malformed-but-parseable response can never push
 * junk or a flood of cues to the glasses. Returns `[]` when there's nothing
 * usable (a clean set), never throws.
 *
 * @param {object} raw  parsed JSON from the model
 * @returns {string[]} ordered spoken cues, most important first
 */
function sanitizeCues(raw) {
  if (!raw || typeof raw !== 'object' || !Array.isArray(raw.cues)) return [];
  const cues = [];
  for (const entry of raw.cues) {
    if (typeof entry !== 'string') continue;
    const trimmed = entry.trim();
    if (trimmed === '') continue;
    cues.push(trimmed.slice(0, MAX_CUE_LENGTH));
    if (cues.length === MAX_CUES) break;
  }
  return cues;
}

/**
 * Generate a short, prioritized list of spoken coaching cues for the caller's
 * current set.
 *
 * @param {string} userId
 * @param {object} input  validated body: `{ exercise, formCues?, reps?,
 *   targetReps?, setNumber? }`
 * @returns {Promise<string[]>} ordered spoken cues (possibly empty)
 * @throws {ApiError} 503 when AI isn't configured, 502 when the model returns
 *   nothing parseable
 */
async function generateCues(userId, input) {
  // Profile is a personalization signal (experience + injuries), not a
  // requirement — coaching still runs for a trainee with no profile.
  const profile = await Profile.findOne({ user: userId }).select(
    'experience injuries'
  );

  const client = getClient();

  const response = await client.messages.create({
    model: config.anthropic.model,
    max_tokens: MAX_TOKENS,
    system: SYSTEM_PROMPT,
    output_config: { format: { type: 'json_schema', schema: CUES_SCHEMA } },
    messages: [
      {
        role: 'user',
        content: buildUserMessage({ ...input, profile }),
      },
    ],
  });

  const block = ((response && response.content) || []).find(
    (b) => b && b.type === 'text'
  );
  if (!block || typeof block.text !== 'string') {
    throw new ApiError(502, 'AI returned no cues');
  }

  let parsed;
  try {
    parsed = JSON.parse(block.text);
  } catch (err) {
    throw new ApiError(502, 'AI returned invalid cues');
  }

  return sanitizeCues(parsed);
}

module.exports = {
  generateCues,
  // exported for unit tests
  sanitizeCues,
  buildUserMessage,
  CUES_SCHEMA,
};
