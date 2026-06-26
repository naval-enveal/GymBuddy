# GymBuddy — Product Brief

**GymBuddy** is an AI fitness coach that lives in Meta Ray-Ban Gen 2 smart glasses. The glasses act like a training buddy who watches you work out: counting reps, correcting form, guiding you through the session, and answering questions hands-free, with coaching delivered as a voice in your ear.

## How it works
The user onboards (goals, experience, equipment, injuries), then gets a workout plan — general curated templates on the free tier, AI-personalized plans that adapt to performance and recovery on premium. A home dashboard shows daily vitals pulled from the phone's health platform or a connected watch (the glasses have no health sensors). During a workout the glasses go live: spoken guidance, rep counting, form cues, rest timers, in-workout Q&A, and session-matched music routed to the glasses, AirPods, or a speaker.

## Tech
Flutter app (iOS + Android), Node/Express/MongoDB backend, on-device pose models for instant rep/form work plus a cloud AI layer for richer coaching and plan generation. Glasses connect through the Meta Wearables Device Access Toolkit, behind a hardware-abstraction layer so other wearables can plug in later.

## Two honest constraints
- Public publishing of the glasses integration is gated to Meta partners until later in 2026. The phone app ships independently.
- The glasses are first-person POV, so they can't see the user's own body for every exercise. Form correction works best for mirror-facing and POV-visible movements and ships as a graded feature, not universal day one.

## Monetization
Free (general plans, basic guidance) vs premium (AI-personalized adaptive plans, full form correction, unlimited Q&A, smart playlists).
