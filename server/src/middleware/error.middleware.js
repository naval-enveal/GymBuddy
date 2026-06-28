'use strict';

/**
 * Operational error carrying an HTTP status and a client-safe message. Anything
 * thrown from a handler or middleware as an `ApiError` is rendered verbatim by
 * `errorHandler`; the auth service's `AuthError` is treated the same way since
 * it also exposes a `statusCode`.
 */
class ApiError extends Error {
  constructor(statusCode, message) {
    super(message);
    this.name = 'ApiError';
    this.statusCode = statusCode;
  }
}

/**
 * Wrap an async route handler so a rejected promise is forwarded to
 * `next(err)` (and thus to `errorHandler`) instead of crashing the request.
 * Lets controllers stay flat — no per-handler try/catch.
 */
function asyncHandler(fn) {
  return (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
}

/**
 * Central error handler — the single owner of the shared
 * `{ error: { message } }` response shape. Mounted last in `app.js`. Known
 * error types are mapped to a safe status + message; anything unexpected
 * becomes a 500 with a generic message (and is logged) so internals never leak
 * to the client.
 */
// eslint-disable-next-line no-unused-vars
function errorHandler(err, req, res, next) {
  // Malformed JSON body — thrown by express.json()/body-parser.
  if (err && err.type === 'entity.parse.failed') {
    return res.status(400).json({ error: { message: 'Invalid JSON in request body' } });
  }

  // Duplicate-key race on a unique index (e.g. two registers at once). The only
  // unique index in play here is the user email.
  if (err && err.code === 11000) {
    return res.status(409).json({ error: { message: 'Email already registered' } });
  }

  // Mongoose schema validation reaching the edge (defense in depth; requests
  // are validated before they hit a model).
  if (err && err.name === 'ValidationError') {
    return res.status(400).json({ error: { message: 'Invalid request' } });
  }

  // Deliberately-thrown operational errors carry a curated, client-safe
  // message and status, so they're rendered verbatim — including 5xx (e.g. a
  // 502/503 from an upstream Claude API call), which the client should see
  // rather than an opaque 500. ApiError is always safe; AuthError (and other
  // 4xx carriers) are rendered for their client-facing 4xx range only.
  if (err instanceof ApiError) {
    return res.status(err.statusCode).json({ error: { message: err.message } });
  }
  if (err && Number.isInteger(err.statusCode) && err.statusCode >= 400 && err.statusCode < 500) {
    return res.status(err.statusCode).json({ error: { message: err.message } });
  }

  // Unexpected — log server-side, return an opaque 500.
  console.error(err);
  return res.status(500).json({ error: { message: 'Internal server error' } });
}

module.exports = { ApiError, asyncHandler, errorHandler };
