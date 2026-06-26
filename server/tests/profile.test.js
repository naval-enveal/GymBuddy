'use strict';

// Keep bcrypt cheap (register mints a real user). Must be set before config
// loads transitively via the routes/services.
process.env.BCRYPT_ROUNDS = '4';

const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
const createApp = require('../src/app');
const { User, Profile, Subscription, RefreshToken } = require('../src/models');

// Integration tests for the Profile API (PUT/GET /profile), the persistence
// layer behind the M3 onboarding flow. A real user is registered through the
// auth endpoints so the access token authenticates through the real middleware,
// then the onboarding answers are upserted and read back.

describe('profile API', () => {
  const app = createApp();
  let mongod;

  const creds = { email: 'lifter@example.com', password: 'sup3r-secret-pw' };

  const fullDraft = {
    goals: ['build_muscle', 'gain_strength'],
    experience: 'intermediate',
    daysPerWeek: 4,
    equipment: ['dumbbells', 'barbell'],
    injuries: ['lower back', 'left knee'],
    bodyStats: { heightCm: 180, weightKg: 78, age: 30, sex: 'male' },
    onboardingComplete: true,
  };

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
      Subscription.deleteMany({}),
      RefreshToken.deleteMany({}),
    ]);
  });

  async function registerAndToken() {
    const res = await request(app).post('/auth/register').send(creds);
    expect(res.status).toBe(201);
    return { accessToken: res.body.accessToken, userId: res.body.user.id };
  }

  test('GET /profile requires authentication', async () => {
    const res = await request(app).get('/profile');
    expect(res.status).toBe(401);
    expect(res.body.error.message).toBeDefined();
  });

  test('PUT /profile requires authentication', async () => {
    const res = await request(app).put('/profile').send(fullDraft);
    expect(res.status).toBe(401);
  });

  test('GET /profile returns null before onboarding', async () => {
    const { accessToken } = await registerAndToken();
    const res = await request(app)
      .get('/profile')
      .set('Authorization', `Bearer ${accessToken}`);
    expect(res.status).toBe(200);
    expect(res.body.profile).toBeNull();
  });

  test('PUT /profile upserts the full draft and GET reads it back', async () => {
    const { accessToken, userId } = await registerAndToken();

    const put = await request(app)
      .put('/profile')
      .set('Authorization', `Bearer ${accessToken}`)
      .send(fullDraft);

    expect(put.status).toBe(200);
    expect(put.body.profile.goals).toEqual(['build_muscle', 'gain_strength']);
    expect(put.body.profile.experience).toBe('intermediate');
    expect(put.body.profile.daysPerWeek).toBe(4);
    expect(put.body.profile.equipment).toEqual(['dumbbells', 'barbell']);
    expect(put.body.profile.injuries).toEqual(['lower back', 'left knee']);
    expect(put.body.profile.bodyStats).toMatchObject({
      heightCm: 180,
      weightKg: 78,
      age: 30,
      sex: 'male',
    });
    expect(put.body.profile.onboardingComplete).toBe(true);
    expect(put.body.profile.user).toBe(userId);

    // Exactly one profile exists for the user (upsert, not duplicate insert).
    expect(await Profile.countDocuments({ user: userId })).toBe(1);

    const get = await request(app)
      .get('/profile')
      .set('Authorization', `Bearer ${accessToken}`);
    expect(get.status).toBe(200);
    expect(get.body.profile.experience).toBe('intermediate');
    expect(get.body.profile.onboardingComplete).toBe(true);
  });

  test('PUT /profile is idempotent — a second save updates, not duplicates', async () => {
    const { accessToken, userId } = await registerAndToken();

    await request(app)
      .put('/profile')
      .set('Authorization', `Bearer ${accessToken}`)
      .send(fullDraft);

    const second = await request(app)
      .put('/profile')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ ...fullDraft, daysPerWeek: 2, goals: ['lose_weight'] });

    expect(second.status).toBe(200);
    expect(second.body.profile.daysPerWeek).toBe(2);
    expect(second.body.profile.goals).toEqual(['lose_weight']);
    expect(await Profile.countDocuments({ user: userId })).toBe(1);
  });

  test('PUT /profile drops unknown fields and keeps no health-permission data', async () => {
    const { accessToken } = await registerAndToken();
    const res = await request(app)
      .put('/profile')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        goals: ['general_fitness'],
        healthPermission: 'granted', // device-level, never persisted
        isPremium: true, // a client must not smuggle entitlement in
      });

    expect(res.status).toBe(200);
    expect(res.body.profile.healthPermission).toBeUndefined();
    expect(res.body.profile.isPremium).toBeUndefined();
    expect(res.body.profile.goals).toEqual(['general_fitness']);
  });

  test('PUT /profile rejects an invalid goal', async () => {
    const { accessToken } = await registerAndToken();
    const res = await request(app)
      .put('/profile')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ goals: ['become_a_wizard'] });
    expect(res.status).toBe(400);
    expect(res.body.error.message).toMatch(/goals/);
  });

  test('PUT /profile rejects an out-of-range daysPerWeek', async () => {
    const { accessToken } = await registerAndToken();
    const res = await request(app)
      .put('/profile')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ daysPerWeek: 9 });
    expect(res.status).toBe(400);
    expect(res.body.error.message).toMatch(/daysPerWeek/);
  });

  test('PUT /profile rejects an out-of-range body stat', async () => {
    const { accessToken } = await registerAndToken();
    const res = await request(app)
      .put('/profile')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ bodyStats: { age: 5 } });
    expect(res.status).toBe(400);
    expect(res.body.error.message).toMatch(/age/);
  });

  test('PUT /profile accepts a partial draft (every field optional)', async () => {
    const { accessToken } = await registerAndToken();
    const res = await request(app)
      .put('/profile')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ goals: ['improve_endurance'] });
    expect(res.status).toBe(200);
    expect(res.body.profile.goals).toEqual(['improve_endurance']);
    expect(res.body.profile.onboardingComplete).toBe(false); // schema default
  });

  test("one user's profile is isolated from another's", async () => {
    const first = await registerAndToken();
    await request(app)
      .put('/profile')
      .set('Authorization', `Bearer ${first.accessToken}`)
      .send(fullDraft);

    const secondReg = await request(app)
      .post('/auth/register')
      .send({ email: 'other@example.com', password: 'another-secret-pw' });
    const secondToken = secondReg.body.accessToken;

    const res = await request(app)
      .get('/profile')
      .set('Authorization', `Bearer ${secondToken}`);
    expect(res.status).toBe(200);
    expect(res.body.profile).toBeNull();
  });
});
