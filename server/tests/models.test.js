'use strict';

const {
  User,
  Profile,
  Plan,
  Workout,
  WorkoutLog,
  Subscription,
} = require('../src/models');

// These exercise schema definition, validation rules, and instance methods via
// validateSync() / new — no live MongoDB connection required. (Unique indexes
// are enforced by Mongo at write time and are not covered here.)

describe('User model', () => {
  it('requires email and passwordHash', () => {
    const err = new User({}).validateSync();
    expect(err.errors.email).toBeDefined();
    expect(err.errors.passwordHash).toBeDefined();
  });

  it('rejects a malformed email', () => {
    const err = new User({ email: 'not-an-email', passwordHash: 'x' }).validateSync();
    expect(err && err.errors.email).toBeDefined();
  });

  it('lowercases and trims a valid email and accepts the doc', () => {
    const user = new User({ email: '  Test@Example.COM ', passwordHash: 'hash' });
    expect(user.validateSync()).toBeUndefined();
    expect(user.email).toBe('test@example.com');
  });

  it('omits passwordHash from toJSON output', () => {
    const user = new User({ email: 'a@b.com', passwordHash: 'secret-hash' });
    const json = user.toJSON();
    expect(json.email).toBe('a@b.com');
    expect(json.passwordHash).toBeUndefined();
  });
});

describe('Profile model', () => {
  it('requires a user reference', () => {
    const err = new Profile({}).validateSync();
    expect(err.errors.user).toBeDefined();
  });

  it('rejects out-of-range daysPerWeek', () => {
    const err = new Profile({
      user: '507f1f77bcf86cd799439011',
      daysPerWeek: 9,
    }).validateSync();
    expect(err.errors.daysPerWeek).toBeDefined();
  });

  it('rejects an unknown goal enum value', () => {
    const err = new Profile({
      user: '507f1f77bcf86cd799439011',
      goals: ['become_a_dragon'],
    }).validateSync();
    expect(err.errors['goals.0']).toBeDefined();
  });

  it('accepts a well-formed profile and defaults onboardingComplete to false', () => {
    const profile = new Profile({
      user: '507f1f77bcf86cd799439011',
      goals: ['build_muscle', 'gain_strength'],
      experience: 'intermediate',
      daysPerWeek: 4,
      equipment: ['dumbbells', 'barbell'],
      bodyStats: { heightCm: 180, weightKg: 80, age: 30, sex: 'male' },
    });
    expect(profile.validateSync()).toBeUndefined();
    expect(profile.onboardingComplete).toBe(false);
  });
});

describe('Workout model', () => {
  it('requires a name', () => {
    const err = new Workout({}).validateSync();
    expect(err.errors.name).toBeDefined();
  });

  it('requires each exercise to have a name and defaults formTracked to false', () => {
    const err = new Workout({
      name: 'Push Day',
      exercises: [{ sets: 3, reps: 10 }],
    }).validateSync();
    expect(err.errors['exercises.0.name']).toBeDefined();

    const ok = new Workout({
      name: 'Push Day',
      exercises: [{ name: 'Bench Press', sets: 3, reps: 8 }],
    });
    expect(ok.validateSync()).toBeUndefined();
    expect(ok.exercises[0].formTracked).toBe(false);
    expect(ok.exercises[0].restSeconds).toBe(60);
  });
});

describe('Plan model', () => {
  it('requires a name and defaults isTemplate/isActive to false', () => {
    const err = new Plan({}).validateSync();
    expect(err.errors.name).toBeDefined();

    const plan = new Plan({ name: 'Beginner Full Body', daysPerWeek: 3 });
    expect(plan.validateSync()).toBeUndefined();
    expect(plan.isTemplate).toBe(false);
    expect(plan.isActive).toBe(false);
    expect(plan.owner).toBeNull();
  });

  it('rejects an unknown experience value', () => {
    const err = new Plan({ name: 'P', experience: 'grandmaster' }).validateSync();
    expect(err.errors.experience).toBeDefined();
  });
});

describe('WorkoutLog model', () => {
  it('requires user and startedAt', () => {
    const err = new WorkoutLog({}).validateSync();
    expect(err.errors.user).toBeDefined();
    expect(err.errors.startedAt).toBeDefined();
  });

  it('accepts a log with nested logged sets', () => {
    const log = new WorkoutLog({
      user: '507f1f77bcf86cd799439011',
      startedAt: new Date('2026-06-26T10:00:00Z'),
      exercises: [
        {
          name: 'Squat',
          sets: [
            { reps: 5, weightKg: 100, completed: true },
            { reps: 5, weightKg: 100 },
          ],
        },
      ],
    });
    expect(log.validateSync()).toBeUndefined();
    expect(log.exercises[0].sets[1].completed).toBe(true);
  });
});

describe('Subscription model', () => {
  it('requires a user and defaults to a free/active/none subscription', () => {
    const err = new Subscription({}).validateSync();
    expect(err.errors.user).toBeDefined();

    const sub = new Subscription({ user: '507f1f77bcf86cd799439011' });
    expect(sub.validateSync()).toBeUndefined();
    expect(sub.tier).toBe('free');
    expect(sub.status).toBe('active');
    expect(sub.provider).toBe('none');
  });

  it('rejects an unknown tier', () => {
    const err = new Subscription({
      user: '507f1f77bcf86cd799439011',
      tier: 'platinum',
    }).validateSync();
    expect(err.errors.tier).toBeDefined();
  });

  describe('isPremiumActive()', () => {
    const userId = '507f1f77bcf86cd799439011';
    const now = new Date('2026-06-26T00:00:00Z');

    it('is false for the free tier', () => {
      const sub = new Subscription({ user: userId, tier: 'free' });
      expect(sub.isPremiumActive(now)).toBe(false);
    });

    it('is true for an active premium with no expiry', () => {
      const sub = new Subscription({
        user: userId,
        tier: 'premium',
        status: 'active',
      });
      expect(sub.isPremiumActive(now)).toBe(true);
    });

    it('is true for premium expiring in the future', () => {
      const sub = new Subscription({
        user: userId,
        tier: 'premium',
        status: 'active',
        expiresAt: new Date('2026-12-31T00:00:00Z'),
      });
      expect(sub.isPremiumActive(now)).toBe(true);
    });

    it('is false once the expiry has passed', () => {
      const sub = new Subscription({
        user: userId,
        tier: 'premium',
        status: 'active',
        expiresAt: new Date('2026-01-01T00:00:00Z'),
      });
      expect(sub.isPremiumActive(now)).toBe(false);
    });

    it('is false for a cancelled premium even before expiry', () => {
      const sub = new Subscription({
        user: userId,
        tier: 'premium',
        status: 'cancelled',
        expiresAt: new Date('2026-12-31T00:00:00Z'),
      });
      expect(sub.isPremiumActive(now)).toBe(false);
    });
  });
});
