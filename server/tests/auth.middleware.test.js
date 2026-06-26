'use strict';

// Keep bcrypt cheap; must be set before config loads (via the services).
process.env.BCRYPT_ROUNDS = '4';

const express = require('express');
const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
const { requireAuth } = require('../src/middleware/auth.middleware');
const {
  signAccessToken,
  signRefreshToken,
} = require('../src/services/token.service');
const { User } = require('../src/models');

// Integration tests for the auth middleware. A tiny app mounts requireAuth in
// front of a protected route that echoes the authenticated user back.

function buildApp() {
  const app = express();
  app.use(express.json());
  app.get('/protected', requireAuth, (req, res) => {
    res.status(200).json({ userId: req.userId, email: req.user.email });
  });
  return app;
}

describe('requireAuth middleware', () => {
  const app = buildApp();
  let mongod;
  let user;

  beforeAll(async () => {
    mongod = await MongoMemoryServer.create();
    await mongoose.connect(mongod.getUri());
  }, 60000);

  afterAll(async () => {
    await mongoose.disconnect();
    if (mongod) await mongod.stop();
  });

  beforeEach(async () => {
    user = await User.create({
      email: 'lifter@example.com',
      passwordHash: 'unused-here',
    });
  });

  afterEach(async () => {
    await User.deleteMany({});
  });

  it('allows a request bearing a valid access token and loads the user', async () => {
    const token = signAccessToken(user._id);
    const res = await request(app)
      .get('/protected')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.userId).toBe(String(user._id));
    expect(res.body.email).toBe(user.email);
  });

  it('rejects a request with no Authorization header (401, shared shape)', async () => {
    const res = await request(app).get('/protected');
    expect(res.status).toBe(401);
    expect(res.body.error.message).toBe('Authentication required');
  });

  it('rejects a non-Bearer scheme with 401', async () => {
    const token = signAccessToken(user._id);
    const res = await request(app)
      .get('/protected')
      .set('Authorization', `Basic ${token}`);
    expect(res.status).toBe(401);
    expect(res.body.error.message).toBeDefined();
  });

  it('rejects a malformed token with 401', async () => {
    const res = await request(app)
      .get('/protected')
      .set('Authorization', 'Bearer not.a.jwt');
    expect(res.status).toBe(401);
    expect(res.body.error.message).toBe('Invalid or expired token');
  });

  it('rejects an expired access token with 401', async () => {
    const jwt = require('jsonwebtoken');
    const config = require('../src/config/env');
    const expired = jwt.sign({ type: 'access' }, config.jwt.accessSecret, {
      subject: String(user._id),
      issuer: 'gymbuddy',
      expiresIn: '-1s',
    });
    const res = await request(app)
      .get('/protected')
      .set('Authorization', `Bearer ${expired}`);
    expect(res.status).toBe(401);
    expect(res.body.error.message).toBe('Invalid or expired token');
  });

  it('rejects a refresh token presented as an access token (type mismatch)', async () => {
    const { token } = signRefreshToken(user._id);
    const res = await request(app)
      .get('/protected')
      .set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(401);
  });

  it('rejects a valid token whose user no longer exists', async () => {
    const token = signAccessToken(user._id);
    await User.deleteMany({});
    const res = await request(app)
      .get('/protected')
      .set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(401);
    expect(res.body.error.message).toBe('Invalid or expired token');
  });
});
