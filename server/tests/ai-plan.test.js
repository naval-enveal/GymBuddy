'use strict';

// Keep bcrypt cheap (register mints a real user). Must be set before config
// loads transitively via the routes/services.
process.env.BCRYPT_ROUNDS = '4';
// AI is exercised via an injected fake client; ensure no real key leaks in from
// the dev environment (the 503-when-unconfigured test depends on this).
delete process.env.GEMINI_API_KEY;

const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
const createApp = require('../src/app');
const aiClient = require('../src/services/ai.client');
const {
  User,
  Profile,
  Plan,
  Workout,
  WorkoutLog,
  RefreshToken,
  Subscription,
} = require('../src/models');

// Integration tests for POST /plans/generate (M9) — server-side Gemini plan
// generation. The AI client is injected via ai.client.setClient so no
// network/API key is needed; a real user is registered through the auth
// endpoints so the access token authenticates through the real middleware.

/** A fake AI client returning `planJson` as a JSON text block. */
function fakeClient(planJson, capture) {
  return {
    messages: {
      create: async (params) => {
        if (capture) capture.params = params;
        return { content: [{ type: 'text', text: JSON.stringify(planJson) }] };
      },
    },
  };
}

/** A well-formed plan the model might return. */
function goodPlan() {
  return {
    name: 'Hypertrophy Builder',
    description: 'A 3-day split tuned to your goals.',
    goal: 'build_muscle',
    experience: 'intermediate',
    daysPerWeek: 3,
    equipment: ['dumbbells', 'barbell'],
    workouts: [
      {
        name: 'Push Day',
        description: 'Chest, shoulders, triceps.',
        estimatedMinutes: 50,
        exercises: [
          {
            name: 'Barbell Bench Press',
            sets: 4,
            reps: 8,
            restSeconds: 90,
            targetWeightKg: 60,
            formTracked: true,
            notes: 'Keep shoulders retracted.',
          },
        ],
      },
      {
        name: 'Pull Day',
        exercises: [
          { name: 'Pull-up', sets: 3, reps: null, restSeconds: 90, formTracked: false },
        ],
      },
    ],
  };
}

