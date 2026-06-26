# GymBuddy — backend

Node.js + Express + MongoDB (Mongoose) REST API. Currently boots with a
`GET /health` endpoint; auth and domain models land in M1. See `../docs/PLAN.md`
for per-milestone scope and `../docs/STATUS.md` for the live task list. Root
conventions in `../CLAUDE.md` apply here too.

## Commands (run from `server/`)
- `npm run dev` — start with nodemon (auto-reload)
- `npm start` — start once (`node src/server.js`)
- `npm test` — Jest + supertest, run in band
- `npm run lint` — ESLint; must be clean before a task is marked done

## Layout (`src/`)
- `app.js` — builds the Express app. **Side-effect free** (no `listen`, no DB
  connect) so supertest can import it directly. Add routes and middleware here.
- `server.js` — boots HTTP + attempts the DB connection. A DB failure does not
  stop the server from serving requests (health-check reports DB state).
- `config/env.js` — reads `process.env` (PORT, NODE_ENV, MONGODB_URI) with
  defaults. The only place env vars are read.
- `db/connect.js` — Mongoose connection.
- `routes/` — Express routers (`*.routes.js`), thin: wire paths to controllers.
- `controllers/` — request/response handling (`*.controller.js`).
- `services/` — business logic, reused across controllers.
- `models/` — Mongoose schemas (M1: User, Profile, Plan, Workout, WorkoutLog,
  Subscription).
- `middleware/` — auth, validation, error handling (M1).

## Conventions
- `'use strict';` at the top of every module; CommonJS `require`/`module.exports`.
- **API shape:** REST + JSON. JWT (access + refresh, bcrypt for passwords) in the
  `Authorization` header. Keep one **shared error response shape** —
  `{ error: { message } }` (see the 404 handler in `app.js`); extend it
  consistently, don't invent per-route shapes.
- Layering: routes → controllers → services → models. Keep DB access out of
  controllers once services exist.
- **Validation:** validate requests at the edge (M1 adds middleware + the shared
  error shape).

## Security rules (non-negotiable)
- **Secrets via env only.** Never read secrets outside `config/env.js`. Never
  commit `.env` (use `.env.example`). The Claude API key is server-side only.
- **Premium gating is enforced here, never trusted from the client.** Verify
  subscription state server-side on every premium-gated endpoint.

## Tests
Jest + supertest. Import `createApp()` from `app.js` directly — no live port
needed. Write meaningful tests; never weaken or skip one to make CI green.
