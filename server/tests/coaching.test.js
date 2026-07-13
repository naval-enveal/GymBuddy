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
const { User, Profile, RefreshToken, Subscription } = require('../src/models');

// Integration tests for POST /coaching/cues (M9) — server-side Gemini form
// coaching. The AI client is injected via ai.client.setClient so no
// network/API key is needed; a real user is registered through the auth
// endpoints so the access token authenticates through the real middleware.

/** A fake AI client returning `cuesJson` as a JSON text block. */
function fakeClient(cuesJson, capture) {
  return {
    messages: {
      create: async (params) => {
        if (capture) capture.params = params;
        return { content: [{ type: 'text', text: JSON.stringify(cuesJson) }] };
      },
    },
  };
}

describe('POST /coaching/cues', () => {
  const app = createApp();
  let mongod;

  const creds = { email: 'coach-user@example.com', password: 'sup3r-secret-pw' };

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

  // /coaching/cues is premium-gated server-side, so the AI-behavior tests
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
      experience: 'beginner',
      daysPerWeek: 3,
      equipment: ['barbell'],
      injuries: ['left knee'],
      onboardingComplete: true,
      ...overrides,
    });
  }

  test('requires authentication', async () => {
    const res = await request(app)
      .post('/coaching/cues')
      .send({ exercise: 'Back Squat' });
    expect(res.status).toBe(401);
  });

  test('rejects a free user server-side (402), before any AI call', async () => {
    // Register but do NOT grant premium — the default subscription is free.
    const reg = await request(app).post('/auth/register').send({ ...creds });
    expect(reg.status).toBe(201);
    const { accessToken } = reg.body;
    let called = false;
    aiClient.setClient({
      messages: { create: async () => { called = true; return { content: [] }; } },
    });

    const res = await request(app)
      .post('/coaching/cues')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ exercise: 'Back Squat' });

    expect(res.status).toBe(402);
    expect(res.body.error.message).toMatch(/premium/i);
    expect(called).toBe(false);
  });

  test('rejects a cancelled premium subscription (402)', async () => {
    const reg = await request(app).post('/auth/register').send({ ...creds });
    expect(reg.status).toBe(201);
    const { accessToken, user } = reg.body;
    await Subscription.updateOne(
      { user: user.id },
      { tier: 'premium', status: 'cancelled' }
    );
    aiClient.setClient(fakeClient({ cues: ['Chest up.'] }));

    const res = await request(app)
      .post('/coaching/cues')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ exercise: 'Back Squat' });

    expect(res.status).toBe(402);
  });

  test('allows an active premium user through the gate', async () => {
    const { accessToken } = await registerAndToken();
    aiClient.setClient(fakeClient({ cues: ['Chest up.'] }));

    const res = await request(app)
      .post('/coaching/cues')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ exercise: 'Back Squat' });

    expect(res.status).toBe(200);
  });

  test('returns prioritized spoken cues for a faulty set', async () => {
    const { accessToken } = await registerAndToken();
    aiClient.setClient(
      fakeClient({
        cues: ['Push your knees out as you stand.', 'Keep your chest up.'],
      })
    );

    const res = await request(app)
      .post('/coaching/cues')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        exercise: 'Back Squat',
        formCues: [
          { severity: 'major', message: 'Knees caving in', joint: 'knee' },
        ],
        reps: 5,
        targetReps: 8,
        setNumber: 2,
      });

    expect(res.status).toBe(200);
    expect(res.body.cues).toEqual([
      'Push your knees out as you stand.',
      'Keep your chest up.',
    ]);
  });

  test('feeds the exercise, faults, set progress, and profile into the prompt', async () => {
    const { accessToken, userId } = await registerAndToken();
    await seedProfile(userId);
    const capture = {};
    aiClient.setClient(fakeClient({ cues: ['Brace your core.'] }, capture));

    const res = await request(app)
      .post('/coaching/cues')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        exercise: 'Romanian Deadlift',
        formCues: [{ severity: 'minor', message: 'Lower back rounding' }],
        reps: 6,
        targetReps: 10,
        setNumber: 1,
      });

    expect(res.status).toBe(200);
    const userMessage = capture.params.messages[0].content;
    // Exercise + fault signal.
    expect(userMessage).toContain('Romanian Deadlift');
    expect(userMessage).toContain('Lower back rounding');
    // Set-progress signal.
    expect(userMessage).toContain('10');
    // Profile signal read server-side (experience + injury).
    expect(userMessage).toContain('beginner');
    expect(userMessage).toContain('left knee');
    // Uses the configured model and structured output.
    expect(capture.params.model).toBe('gemini-flash-latest');
    expect(capture.params.output_config.format.type).toBe('json_schema');
  });

  test('works without a profile (coaching is not gated on onboarding)', async () => {
    const { accessToken } = await registerAndToken();
    const capture = {};
    aiClient.setClient(fakeClient({ cues: ['Slow the descent.'] }, capture));

    const res = await request(app)
      .post('/coaching/cues')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ exercise: 'Bench Press' });

    expect(res.status).toBe(200);
    expect(res.body.cues).toEqual(['Slow the descent.']);
    // Empty trainee context when there's no profile.
    expect(capture.params.messages[0].content).toContain('"trainee": {}');
  });

  test('returns an empty list for a clean set', async () => {
    const { accessToken } = await registerAndToken();
    aiClient.setClient(fakeClient({ cues: [] }));

    const res = await request(app)
      .post('/coaching/cues')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ exercise: 'Back Squat', formCues: [] });

    expect(res.status).toBe(200);
    expect(res.body.cues).toEqual([]);
  });

  test('sanitizes malformed cue output (trims, drops blanks, caps to 3)', async () => {
    const { accessToken } = await registerAndToken();
    aiClient.setClient(
      fakeClient({
        cues: [
          '  Push your knees out.  ', // trimmed
          '', // blank → dropped
          42, // non-string → dropped
          'Chest up.',
          'Brace.',
          'A fourth cue that should be dropped.', // over the cap of 3
        ],
      })
    );

    const res = await request(app)
      .post('/coaching/cues')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ exercise: 'Back Squat' });

    expect(res.status).toBe(200);
    expect(res.body.cues).toEqual([
      'Push your knees out.',
      'Chest up.',
      'Brace.',
    ]);
  });

  test('returns an empty list when the model output has no cues array', async () => {
    const { accessToken } = await registerAndToken();
    aiClient.setClient(fakeClient({ notCues: 'whoops' }));

    const res = await request(app)
      .post('/coaching/cues')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ exercise: 'Back Squat' });

    expect(res.status).toBe(200);
    expect(res.body.cues).toEqual([]);
  });

  test('rejects (502) when the model returns invalid JSON', async () => {
    const { accessToken } = await registerAndToken();
    aiClient.setClient({
      messages: {
        create: async () => ({ content: [{ type: 'text', text: 'not json' }] }),
      },
    });

    const res = await request(app)
      .post('/coaching/cues')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ exercise: 'Back Squat' });

    expect(res.status).toBe(502);
  });

  test('returns 503 when AI is not configured', async () => {
    const { accessToken } = await registerAndToken();
    aiClient.setClient(null); // no injected client, no API key in test env

    const res = await request(app)
      .post('/coaching/cues')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ exercise: 'Back Squat' });

    expect(res.status).toBe(503);
  });

  test('requires an exercise (400)', async () => {
    const { accessToken } = await registerAndToken();
    aiClient.setClient(fakeClient({ cues: [] }));

    const res = await request(app)
      .post('/coaching/cues')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ formCues: [{ message: 'Knees caving' }] });

    expect(res.status).toBe(400);
    expect(res.body.error.message).toMatch(/exercise/);
  });

  test('rejects an invalid form-cue severity (400)', async () => {
    const { accessToken } = await registerAndToken();
    aiClient.setClient(fakeClient({ cues: [] }));

    const res = await request(app)
      .post('/coaching/cues')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        exercise: 'Back Squat',
        formCues: [{ severity: 'catastrophic', message: 'Knees caving' }],
      });

    expect(res.status).toBe(400);
    expect(res.body.error.message).toMatch(/severity/);
  });

  test('rejects an out-of-range rep count (400)', async () => {
    const { accessToken } = await registerAndToken();
    aiClient.setClient(fakeClient({ cues: [] }));

    const res = await request(app)
      .post('/coaching/cues')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ exercise: 'Back Squat', reps: 99999 });

    expect(res.status).toBe(400);
    expect(res.body.error.message).toMatch(/reps/);
  });
});
