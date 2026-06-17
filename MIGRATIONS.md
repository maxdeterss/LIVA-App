# LIVA — Database Migrations

Migrations are applied to the Supabase project `LIVA` (`deqdmxbvvfatdakqqfnv`).
Each is idempotent where practical. RLS is enabled on every table.

## MVP (01–07)
- **01** profiles, signup trigger, RLS
- **02** social graph: follows, posts, post_tags, likes, comments
- **03** *(legacy tracking — superseded by Health Phase 1, see 08)*
- **04** conversations, messages (the "Send" feature)
- **05** storage buckets (avatars, posts), feed/profile_stats/username RPCs, realtime
- **06** function hardening (search_path, execute grants)
- **07** case-insensitive storage folder policy

## Health & Tracking — Phase 1 (08–12)

| # | Migration | Summary |
|---|-----------|---------|
| 08 | `health_drop_legacy_extend_profiles` | Drops the simpler MVP tracking tables (weight_logs, workout_logs, workout_exercises, daily_metrics, nutrition_logs, nutrition_targets) and the old `workout_type` enum. Extends `profiles` with `units`, `birth_date`, `sex`, `height_cm`, `weight_goal_kg`, `activity_timezone`. |
| 09 | `health_goals_workouts_strength` | `goals` (versioned by effective_date); `workouts` (+ `workout_type`/`workout_source`/`privacy_level` enums, de-dupe `external_id`); `exercises` library; `strength_sets`. RLS incl. a privacy-aware select policy on workouts for the future social feed. |
| 10 | `health_biometrics_body_water` | `biometrics` (+ `biometric_metric`/`metric_source` enums, `metadata` jsonb for sleep stages), `body_metrics`, `water_logs`. Indexes on `(user_id, recorded_at)`. |
| 11 | `health_nutrition_stubs` | `foods`, `servings`, `nutrition_logs` stubs (fully built in Phase 3). Reuses the existing `meal_type` enum. |
| 12 | `seed_exercises` | Seeds ~60 common movements into `exercises`. |

## Health & Tracking — Phase 2 (13–14)

| # | Migration | Summary |
|---|-----------|---------|
| 13 | `gps_activities` | Enables **PostGIS**. Extends `workouts` with GPS fields (distance, moving/elapsed time, elevation gain/loss, avg/max pace & speed, encoded `polyline`, `bounds`, start/end coords, `map_thumbnail_url`, `is_indoor`, `route geography(LineString,4326)`, `gear_id`). Adds `activity_streams` (jsonb time-series), `gear` (mileage accumulation), `personal_records`, `activity_photos`, and `segments` + `segment_efforts` (tables; spatial matching Edge Function pending). RLS + leaderboard index. |
| 14 | `increment_gear_distance` | RPC to accumulate gear mileage (owner-checked). |

> **Note:** PostGIS lives in `public` — Supabase's advisor flags extensions in
> `public` as a warning; acceptable here. The `route` geography column and
> `segments` tables are in place for the Phase-2 segment-matching Edge Function.

### Conflict resolution / sync
- Tables carry `updated_at`; the client's offline queue replays writes with
  **last-write-wins** semantics on reconnect.
- `external_id` + `source` unique indexes on `workouts`/`biometrics` enable
  multi-source de-duplication (Phase 4 wearables).

### Notes
- The MVP tracking tables were dropped (no production data existed). The Health
  module is the canonical tracking schema going forward.
- GPS columns for `workouts` and the `activity_streams` table arrive in Phase 2.
