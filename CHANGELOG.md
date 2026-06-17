# Changelog

## Nutrition — Phase 3 · MyFitnessPal-grade logging + Cal AI-grade AI

### Added
- **Food database (Nutritionix)** via the `food-search` Edge Function: instant search,
  **barcode scanning** (VisionKit `DataScannerViewController`), and full-macro detail lookup.
- **AI logging (Claude)** via Edge Functions: **snap-a-photo** estimation (`meal-photo`, vision)
  and **describe-your-meal** parsing (`meal-describe`) — both `claude-opus-4-8` with structured
  output. Detected items are reviewable/removable before logging, with confidence shown.
- **MealLoggerView** — the fast logging hub (≤2 taps from HEALTH): Search · Photo · Describe,
  a barcode button, **Quick Add calories**, and **recents + favorites** for one-tap re-logging.
- **FoodDetailView** — serving/quantity scaling with live macro recompute; save to favorites.
- **Live nutrition** — calorie ring + macro bars, the **remaining = goal − food + exercise**
  equation (exercise pulled from workouts + active energy), daily diary with delete, and water.
- **Schema** (migration 15): richer foods/logs, saved meals, recipes, favorites, `recent_foods` RPC.
- **4 new unit tests** (serving scaling, diary totals, remaining equation). 29 total, all green.

### Engineering
- `LIVA/Health/Nutrition/` module + 3 deployed Edge Functions (graceful without API keys).
- All AI/DB keys stay server-side; the app degrades cleanly when secrets aren't set.

### Requires action / deferred
- **Set Edge Function secrets** to enable live search/AI: `NUTRITIONIX_APP_ID` + `NUTRITIONIX_APP_KEY`
  (food DB) and `ANTHROPIC_API_KEY` (AI), in Supabase → Edge Functions → Secrets. Until then, manual
  Quick Add + custom logging + the ring work; search/AI return empty.
- Deferred to a later pass: recipes & saved-meals UI (schema exists), food-label OCR, recipe URL import,
  micronutrient breakdown screen.

## Health & Tracking — Phase 2 · GPS Cardio Tracking

### Added
- **Live GPS tracker** (`ActivityRecorder`, `@Observable`): real-time distance, pace,
  elevation (gain/loss), speed and splits at ~1 Hz. Aggressive **jitter/teleport filtering**
  (accuracy gate + sport-aware speed gate), **auto-pause/resume**, **per-mile/km splits** with
  **haptics + spoken audio cues** (AVSpeechSynthesizer, ducks music), and **indoor / no-GPS mode**.
- **Crash resilience**: the in-progress track is continuously persisted to disk and offered for
  **resume on relaunch**.
- **Location abstraction** (`LocationProvider`): real `CoreLocationProvider` (best-for-navigation,
  background-mode-gated) + `SimulatedLocationProvider` that replays a demo route so the live
  tracker is fully usable in the simulator.
- **Live map** (SwiftUI MapKit): route polyline draws in real time with a recenter/follow control.
- **Post-activity summary**: route map with start/finish pins, stat grid, **mile/km splits** (fastest
  highlighted), **elevation profile chart** (Swift Charts), editable title (auto "Morning Run"),
  privacy (Everyone/Followers/Only Me), notes, and **PR celebration**.
- **Personal records**: fastest 1K/5K/10K (sliding-window), longest distance, most elevation —
  auto-detected on save and stored.
- **Feed integration**: optional share renders an `MKMapSnapshotter` route thumbnail, uploads it,
  and posts to the Loops feed with a stat caption.
- **Schema** (migrations 13–14): PostGIS, GPS fields on `workouts`, `activity_streams`, `gear`
  (mileage RPC), `personal_records`, `activity_photos`, `segments`/`segment_efforts`.
- **Entry point**: a "Record Activity" card on the HEALTH dashboard → full-screen record flow.
- **11 new unit tests** (haversine, total distance, elevation, pace/duration formatting, jitter/teleport
  filter, split marking, polyline round-trip + known Google encoding, PR sliding-window). 25 total, all green.

### Engineering
- `LIVA/Health/GPS/` module. Location/motion `Info.plist` usage strings added to the app target.

### Deferred to a device sub-phase (need new Xcode targets + physical device + paid Apple Developer account)
- **Apple Watch companion app** (watchOS target, HKWorkoutSession, WatchConnectivity).
- **Live Activity / Dynamic Island** (ActivityKit + widget extension target).
- **Segment matching Edge Function** (PostGIS spatial join), heatmaps, challenges, GPX/FIT import-export.
- **Background location** on device: add the `location` UIBackgroundMode + entitlement; the code already
  enables `allowsBackgroundLocationUpdates` once that mode is present.

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
