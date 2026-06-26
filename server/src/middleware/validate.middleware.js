'use strict';

const { ApiError } = require('./error.middleware');

// Same shape the User model enforces; validating here rejects bad input at the
// edge with a clear message before it ever reaches Mongoose.
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

/**
 * Build a middleware that validates and lightly sanitizes `req.body` against a
 * field schema. On the first violation it forwards a 400 `ApiError` to the
 * shared error handler. On success it replaces `req.body` with an object
 * containing ONLY the declared fields (coerced) — unknown keys are dropped, so
 * a client can't smuggle extra properties into a downstream `create`.
 *
 * Field rules: `{ type: 'email' | 'string', required, minLength, maxLength,
 * trim }`. `type: 'email'` always trims + lowercases; other strings trim only
 * when `trim: true` (passwords/tokens are left byte-for-byte intact).
 */
function validate(schema) {
  return (req, res, next) => {
    const body = req.body;
    if (typeof body !== 'object' || body === null || Array.isArray(body)) {
      return next(new ApiError(400, 'Request body must be a JSON object'));
    }

    const clean = {};
    for (const [field, rules] of Object.entries(schema)) {
      let value = body[field];

      if (value === undefined || value === null || value === '') {
        if (rules.required) {
          return next(new ApiError(400, `${field} is required`));
        }
        continue; // optional and absent — nothing to validate
      }

      if (typeof value !== 'string') {
        return next(new ApiError(400, `${field} must be a string`));
      }

      const isEmail = rules.type === 'email';
      if (isEmail || rules.trim) value = value.trim();
      if (isEmail) value = value.toLowerCase();

      if (value === '') {
        // Became empty after trimming (e.g. whitespace-only).
        if (rules.required) {
          return next(new ApiError(400, `${field} is required`));
        }
        continue;
      }

      if (isEmail && !EMAIL_RE.test(value)) {
        return next(new ApiError(400, 'email must be a valid email address'));
      }
      if (rules.minLength && value.length < rules.minLength) {
        return next(
          new ApiError(400, `${field} must be at least ${rules.minLength} characters`)
        );
      }
      if (rules.maxLength && value.length > rules.maxLength) {
        return next(
          new ApiError(400, `${field} must be at most ${rules.maxLength} characters`)
        );
      }

      clean[field] = value;
    }

    req.body = clean;
    return next();
  };
}

module.exports = { validate };
