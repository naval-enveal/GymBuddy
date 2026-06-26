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
  Plan,
  Workout,
  Subscription,
  RefreshToken,
} = require('../src/models');
const { seedTemplates } = require('../src/services/seed.service');
const TEMPLATES = require('../src/seeds/templates');

// Integration tests for GET /plans/templates (M4) — the endpoint that ranks the
// seeded template library against the caller's onboarding Profile. A real user
// is registered through the auth endpoints so the access token authenticates
// through the real middleware, and the real seed populates the library.

describe('GET /plans/templates', () => {
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
      Profile.deleteMany({}),
      Plan.deleteMany({}),
      Workout.deleteMany({}),
      Subscription.deleteMany({}),
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

  async function setProfile(accessToken, profile) {
    const res = await request(app)
      .put('/profile')
      .set('Authorization', `Bearer ${accessToken}`)
      .send(profile);
    expect(res.status).toBe(200);
  }

  function get(accessToken) {
    return request(app)
      .get('/plans/templates')
      .set('Authorization', `Bearer ${accessToken}`);
  }

  test('requires authentication', async () => {
    const res = await request(app).get('/plans/templates');
    expect(res.status).toBe(401);
    expect(res.body.error.message).toBeDefined();
  });

  test('returns the full template library with populated workouts', async () => {
    await seedTemplates();
    const { accessToken } = await registerAndToken();

    const res = await get(accessToken);

    expect(res.status).toBe(200);
    expect(res.body.templates).toHaveLength(TEMPLATES.length);
    for (const tpl of res.body.templates) {
      expect(tpl.isTemplate).toBe(true);
      expect(tpl.owner).toBeNull();
      expect(typeof tpl.matchScore).toBe('number');
      // workouts are populated docs, not dangling ids
      expect(tpl.workouts.length).toBeGreaterThan(0);
      for (const w of tpl.workouts) {
        expect(typeof w).toBe('object');
        expect(w.name).toEqual(expect.any(String));
        expect(w.exercises.length).toBeGreaterThan(0);
      }
    }
  });

  test('without a profile, returns every template in name order with score 0', async () => {
    await seedTemplates();
    const { accessToken } = await registerAndToken();

    const res = await get(accessToken);

    const names = res.body.templates.map((t) => t.name);
    expect(names).toEqual([...names].sort((a, b) => a.localeCompare(b)));
    for (const tpl of res.body.templates) {
      expect(tpl.matchScore).toBe(0);
    }
  });

  test('ranks a goal-matched template first', async () => {
    await seedTemplates();
    const { accessToken } = await registerAndToken();
    // 'lose_weight' is served only by the "Lean Burn Circuit" template.
    await setProfile(accessToken, {
      goals: ['lose_weight'],
      experience: 'beginner',
      daysPerWeek: 4,
      equipment: ['dumbbells', 'bodyweight'],
    });

    const res = await get(accessToken);

    expect(res.status).toBe(200);
    expect(res.body.templates[0].name).toBe('Lean Burn Circuit');
    expect(res.body.templates[0].goal).toBe('lose_weight');
    // The top result outscores the rest.
    expect(res.body.templates[0].matchScore).toBeGreaterThan(
      res.body.templates[1].matchScore
    );
  });

  test('penalizes templates needing equipment the user lacks', async () => {
    await seedTemplates();
    const { accessToken } = await registerAndToken();
    // Bodyweight-only trainee: full_gym / barbell plans are not runnable.
    await setProfile(accessToken, {
      goals: ['general_fitness'],
      experience: 'beginner',
      daysPerWeek: 3,
      equipment: ['bodyweight'],
    });

    const res = await get(accessToken);
    const byName = Object.fromEntries(
      res.body.templates.map((t) => [t.name, t.matchScore])
    );

    // A bodyweight plan must outrank the full-gym split for this user.
    expect(byName['Full Body Foundations']).toBeGreaterThan(
      byName['Push Pull Legs Hypertrophy']
    );
    // The fully-runnable, goal-matched bodyweight plan tops the list.
    expect(res.body.templates[0].name).toBe('Full Body Foundations');
  });

  test('a full-gym user can run equipment-specific plans (no penalty)', async () => {
    await seedTemplates();
    const { accessToken } = await registerAndToken();
    await setProfile(accessToken, {
      goals: ['build_muscle'],
      experience: 'intermediate',
      daysPerWeek: 6,
      equipment: ['full_gym'],
    });

    const res = await get(accessToken);

    // The intermediate 6-day full-gym hypertrophy plan is the perfect match:
    // goal + equipment + experience + days all align.
    const top = res.body.templates[0];
    expect(top.name).toBe('Push Pull Legs Hypertrophy');
    // 100 goal + 40 equipment + 20 experience + 15 days
    expect(top.matchScore).toBe(175);
  });

  test('only template plans are returned, never adopted user plans', async () => {
    await seedTemplates();
    const { accessToken, userId } = await registerAndToken();

    // An adopted (owned, non-template) plan must not leak into the library.
    const owned = await Workout.create({
      name: 'My Day',
      owner: userId,
      exercises: [{ name: 'Curl', sets: 3, reps: 10 }],
    });
    await Plan.create({
      name: 'My Adopted Plan',
      owner: userId,
      isTemplate: false,
      workouts: [owned._id],
    });

    const res = await get(accessToken);

    expect(res.body.templates).toHaveLength(TEMPLATES.length);
    expect(res.body.templates.map((t) => t.name)).not.toContain(
      'My Adopted Plan'
    );
  });
});
