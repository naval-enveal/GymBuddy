'use strict';

// Keep bcrypt cheap so the flow tests stay fast. Must be set before config is
// loaded (transitively, via app).
process.env.BCRYPT_ROUNDS = '4';

const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
const createApp = require('../src/app');
const { User, Subscription, RefreshToken } = require('../src/models');

// Full auth-flow integration tests against an in-memory MongoDB.

describe('auth endpoints', () => {
  const app = createApp();
  let mongod;

  const creds = { email: 'lifter@example.com', password: 'sup3r-secret-pw' };

  beforeAll(async () => {
    mongod = await MongoMemoryServer.create();
    await mongoose.connect(mongod.getUri());
  }, 60000);

  afterAll(async () => {
    await mongoose.disconnect();
    if (mongod) await mongod.stop();
  });

  afterEach(async () => {
    await Promise.all([
      User.deleteMany({}),
      Subscription.deleteMany({}),
      RefreshToken.deleteMany({}),
    ]);
  });

  async function registerUser(overrides = {}) {
    return request(app)
      .post('/auth/register')
      .send({ ...creds, displayName: 'Lifter', ...overrides });
  }

  describe('POST /auth/register', () => {
    it('creates a user + free subscription, returns tokens, never the hash', async () => {
      const res = await registerUser();

      expect(res.status).toBe(201);
      expect(res.body.user.email).toBe(creds.email);
      expect(res.body.user.passwordHash).toBeUndefined();
      expect(typeof res.body.accessToken).toBe('string');
      expect(typeof res.body.refreshToken).toBe('string');

      const stored = await User.findOne({ email: creds.email }).select(
        '+passwordHash'
      );
      expect(stored.passwordHash).toBeDefined();
      expect(stored.passwordHash).not.toBe(creds.password); // hashed, not plain

      const sub = await Subscription.findOne({ user: stored._id });
      expect(sub).not.toBeNull();
      expect(sub.tier).toBe('free');

      // The refresh token was tracked server-side for later revocation.
      expect(await RefreshToken.countDocuments({ user: stored._id })).toBe(1);
    });

    it('rejects a duplicate email with 409 and the shared error shape', async () => {
      await registerUser();
      const res = await registerUser();
      expect(res.status).toBe(409);
      expect(res.body.error.message).toMatch(/already registered/i);
    });

    it('rejects missing fields with 400', async () => {
      const res = await request(app)
        .post('/auth/register')
        .send({ email: creds.email });
      expect(res.status).toBe(400);
      expect(res.body.error.message).toBeDefined();
    });
  });

  describe('POST /auth/login', () => {
    beforeEach(async () => {
      await registerUser();
    });

    it('returns tokens for valid credentials', async () => {
      const res = await request(app).post('/auth/login').send(creds);
      expect(res.status).toBe(200);
      expect(typeof res.body.accessToken).toBe('string');
      expect(typeof res.body.refreshToken).toBe('string');
      expect(res.body.user.passwordHash).toBeUndefined();
    });

    it('rejects a wrong password with 401 and a non-enumerating message', async () => {
      const res = await request(app)
        .post('/auth/login')
        .send({ email: creds.email, password: 'wrong' });
      expect(res.status).toBe(401);
      expect(res.body.error.message).toBe('Invalid email or password');
    });

    it('rejects an unknown email with the same 401 message', async () => {
      const res = await request(app)
        .post('/auth/login')
        .send({ email: 'nobody@example.com', password: creds.password });
      expect(res.status).toBe(401);
      expect(res.body.error.message).toBe('Invalid email or password');
    });
  });

  describe('POST /auth/refresh', () => {
    it('rotates the refresh token and rejects reuse of the old one', async () => {
      const { body } = await registerUser();
      const oldRefresh = body.refreshToken;

      const res = await request(app)
        .post('/auth/refresh')
        .send({ refreshToken: oldRefresh });
      expect(res.status).toBe(200);
      expect(res.body.accessToken).toBeDefined();
      expect(res.body.refreshToken).toBeDefined();
      expect(res.body.refreshToken).not.toBe(oldRefresh);

      // The rotated-out token must no longer be accepted.
      const reuse = await request(app)
        .post('/auth/refresh')
        .send({ refreshToken: oldRefresh });
      expect(reuse.status).toBe(401);

      // The new one still works.
      const again = await request(app)
        .post('/auth/refresh')
        .send({ refreshToken: res.body.refreshToken });
      expect(again.status).toBe(200);
    });

    it('rejects a garbage token with 401', async () => {
      const res = await request(app)
        .post('/auth/refresh')
        .send({ refreshToken: 'not.a.jwt' });
      expect(res.status).toBe(401);
    });

    it('rejects a missing token with 400', async () => {
      const res = await request(app).post('/auth/refresh').send({});
      expect(res.status).toBe(400);
    });
  });

  describe('POST /auth/logout', () => {
    it('revokes the refresh token so it can no longer be refreshed', async () => {
      const { body } = await registerUser();
      const { refreshToken } = body;

      const out = await request(app)
        .post('/auth/logout')
        .send({ refreshToken });
      expect(out.status).toBe(204);
      expect(await RefreshToken.countDocuments({})).toBe(0);

      const res = await request(app)
        .post('/auth/refresh')
        .send({ refreshToken });
      expect(res.status).toBe(401);
    });

    it('is idempotent — logging out an already-revoked token still 204s', async () => {
      const { body } = await registerUser();
      const { refreshToken } = body;
      await request(app).post('/auth/logout').send({ refreshToken });
      const second = await request(app)
        .post('/auth/logout')
        .send({ refreshToken });
      expect(second.status).toBe(204);
    });
  });
});
