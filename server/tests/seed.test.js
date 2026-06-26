'use strict';

const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
const { Plan, Workout, constants } = require('../src/models');
const { seedTemplates } = require('../src/services/seed.service');
const TEMPLATES = require('../src/seeds/templates');

// Integration tests for the M4 template library seed. The seed service writes
// real Plan/Workout documents (so Mongoose validators run) against an in-memory
// MongoDB, then we assert the library's shape, breadth, and idempotency.

describe('template library seed', () => {
  let mongod;

  beforeAll(async () => {
    mongod = await MongoMemoryServer.create();
    await mongoose.connect(mongod.getUri());
  }, 60000);

  afterEach(async () => {
    await Plan.deleteMany({});
    await Workout.deleteMany({});
  });

  afterAll(async () => {
    await mongoose.disconnect();
    if (mongod) await mongod.stop();
  });

  const expectedWorkoutCount = TEMPLATES.reduce(
    (sum, tpl) => sum + tpl.workouts.length,
    0
  );

  it('creates a template plan per definition plus all their workouts', async () => {
    const result = await seedTemplates();

    expect(result.plansCreated).toBe(TEMPLATES.length);
    expect(result.workoutsCreated).toBe(expectedWorkoutCount);
    expect(await Plan.countDocuments()).toBe(TEMPLATES.length);
    expect(await Workout.countDocuments()).toBe(expectedWorkoutCount);
  });

  it('marks every plan as a template with no owner', async () => {
    await seedTemplates();

    const plans = await Plan.find();
    expect(plans).toHaveLength(TEMPLATES.length);
    for (const plan of plans) {
      expect(plan.isTemplate).toBe(true);
      expect(plan.owner).toBeNull();
      expect(plan.isActive).toBe(false);
    }

    const workouts = await Workout.find();
    for (const workout of workouts) {
      expect(workout.owner).toBeNull();
    }
  });

  it('uses only valid enum values matched to the profile vocabulary', async () => {
    await seedTemplates();

    for (const plan of await Plan.find()) {
      expect(constants.GOALS).toContain(plan.goal);
      expect(constants.EXPERIENCE_LEVELS).toContain(plan.experience);
      expect(plan.daysPerWeek).toBeGreaterThanOrEqual(1);
      expect(plan.daysPerWeek).toBeLessThanOrEqual(7);
      expect(plan.equipment.length).toBeGreaterThan(0);
      for (const item of plan.equipment) {
        expect(constants.EQUIPMENT).toContain(item);
      }
    }
  });

  it('covers every training goal so any profile can be matched', async () => {
    await seedTemplates();

    const goals = new Set((await Plan.find()).map((p) => p.goal));
    for (const goal of constants.GOALS) {
      expect(goals).toContain(goal);
    }
  });

  it('links each plan to real workout documents that have exercises', async () => {
    await seedTemplates();

    const plans = await Plan.find().populate('workouts');
    for (const plan of plans) {
      expect(plan.workouts.length).toBeGreaterThan(0);
      for (const workout of plan.workouts) {
        // populate returns the referenced doc, not a dangling id
        expect(workout).not.toBeNull();
        expect(workout.name).toEqual(expect.any(String));
        expect(workout.exercises.length).toBeGreaterThan(0);
        for (const ex of workout.exercises) {
          expect(ex.name).toEqual(expect.any(String));
          expect(ex.sets).toBeGreaterThanOrEqual(1);
          expect(typeof ex.formTracked).toBe('boolean');
        }
      }
    }
  });

  it('is idempotent — re-seeding produces no duplicates', async () => {
    const first = await seedTemplates();
    const second = await seedTemplates();

    expect(second).toEqual(first);
    expect(await Plan.countDocuments()).toBe(TEMPLATES.length);
    expect(await Workout.countDocuments()).toBe(expectedWorkoutCount);

    // Plan names are unique across the library — no accidental dupes.
    const names = (await Plan.find()).map((p) => p.name);
    expect(new Set(names).size).toBe(names.length);
  });

  it('leaves user-authored workouts and adopted plans untouched on re-seed', async () => {
    const userId = new mongoose.Types.ObjectId();
    const userWorkout = await Workout.create({
      name: 'My Custom Day',
      owner: userId,
      exercises: [{ name: 'Curl', sets: 3, reps: 10 }],
    });
    const userPlan = await Plan.create({
      name: 'My Plan',
      owner: userId,
      isTemplate: false,
      workouts: [userWorkout._id],
    });

    await seedTemplates();

    expect(await Workout.findById(userWorkout._id)).not.toBeNull();
    expect(await Plan.findById(userPlan._id)).not.toBeNull();
    expect(await Plan.countDocuments({ isTemplate: true })).toBe(
      TEMPLATES.length
    );
  });
});
