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

// Integration tests for adopting a library template as the active plan (M4):
//   POST /plans/:id/adopt  — writes an owned, active copy of the template
//   GET  /plans/active     — returns the caller's active plan (or null)
// One active plan per user is enforced server-side; the client is never trusted
// to deactivate a prior plan.

describe('plan adoption (POST /plans/:id/adopt, GET /plans/active)', () => {
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

  /** Adopt by id with the given token. */
  function adopt(accessToken, id) {
    return request(app)
      .post(`/plans/${id}/adopt`)
      .set('Authorization', `Bearer ${accessToken}`);
  }

  function getActive(accessToken) {
    return request(app)
      .get('/plans/active')
      .set('Authorization', `Bearer ${accessToken}`);
  }

  /** A template id to adopt, plus the template doc. */
  async function aTemplate(name = 'Full Body Foundations') {
    return Plan.findOne({ isTemplate: true, name });
  }

  test('adopt requires authentication', async () => {
    const res = await request(app).post(`/plans/${new mongoose.Types.ObjectId()}/adopt`);
    expect(res.status).toBe(401);
    expect(res.body.error.message).toBeDefined();
  });

  test('GET /plans/active requires authentication', async () => {
    const res = await request(app).get('/plans/active');
    expect(res.status).toBe(401);
  });

  test('with no plan adopted, active is null', async () => {
    const { accessToken } = await registerAndToken();
    const res = await getActive(accessToken);
    expect(res.status).toBe(200);
    expect(res.body.plan).toBeNull();
  });

  test('adopting a template creates an owned, active copy with its own workouts', async () => {
    await seedTemplates();
    const { accessToken, userId } = await registerAndToken();
    const template = await aTemplate();

    const res = await adopt(accessToken, template._id.toString());

    expect(res.status).toBe(201);
    const { plan } = res.body;
    // An owned, non-template, active copy of the template.
    expect(plan.isTemplate).toBe(false);
    expect(plan.isActive).toBe(true);
    expect(plan.owner).toBe(userId);
    expect(plan.name).toBe(template.name);
    expect(plan.goal).toBe(template.goal);
    expect(plan.sourceTemplate).toBe(template._id.toString());
    // Workouts are copied (populated docs), owned by the user, with exercises.
    expect(plan.workouts.length).toBe(template.workouts.length);
    for (const w of plan.workouts) {
      expect(typeof w).toBe('object');
      expect(w.owner).toBe(userId);
      expect(w.exercises.length).toBeGreaterThan(0);
    }
    // The copied workouts are distinct documents from the template's.
    const templateWorkoutIds = template.workouts.map((id) => id.toString());
    for (const w of plan.workouts) {
      expect(templateWorkoutIds).not.toContain(w._id);
    }
  });

  test('the adopted plan is returned by GET /plans/active', async () => {
    await seedTemplates();
    const { accessToken } = await registerAndToken();
    const template = await aTemplate();

    const adopted = await adopt(accessToken, template._id.toString());
    const res = await getActive(accessToken);

    expect(res.status).toBe(200);
    expect(res.body.plan).not.toBeNull();
    expect(res.body.plan._id).toBe(adopted.body.plan._id);
    expect(res.body.plan.sourceTemplate).toBe(template._id.toString());
  });

  test('adopting a second plan deactivates the first (one active per user)', async () => {
    await seedTemplates();
    const { accessToken, userId } = await registerAndToken();
    const first = await aTemplate('Full Body Foundations');
    const second = await aTemplate('Push Pull Legs Hypertrophy');

    const firstAdopt = await adopt(accessToken, first._id.toString());
    const secondAdopt = await adopt(accessToken, second._id.toString());

    expect(secondAdopt.status).toBe(201);

    // Active reflects only the second plan.
    const active = await getActive(accessToken);
    expect(active.body.plan._id).toBe(secondAdopt.body.plan._id);
    expect(active.body.plan.name).toBe('Push Pull Legs Hypertrophy');

    // The first plan still exists but is now inactive; exactly one active plan.
    const firstDoc = await Plan.findById(firstAdopt.body.plan._id);
    expect(firstDoc.isActive).toBe(false);
    const activeCount = await Plan.countDocuments({
      owner: userId,
      isActive: true,
    });
    expect(activeCount).toBe(1);
  });

  test('one user adopting does not affect another user', async () => {
    await seedTemplates();
    const a = await registerAndToken('a@example.com');
    const b = await registerAndToken('b@example.com');
    const template = await aTemplate();

    await adopt(a.accessToken, template._id.toString());

    // User B still has no active plan.
    const bActive = await getActive(b.accessToken);
    expect(bActive.body.plan).toBeNull();
    // User A does.
    const aActive = await getActive(a.accessToken);
    expect(aActive.body.plan).not.toBeNull();
  });

  test('adopting a non-template (or unknown) plan 404s', async () => {
    await seedTemplates();
    const { accessToken } = await registerAndToken();

    // Unknown id.
    const unknown = await adopt(accessToken, new mongoose.Types.ObjectId().toString());
    expect(unknown.status).toBe(404);
    expect(unknown.body.error.message).toBeDefined();

    // An owned, non-template plan must not be adoptable as a template.
    const owned = await Plan.create({
      name: 'My Adopted Plan',
      owner: (await User.findOne({}))._id,
      isTemplate: false,
    });
    const nonTemplate = await adopt(accessToken, owned._id.toString());
    expect(nonTemplate.status).toBe(404);
  });

  test('adopted plans never leak into the template library', async () => {
    await seedTemplates();
    const { accessToken } = await registerAndToken();
    const template = await aTemplate();

    await adopt(accessToken, template._id.toString());

    const res = await request(app)
      .get('/plans/templates')
      .set('Authorization', `Bearer ${accessToken}`);
    // Only templates come back; the adopted owned copy is excluded.
    expect(res.body.templates.every((t) => t.isTemplate === true)).toBe(true);
    expect(res.body.templates.every((t) => t.owner === null)).toBe(true);
  });
});
