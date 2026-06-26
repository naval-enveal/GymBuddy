'use strict';

/**
 * Barrel for the domain models so callers can do
 * `const { User, Profile } = require('../models')`.
 */

const User = require('./user.model');
const Profile = require('./profile.model');
const Plan = require('./plan.model');
const Workout = require('./workout.model');
const WorkoutLog = require('./workout-log.model');
const Subscription = require('./subscription.model');
const RefreshToken = require('./refresh-token.model');
const constants = require('./constants');

module.exports = {
  User,
  Profile,
  Plan,
  Workout,
  WorkoutLog,
  Subscription,
  RefreshToken,
  constants,
};
