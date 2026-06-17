# Changelog

## Health & Tracking — Phase 1 · Data Foundation, HealthKit Spine & Manual Logging

### Added
- **Canonical health schema** (migrations 08–12): goals, workouts, strength_sets,
  exercises (seeded), biometrics, body_metrics, water_logs, nutrition stubs — all RLS-locked.
- **HealthKit spine, abstracted** — `HealthDataSource` protocol with:
  - `MockHealthDataSource` (ships by default; makes the simulator fully functional)
  - `HealthKitDataSource` (real reads: steps, active energy, HRV, RHR, SpO₂, body temp,
    sleep; per-metric daily series; write-back authorization scopes prepared).
- **Offline-first** — SwiftData-backed `OfflineQueue` write-ahead log. Manual logs persist
  locally and replay to Supabase on reconnect (last-write-wins). Flushes on launch + foreground.
- **DI container** — `HealthEnvironment` injects mockable services behind protocols
  (`GoalService`, `WorkoutService`, `BiometricService`, `BodyMetricService`,
  `WaterService`, `NutritionReadService`) via `RemoteWriter`.
- **Live HEALTH dashboard** (refactored to new schema):
  - BIOMETRICS row pulls live values, each tappable → per-metric **detail chart**
    (Swift Charts, W/M/3M ranges, min/avg/max).
  - Week strip selects a day and loads that day's workouts/nutrition/water.
  - WORKOUTS card shows real steps + active calories; NUTRITION ring + macro bars live.
- **Manual loggers**: Workout (type, duration, calories, HR, privacy + strength sets with a
  **rest timer + haptics**), Biometric (any metric), Weight + body-fat. Meal → Phase 3 stub.
- **Reusable components**: `MetricChip`, `SegmentedProgressBar`.
- **Unit tests** (14, Swift Testing): pace, macros, the goal/remaining-calorie equation,
  unit conversions, stats, latest-per-metric, and offline connectivity classification.

### Changed
- Replaced the MVP's simpler tracking tables and dashboard with the richer Health module.
- Locked the app to its light cream theme; input text always renders dark.

### Engineering
- New `LIVA/Health/` module: Models, HealthKit, Persistence, Services, DI, Components, Views.
- Accessibility labels on metric chips and progress bars; 44pt+ touch targets.

### Deferred / requires action
- **HealthKit on device**: real data needs a physical iPhone + the HealthKit entitlement.
  Flip `HealthDataSourceFactory.make()` to `HealthKitDataSource()` once enabled.
- Phase 2 (GPS tracking), Phase 3 (nutrition + AI), Phase 4 (wearables), Phase 5 (insights).

## MVP
- Auth, onboarding, Loops feed (like/comment/send), post creation, profile + creator links.
- LIVA brand identity: app icon + VA monogram.
