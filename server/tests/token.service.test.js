'use strict';

const jwt = require('jsonwebtoken');
const config = require('../src/config/env');
const {
  signAccessToken,
  signRefreshToken,
  verifyAccessToken,
  verifyRefreshToken,
} = require('../src/services/token.service');

// Pure crypto/token tests — no DB required.

describe('token.service', () => {
  const userId = '507f1f77bcf86cd799439011';

  it('signs and verifies an access token carrying the user id', () => {
    const token = signAccessToken(userId);
    const payload = verifyAccessToken(token);
    expect(payload.sub).toBe(userId);
    expect(payload.type).toBe('access');
  });

  it('signs a refresh token with a unique jti each time', () => {
    const a = signRefreshToken(userId);
    const b = signRefreshToken(userId);
    expect(a.jti).toBeDefined();
    expect(a.jti).not.toBe(b.jti);
    const payload = verifyRefreshToken(a.token);
    expect(payload.sub).toBe(userId);
    expect(payload.type).toBe('refresh');
    expect(payload.jti).toBe(a.jti);
  });

  it('rejects an access token presented as a refresh token (and vice versa)', () => {
    const access = signAccessToken(userId);
    const { token: refresh } = signRefreshToken(userId);
    // Distinct secrets mean cross-verification fails outright.
    expect(() => verifyRefreshToken(access)).toThrow();
    expect(() => verifyAccessToken(refresh)).toThrow();
  });

  it('rejects a token signed with the wrong secret', () => {
    const forged = jwt.sign({ type: 'access' }, 'not-the-secret', {
      subject: userId,
      issuer: 'gymbuddy',
    });
    expect(() => verifyAccessToken(forged)).toThrow();
  });

  it('rejects an expired access token', () => {
    const expired = jwt.sign({ type: 'access' }, config.jwt.accessSecret, {
      subject: userId,
      issuer: 'gymbuddy',
      expiresIn: -1,
    });
    expect(() => verifyAccessToken(expired)).toThrow(jwt.TokenExpiredError);
  });

  it('rejects a token whose type claim has been tampered with', () => {
    // Signed with the refresh secret but mislabeled as access.
    const wrongType = jwt.sign({ type: 'access' }, config.jwt.refreshSecret, {
      subject: userId,
      issuer: 'gymbuddy',
    });
    expect(() => verifyRefreshToken(wrongType)).toThrow('invalid token type');
  });
});
