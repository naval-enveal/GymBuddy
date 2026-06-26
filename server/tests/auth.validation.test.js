'use strict';

const request = require('supertest');
const createApp = require('../src/app');

// Validation runs at the edge, before any service/DB access — so these cases
// reject without a live MongoDB. Every response must use the shared
// { error: { message } } shape with a 400.

describe('auth request validation', () => {
  const app = createApp();

  function expectBadRequest(res, messageMatch) {
    expect(res.status).toBe(400);
    expect(res.body.error).toBeDefined();
    expect(typeof res.body.error.message).toBe('string');
    if (messageMatch) expect(res.body.error.message).toMatch(messageMatch);
  }

  describe('POST /auth/register', () => {
    const valid = { email: 'lifter@example.com', password: 'sup3r-secret-pw' };

    it('rejects a missing email', async () => {
      const res = await request(app)
        .post('/auth/register')
        .send({ password: valid.password });
      expectBadRequest(res, /email is required/i);
    });

    it('rejects a malformed email', async () => {
      const res = await request(app)
        .post('/auth/register')
        .send({ ...valid, email: 'not-an-email' });
      expectBadRequest(res, /valid email/i);
    });

    it('rejects a missing password', async () => {
      const res = await request(app)
        .post('/auth/register')
        .send({ email: valid.email });
      expectBadRequest(res, /password is required/i);
    });

    it('rejects a too-short password', async () => {
      const res = await request(app)
        .post('/auth/register')
        .send({ ...valid, password: 'short' });
      expectBadRequest(res, /at least 8 characters/i);
    });

    it('rejects an over-long password', async () => {
      const res = await request(app)
        .post('/auth/register')
        .send({ ...valid, password: 'a'.repeat(201) });
      expectBadRequest(res, /at most 200 characters/i);
    });

    it('rejects an over-long displayName', async () => {
      const res = await request(app)
        .post('/auth/register')
        .send({ ...valid, displayName: 'x'.repeat(81) });
      expectBadRequest(res, /displayName/i);
    });

    it('rejects a non-string password', async () => {
      const res = await request(app)
        .post('/auth/register')
        .send({ email: valid.email, password: 12345678 });
      expectBadRequest(res, /password must be a string/i);
    });
  });

  describe('POST /auth/login', () => {
    it('rejects a missing password', async () => {
      const res = await request(app)
        .post('/auth/login')
        .send({ email: 'lifter@example.com' });
      expectBadRequest(res, /password is required/i);
    });

    it('rejects a malformed email', async () => {
      const res = await request(app)
        .post('/auth/login')
        .send({ email: 'bad', password: 'whatever' });
      expectBadRequest(res, /valid email/i);
    });
  });

  describe('POST /auth/refresh & /auth/logout', () => {
    it('rejects a missing refreshToken on refresh', async () => {
      const res = await request(app).post('/auth/refresh').send({});
      expectBadRequest(res, /refreshToken is required/i);
    });

    it('rejects a missing refreshToken on logout', async () => {
      const res = await request(app).post('/auth/logout').send({});
      expectBadRequest(res, /refreshToken is required/i);
    });
  });

  describe('malformed bodies', () => {
    it('rejects invalid JSON with the shared shape', async () => {
      const res = await request(app)
        .post('/auth/register')
        .set('Content-Type', 'application/json')
        .send('{ not valid json ');
      expectBadRequest(res, /invalid json/i);
    });

    it('rejects a non-object (array) body', async () => {
      const res = await request(app)
        .post('/auth/register')
        .set('Content-Type', 'application/json')
        .send('[1,2,3]');
      expectBadRequest(res, /must be a json object/i);
    });
  });
});