describe('POST /plans/generate', () => {
  const app = createApp();
  let mongod;

  const creds = { email: 'ai-user@example.com', password: 'sup3r-secret-pw' };

  beforeAll(async () => {
    mongod = await MongoMemoryServer.create();
    await mongoose.connect(mongod.getUri());
  }, 60000);

  afterAll(async () => {
    await mongoose.disconnect();
    if (mongod) await mongod.stop();
  });

  afterEach(async () => {
    aiClient.setClient(null); // reset the injected client between tests
    await Promise.all([
      User.deleteMany({}),
      Profile.deleteMany({}),
      Plan.deleteMany({}),
      Workout.deleteMany({}),
      WorkoutLog.deleteMany({}),
      RefreshToken.deleteMany({}),
      Subscription.deleteMany({}),
    ]);
  });

  /** Flip the user's (free-by-default) subscription to active premium. */
  async function grantPremium(userId) {
    await Subscription.updateOne(
      { user: userId },
      { tier: 'premium', status: 'active', provider: 'revenuecat' }
    );
  }

  // /plans/generate is premium-gated server-side, so the AI-behavior tests
  // register a premium caller; the gate itself is covered separately below.
  async function registerAndToken(email = creds.email) {
    const res = await request(app)
      .post('/auth/register')
      .send({ ...creds, email });
    expect(res.status).toBe(201);
    const userId = res.body.user.id;
    await grantPremium(userId);
    return { accessToken: res.body.accessToken, userId };
  }

  async function seedProfile(userId, overrides = {}) {
    return Profile.create({
      user: userId,
      goals: ['build_muscle'],
      experience: 'intermediate',
      daysPerWeek: 3,
      equipment: ['dumbbells', 'barbell'],
      injuries: ['left knee'],
      bodyStats: { heightCm: 178, weightKg: 80, age: 30, sex: 'male' },
      onboardingComplete: true,
      ...overrides,
    });
  }

  test('requires authentication', async () => {
    const res = await request(app).post('/plans/generate').send({});
    expect(res.status).toBe(401);
  });

  test('rejects a free user server-side (402), before any AI call', async () => {
    // Register but do NOT grant premium — the default subscription is free.
    const reg = await request(app)
      .post('/auth/register')
      .send({ ...creds });
    expect(reg.status).toBe(201);
    const { accessToken, user } = reg.body;
    await seedProfile(user.id);
    // A client claiming premium must not matter: the gate reads the server-side
    // subscription, and the AI service is never reached.
    let called = false;
    aiClient.setClient({
      messages: { create: async () => { called = true; return { content: [] }; } },
    });

    const res = await request(app)
      .post('/plans/generate')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({});

    expect(res.status).toBe(402);
    expect(res.body.error.message).toMatch(/premium/i);
    expect(called).toBe(false);
  });

  test('rejects an expired premium subscription (402)', async () => {
    const reg = await request(app).post('/auth/register').send({ ...creds });
    expect(reg.status).toBe(201);
    const { accessToken, user } = reg.body;
    await seedProfile(user.id);
    // tier says premium but it has lapsed — isPremiumActive() must gate it out.
    await Subscription.updateOne(
      { user: user.id },
      { tier: 'premium', status: 'expired' }
    );
    aiClient.setClient(fakeClient(goodPlan()));

    const res = await request(app)
      .post('/plans/generate')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({});

    expect(res.status).toBe(402);
  });

  test('allows an active premium user through the gate', async () => {
    const { accessToken, userId } = await registerAndToken();
    await seedProfile(userId);
    aiClient.setClient(fakeClient(goodPlan()));

    const res = await request(app)
      .post('/plans/generate')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({});

    expect(res.status).toBe(201);
  });

  test('requires a profile (onboarding first)', async () => {
    const { accessToken } = await registerAndToken();
    aiClient.setClient(fakeClient(goodPlan()));

    const res = await request(app)
      .post('/plans/generate')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({});

    expect(res.status).toBe(400);
    expect(res.body.error.message).toMatch(/onboarding/i);
  });

  test('generates and persists an active plan owned by the caller', async () => {
    const { accessToken, userId } = await registerAndToken();
    await seedProfile(userId);
    aiClient.setClient(fakeClient(goodPlan()));

    const res = await request(app)
      .post('/plans/generate')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({});

    expect(res.status).toBe(201);
    expect(res.body.plan).toBeDefined();
    expect(res.body.plan.name).toBe('Hypertrophy Builder');
    expect(res.body.plan.workouts).toHaveLength(2);
    // Workouts are populated, not bare ids.
    expect(res.body.plan.workouts[0].name).toBe('Push Day');
    expect(res.body.plan.workouts[0].exercises[0].name).toBe(
      'Barbell Bench Press'
    );

    // Persisted as the caller's active, owned, non-template, AI-sourced plan.
    const stored = await Plan.findById(
      res.body.plan.id || res.body.plan._id
    );
    expect(stored.owner.toString()).toBe(userId);
    expect(stored.isActive).toBe(true);
    expect(stored.isTemplate).toBe(false);
    expect(stored.sourceTemplate).toBeNull();

    // Workouts are owned by the caller.
    const workouts = await Workout.find({ owner: userId });
    expect(workouts).toHaveLength(2);
  });

  test('deactivates any prior active plan (one active plan per user)', async () => {
    const { accessToken, userId } = await registerAndToken();
    await seedProfile(userId);
    const prior = await Plan.create({
      name: 'Old Plan',
      owner: userId,
      isTemplate: false,
      isActive: true,
    });
    aiClient.setClient(fakeClient(goodPlan()));

    const res = await request(app)
      .post('/plans/generate')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({});

    expect(res.status).toBe(201);
    const reloadedPrior = await Plan.findById(prior._id);
    expect(reloadedPrior.isActive).toBe(false);
    const active = await Plan.find({ owner: userId, isActive: true });
    expect(active).toHaveLength(1);
    expect(active[0].name).toBe('Hypertrophy Builder');
  });

  test('feeds profile, recent history, and vitals into the prompt', async () => {
    const { accessToken, userId } = await registerAndToken();
    await seedProfile(userId);
    await WorkoutLog.create({
      user: userId,
      startedAt: new Date('2026-06-20T09:00:00.000Z'),
      exercises: [{ name: 'Romanian Deadlift', sets: [{ reps: 10, weightKg: 70 }] }],
    });
    const capture = {};
    aiClient.setClient(fakeClient(goodPlan(), capture));

    const res = await request(app)
      .post('/plans/generate')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ vitals: { restingHeartRate: 52, hrv: 88, sleepHours: 7.5, readiness: 81 } });

    expect(res.status).toBe(201);
    const userMessage = capture.params.messages[0].content;
    // Profile signal.
    expect(userMessage).toContain('build_muscle');
    expect(userMessage).toContain('left knee');
    // Recent history signal.
    expect(userMessage).toContain('Romanian Deadlift');
    // Vitals signal.
    expect(userMessage).toContain('52');
    expect(userMessage).toContain('81');
    // Uses the configured model and structured output.
    expect(capture.params.model).toBe('gemini-2.5-flash');
    expect(capture.params.output_config.format.type).toBe('json_schema');
  });

  test('sanitizes malformed model output (clamps, drops junk, fallbacks)', async () => {
    const { accessToken, userId } = await registerAndToken();
    await seedProfile(userId);
    aiClient.setClient(
      fakeClient({
        name: '   ',
        goal: 'not_a_real_goal', // out of vocabulary → profile fallback
        experience: 'wizard', // invalid → profile fallback
        daysPerWeek: 99, // out of range → clamped
        equipment: ['barbell', 'jetpack'], // unknown filtered out
        workouts: [
          {
            name: 'Day 1',
            exercises: [
              { name: 'Squat', sets: 999, reps: 0, restSeconds: -5 }, // clamped
              { name: '   ', sets: 3 }, // nameless → dropped
            ],
          },
          { name: 'Empty Day', exercises: [] }, // no exercises → dropped
        ],
      })
    );

    const res = await request(app)
      .post('/plans/generate')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({});

    expect(res.status).toBe(201);
    const plan = res.body.plan;
    expect(plan.name).toBe('Personalized Plan'); // blank name → fallback
    expect(plan.goal).toBe('build_muscle'); // profile fallback
    expect(plan.experience).toBe('intermediate'); // profile fallback
    expect(plan.daysPerWeek).toBeLessThanOrEqual(7);
    expect(plan.equipment).toEqual(['barbell']); // 'jetpack' filtered
    expect(plan.workouts).toHaveLength(1); // empty day dropped
    const ex = plan.workouts[0].exercises;
    expect(ex).toHaveLength(1); // nameless exercise dropped
    expect(ex[0].sets).toBe(20); // 999 clamped to max
    expect(ex[0].restSeconds).toBe(0); // -5 clamped to min
    expect(ex[0].reps).toBe(1); // 0 clamped to min
  });

  test('rejects (502) when the model returns no usable workouts', async () => {
    const { accessToken, userId } = await registerAndToken();
    await seedProfile(userId);
    aiClient.setClient(
      fakeClient({ name: 'Bad', goal: 'build_muscle', workouts: [] })
    );

    const res = await request(app)
      .post('/plans/generate')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({});

    expect(res.status).toBe(502);
  });

  test('rejects (502) when the model returns invalid JSON', async () => {
    const { accessToken, userId } = await registerAndToken();
    await seedProfile(userId);
    aiClient.setClient({
      messages: { create: async () => ({ content: [{ type: 'text', text: 'not json' }] }) },
    });

    const res = await request(app)
      .post('/plans/generate')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({});

    expect(res.status).toBe(502);
  });

  test('returns 503 when AI is not configured', async () => {
    const { accessToken, userId } = await registerAndToken();
    await seedProfile(userId);
    aiClient.setClient(null); // no injected client, no API key in test env

    const res = await request(app)
      .post('/plans/generate')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({});

    expect(res.status).toBe(503);
  });

  test('rejects non-object vitals (400)', async () => {
    const { accessToken, userId } = await registerAndToken();
    await seedProfile(userId);
    aiClient.setClient(fakeClient(goodPlan()));

    const res = await request(app)
      .post('/plans/generate')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ vitals: 'not-an-object' });

    expect(res.status).toBe(400);
    expect(res.body.error.message).toMatch(/vitals/);
  });

  test('rejects an out-of-range vital (400)', async () => {
    const { accessToken, userId } = await registerAndToken();
    await seedProfile(userId);
    aiClient.setClient(fakeClient(goodPlan()));

    const res = await request(app)
      .post('/plans/generate')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ vitals: { restingHeartRate: 9999 } });

    expect(res.status).toBe(400);
    expect(res.body.error.message).toMatch(/restingHeartRate/);
  });
});
