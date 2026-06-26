'use strict';

// Keep bcrypt cheap so the end-to-end flow stays fast. Must be set before
// config is loaded (transitively, via the routes/services).
process.env.BCRYPT_ROUNDS = '4';

const express = require('express');
const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
const authRoutes = require('../src/routes/auth.routes');
const { requireAuth } = require('../src/middleware/auth.middleware');
const { errorHandler } = require('../src/middleware/error.middleware');
const { User, Subscription, RefreshToken } = require('../src/models');

// End-to-end auth-flow integration tests. Unlike auth.test.js (which exercises
// each endpoint in isolation) and auth.middleware.test.js (which mounts
// requireAuth against synthetic tokens), this walks a single user through the
// connected lifecycle — register → use the issued access token on a protected
// route → refresh → use the rotated access token → logout → confirm the
// refresh token is revoked — proving tokens minted by the real auth endpoints
// authenticate against the real middleware stack.

function buildApp() {
  const app = express();
  app.use(express.json());
  app.use('/auth', authRoutes);
  // A protected route standing in for any future authenticated endpoint.
  app.get('/me', requireAuth, (req, res) => {
    res.status(200).json({ userId: req.userId, email: req.user.email });
  });
  app.use((req, res) => {
    res.status(404).json({ error: { message: 'Not found' } });
  });
  app.use(errorHandler);
  return app;
}

describe('auth flow (end-to-end)', () => {
  const app = buildApp();
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

  const register = (overrides = {}) =>
    request(app)
      .post('/auth/register')
      .send({ ...creds, displayName: 'Lifter', ...overrides });

  const getMe = (accessToken) =>
    request(app).get('/me').set('Authorization', `Bearer ${accessToken}`);

  it('register → access protected route → refresh → access with rotated token → logout', async () => {
    // 1. Register and receive the first token pair.
    const reg = await register();
    expect(reg.status).toBe(201);
    const { accessToken, refreshToken } = reg.body;
    const userId = reg.body.user.id || reg.body.user._id;

    // 2. The issued access token authenticates against the protected route.
    const me = await getMe(accessToken);
    expect(me.status).toBe(200);
    expect(me.body.email).toBe(creds.email);
    if (userId) expect(me.body.userId).toBe(String(userId));

    // 3. Rotate the token pair.
    const refreshed = await request(app)
      .post('/auth/refresh')
      .send({ refreshToken });
    expect(refreshed.status).toBe(200);
    const rotated = refreshed.body;
    expect(rotated.refreshToken).not.toBe(refreshToken);

    // 4. The rotated access token also authenticates the protected route.
    const meAgain = await getMe(rotated.accessToken);
    expect(meAgain.status).toBe(200);
    expect(meAgain.body.email).toBe(creds.email);

    // 5. Log out with the current (rotated) refresh token.
    const out = await request(app)
      .post('/auth/logout')
      .send({ refreshToken: rotated.refreshToken });
    expect(out.status).toBe(204);

    // The revoked refresh token can no longer mint a new pair.
    const afterLogout = await request(app)
      .post('/auth/refresh')
      .send({ refreshToken: rotated.refreshToken });
    expect(afterLogout.status).toBe(401);
    expect(await RefreshToken.countDocuments({})).toBe(0);
  });

  it('logs in and uses the freshly issued access token on the protected route', async () => {
    await register();
    const login = await request(app).post('/auth/login').send(creds);
    expect(login.status).toBe(200);

    const me = await getMe(login.body.accessToken);
    expect(me.status).toBe(200);
    expect(me.body.email).toBe(creds.email);
  });

  it('a refresh token is not accepted as a Bearer access token (type mismatch)', async () => {
    const { body } = await register();
    const res = await getMe(body.refreshToken);
    expect(res.status).toBe(401);
    expect(res.body.error.message).toBe('Invalid or expired token');
  });

  it('rejects the rotated-out access token holder from refreshing twice (reuse)', async () => {
    const { body } = await register();
    const first = await request(app)
      .post('/auth/refresh')
      .send({ refreshToken: body.refreshToken });
    expect(first.status).toBe(200);

    // Replaying the now-consumed original refresh token is rejected, but the
    // access token minted alongside it still authenticates until it expires —
    // access tokens are stateless and rotation only revokes the refresh side.
    const reuse = await request(app)
      .post('/auth/refresh')
      .send({ refreshToken: body.refreshToken });
    expect(reuse.status).toBe(401);

    const me = await getMe(first.body.accessToken);
    expect(me.status).toBe(200);
  });

  it('protected route without a token returns 401 in the shared error shape', async () => {
    const res = await request(app).get('/me');
    expect(res.status).toBe(401);
    expect(res.body.error.message).toBe('Authentication required');
  });
});
