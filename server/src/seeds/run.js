'use strict';

const mongoose = require('mongoose');
const { connectDb } = require('../db/connect');
const { seedTemplates } = require('../services/seed.service');

/**
 * CLI entry point for seeding the template library: `npm run seed`.
 * Connects to the configured MongoDB, runs the idempotent seed, and always
 * disconnects so the process exits cleanly.
 */
async function main() {
  await connectDb();
  try {
    const { plansCreated, workoutsCreated } = await seedTemplates();
    console.log(
      `Seeded ${plansCreated} template plans (${workoutsCreated} workouts).`
    );
  } finally {
    await mongoose.disconnect();
  }
}

main().catch((err) => {
  console.error('Seed failed:', err);
  process.exitCode = 1;
});
