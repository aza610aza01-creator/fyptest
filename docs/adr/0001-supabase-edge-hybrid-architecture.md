# ADR 0001: Supabase Auth + RLS + Edge Functions vs. Dedicated Custom Backend Server

* **Status**: Accepted (v5.0 Redesign)
* **Date**: 2026-10-22
* **Owners**: Lead Flutter Architect Agent (#1), Supabase Database & RLS Agent (#5), Backend Server & API Agent (#14)

## Context

Section 14 (`BACKEND SERVER AND API AGENT`) and `Server Architecture Decision Rules` of the modification specification require evaluating whether AI Gym Cloud should introduce a separate custom Node.js/NestJS backend server or rely on **Supabase Auth, PostgreSQL Row-Level Security (RLS), Supabase Storage, Database Functions (`SECURITY DEFINER`), and lightweight Supabase Edge Functions**.

## Decision

We adopt a **Supabase-First Architecture with Database RPCs & Edge Function Contracts** rather than deploying a redundant stateful Node.js/NestJS intermediary server for standard CRUD, authentication, and real-time camera posture telemetry:

1. **Client-to-Supabase HTTPS with Publishable Key Only**:
   - The Flutter client (`lib/core/constants/app_config.dart`) connects over HTTPS using only `SUPABASE_PUBLISHABLE_KEY` (`sb_publishable_...`).
   - Zero `server_admin_role` keys, database admin credentials, or third-party SMTP secrets are ever bundled in the Flutter app.
2. **Server-Enforced Row-Level Security (RLS) & Verified Admin Claims**:
   - Ownership is enforced on every table (`profiles`, `workouts`, `workout_sets`, `routines`, `routine_exercises`, `cardio_logs`, `body_measurements`, `health_logs`, `user_goals`, `camera_detections`) via `(select auth.uid()) = user_id` with composite indexes (`idx_workouts_user_started_at`, `idx_camera_detections_user_detected_at`) following `@supabase-postgres-best-practices`.
   - Admin access is verified server-side via `public.is_verified_admin()`.
3. **On-Device AI Inference First**:
   - Real-time 17-keypoint YOLOv8n-Pose posture evaluation, joint angle calculation, and equipment/sportswear detection run on-device at 11–14 ms frame latency so athlete camera video streams never leave the device.
4. **Health & Idempotent Migration Contracts**:
   - Liveness and readiness probes map to `/auth/v1/health` and `DatabaseService.verifyConnection()` without leaking secrets.
   - Guest-to-Cloud migration (`SyncController.migrateGuestDataToAccount`) uses deterministic UUID v4 primary keys and `upsert` conflict-resolution rules (`synced_at` timestamp comparison) so repeated retries are 100% idempotent.

## Consequences

* **Positive**: Zero double-hop API latency, zero server maintenance overhead in GitHub Codespaces / Windows desktop environments, and strict PostgreSQL RLS isolation per athlete.
* **Rollout & Rollback**: All schema and RLS index changes in `supabase/migrations/20261022_v4_rls_and_storage_hardening.sql` are wrapped in transactional `BEGIN ... COMMIT` blocks with `IF NOT EXISTS` / `CREATE OR REPLACE` for zero-downtime reversibility.
