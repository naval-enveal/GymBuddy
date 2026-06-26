'use strict';

/**
 * Request-body schemas for the auth endpoints, consumed by the generic
 * `validate` middleware. Login intentionally only requires a non-empty
 * password (no length rule) so a too-short attempt still reaches the service
 * and returns the same non-enumerating 401 as a wrong password — strength is
 * enforced at registration, not at login.
 */

// Bounds the bcrypt input; bcryptjs truncates beyond 72 bytes, so an
// unbounded password is pointless and a cheap DoS vector.
const MAX_PASSWORD_LENGTH = 200;

const register = {
  email: { type: 'email', required: true },
  password: { type: 'string', required: true, minLength: 8, maxLength: MAX_PASSWORD_LENGTH },
  displayName: { type: 'string', required: false, trim: true, maxLength: 80 },
};

const login = {
  email: { type: 'email', required: true },
  password: { type: 'string', required: true, maxLength: MAX_PASSWORD_LENGTH },
};

const refresh = {
  refreshToken: { type: 'string', required: true },
};

const logout = {
  refreshToken: { type: 'string', required: true },
};

module.exports = { register, login, refresh, logout };
