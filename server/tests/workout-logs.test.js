'use strict';

// Keep bcrypt cheap (register mints a real user). Must be set before config
// loads transitively via the routes/services.
process.env.BCRYPT_ROUNDS = '4';

const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
const createApp = require('../src/app');
const {
  User,
  Profile,
  WorkoutLog,
  RefreshToken,
} = require('../src/models');

// Integration tests for POST /workout-logs (M6) — the endpoint the session
// engine syncs a finished workout to on completion. A real user is registered
// through the auth endpoints so the access token authenticates through the real
// middleware.

describe('POST /workout-logs', () => {
  const app = createApp();
  let mongod;

  const creds = { email: 'lifter@example.com', password: 'sup3r-secret-pw' };

  const summary = () => ({
    startedAt: '2026-06-27T09:00:00.000Z',
    completedAt: '2026-06-27T09:42:00.000Z',
    durationSeconds: 2520,
    exercises: [
      {
        name: 'Back Squat',
        sets: [
          { reps: 8, weightKg: 60, completed: true },
          { reps: 8, weightKg: 60, completed: true },
        ],
      },
      {
        name: 'Push-up',
        sets: [{ reps: 15, completed: true }],
      },
    ],
  });

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
      Profile.deleteMany({}),
      WorkoutLog.deleteMany({}),
      RefreshToken.deleteMany({}),
    ]);
  });

  async function registerAndToken(email = creds.email) {
    const res = await request(app)
      .post('/auth/register')
      .send({ ...creds, email });
    expect(res.status).toBe(201);
    return { accessToken: res.body.accessToken, userId: res.body.user.id };
  }

  test('requires authentication', async () => {
    const res = await request(app).post('/workout-logs').send(summary());
    expect(res.status).toBe(401);
  });

  test('persists a completed workout for the caller', async () => {
    const { accessToken, userId } = await registerAndToken();

    const res = await request(app)
      .post('/workout-logs')
      .set('Authorization', `Bearer ${accessToken}`)
      .send(summary());

    expect(res.status).toBe(201);
    expect(res.body.log).toBeDefined();
    expect(res.body.log.durationSeconds).toBe(2520);
    expect(res.body.log.exercises).toHaveLength(2);
    expect(res.body.log.exercises[0]).toMatchObject({
      name: 'Back Squat',
      sets: [
        { reps: 8, weightKg: 60, completed: true },
        { reps: 8, weightKg: 60, completed: true },
      ],
    });
    // Bodyweight set: no weight logged.
    expect(res.body.log.exercises[1].sets[0].weightKg).toBeUndefined();

    // Stored against the authenticated user, not anything from the body.
    const stored = await WorkoutLog.findById(res.body.log.id || res.body.log._id);
    expect(stored).not.toBeNull();
    expect(stored.user.toString()).toBe(userId);
  });

  test('owns the log to the caller, ignoring a user field in the body', async () => {
    const { accessToken, userId } = await registerAndToken();
    const other = new mongoose.Types.ObjectId().toString();

    const res = await request(app)
      .post('/workout-logs')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ ...summary(), user: other });

    expect(res.status).toBe(201);
    const stored = await WorkoutLog.findById(res.body.log.id || res.body.log._id);
    expect(stored.user.toString()).toBe(userId);
    expect(stored.user.toString()).not.toBe(other);
  });

  test('accepts a minimal summary (startedAt only)', async () => {
    const { accessToken } = await registerAndToken();

    const res = await request(app)
      .post('/workout-logs')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ startedAt: '2026-06-27T09:00:00.000Z' });

    expect(res.status).toBe(201);
    expect(res.body.log.exercises).toEqual([]);
  });

  test('rejects a missing startedAt', async () => {
    const { accessToken } = await registerAndToken();
    const body = summary();
    delete body.startedAt;

    const res = await request(app)
      .post('/workout-logs')
      .set('Authorization', `Bearer ${accessToken}`)
      .send(body);

    expect(res.status).toBe(400);
    expect(res.body.error.message).toMatch(/startedAt/);
  });

  test('rejects an invalid startedAt', async () => {
    const { accessToken } = await registerAndToken();

    const res = await request(app)
      .post('/workout-logs')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ ...summary(), startedAt: 'not-a-date' });

    expect(res.status).toBe(400);
    expect(res.body.error.message).toMatch(/startedAt/);
  });

  test('rejects an exercise with no name', async () => {
    const { accessToken } = await registerAndToken();

    const res = await request(app)
      .post('/workout-logs')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        startedAt: '2026-06-27T09:00:00.000Z',
        exercises: [{ sets: [{ reps: 5 }] }],
      });

    expect(res.status).toBe(400);
    expect(res.body.error.message).toMatch(/name/);
  });

  test('rejects a negative weight', async () => {
    const { accessToken } = await registerAndToken();

    const res = await request(app)
      .post('/workout-logs')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        startedAt: '2026-06-27T09:00:00.000Z',
        exercises: [{ name: 'Squat', sets: [{ reps: 5, weightKg: -10 }] }],
      });

    expect(res.status).toBe(400);
    expect(res.body.error.message).toMatch(/weightKg/);
  });
});
