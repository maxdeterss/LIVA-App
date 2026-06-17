# LIVA — iOS App

The first social platform combining fitness, nutrition, and goal tracking in one
application. This is the native iOS (SwiftUI) MVP, backed by Supabase.

> Built to the MVP PRD scope (Auth · Feed · Post Creation · Tracking · Creator
> Profile), architected to extend into the full FORGE/LIVA vision (marketplace,
> gym finder, communities, commerce).

---

## Quick start

1. **Open the project**
   ```
   open LIVA.xcodeproj
   ```
   Xcode will resolve the Swift Package dependency (`supabase-swift`) automatically.

2. **Pick a simulator** (iPhone 15/16, iOS 17+) and press ⌘R.

That's it — the app is already wired to a live Supabase project (see below).

### One recommended backend setting

For frictionless sign-up during development, disable email confirmation:
**Supabase Dashboard → Authentication → Providers → Email → turn off
"Confirm email."** With it on, new accounts must confirm via email before they
can sign in (the app handles this gracefully and shows a prompt either way).

---

## Architecture

```
LIVA/
├── App/                  App entry, SessionStore (auth state), RootView router, MainTabView
├── Config/               Supabase-Info.plist + AppConfig (reads connection details)
├── DesignSystem/         Theme (cream palette), Typography, Components, FlowLayout
├── Models/               Codable models mapping the Postgres schema
├── Services/             Supabase client + one service per domain (Auth, Profile, Feed,
│                         Post, Tracking, Messaging, Storage) + JSON date handling
└── Features/
    ├── Auth/             Sign in / sign up
    ├── Onboarding/       Username · photo · goal · content preferences
    ├── Health/           Dashboard (biometrics, workouts, nutrition) + logging sheets
    ├── Loops/            Feed, post cards, comments, "Send" (share to DM)
    ├── Create/           Post creation (image/video, caption, tags, music)
    └── Profile/          Profile, edit profile, creator links, settings
```

**Patterns**
- **MVVM**: each feature has a `View` + an `@MainActor ObservableObject` view model.
- **Services are stateless enums** that wrap Supabase calls and decode with a shared
  `AppJSON` decoder (handles both `timestamptz` and bare `date` columns).
- **Design system first**: every screen is built from `LivaCard`, `IconCircle`,
  `ProgressRing`, `MacroBar`, `SelectablePill`, etc., so the cream aesthetic from the
  mockups stays consistent.
- The Xcode project uses **file-system synchronized groups** — just add a `.swift`
  file anywhere under `LIVA/` and it's compiled automatically (no project edits).

---

## Backend (Supabase)

- **Project:** `LIVA` (`deqdmxbvvfatdakqqfnv`), region `us-east-1`
- **URL:** `https://deqdmxbvvfatdakqqfnv.supabase.co`
- Connection details live in `LIVA/Config/Supabase-Info.plist`.

### Schema (applied via migrations)

| Area      | Tables |
|-----------|--------|
| Identity  | `profiles` (+ `handle_new_user` trigger) |
| Social    | `follows`, `posts`, `post_tags`, `likes`, `comments` |
| Messaging | `conversations`, `messages` (powers "Send") |
| Tracking  | `weight_logs`, `workout_logs`, `workout_exercises`, `daily_metrics`, `nutrition_targets`, `nutrition_logs` |
| Creator   | `creator_links` |

**RPCs:** `feed`, `profile_stats`, `username_available`, `get_or_create_conversation`.
**Storage buckets:** `avatars`, `posts` (public read; users write only to their own
`<uid>/` folder).

Row-Level Security is enabled on every table: profiles/posts/social data are publicly
readable but only writable by their owner; all tracking data is private to its owner.

---

## What's implemented (MVP)

- ✅ **Auth** — email/password, username in metadata
- ✅ **Onboarding** — username, profile photo, goal, content preferences
- ✅ **Health dashboard** — week strip, biometrics, workouts, nutrition ring + macros,
  quick-add; full logging for weight, workouts (with exercises), biometrics, meals;
  "View All" detail screens and editable daily targets
- ✅ **Loops feed** — followed-user feed, like (optimistic), comment, **Send** (share to
  a friend's DMs), follow suggestions when empty
- ✅ **Post creation** — photo/video, caption, hashtags, people tags, music
- ✅ **Profile** — identity, stats, post grid, creator links (social/affiliate),
  follow/unfollow, edit profile, settings
- 🔜 **Groups** — tab present as a placeholder for the post-MVP community features

---

## Finishing touches (optional polish)

- **App icon**: drop a 1024×1024 into `LIVA/Assets.xcassets/AppIcon.appiconset`
  (the brand mark is in `../App Design/`).
- **Brand font**: the wordmark approximates Archivo Black with the system black weight.
  Add `ArchivoBlack.ttf` to the project and update `Font.wordmark` in
  `DesignSystem/Typography.swift` for a pixel-perfect match.
- **Seed data**: create a couple of accounts and post from each to see the feed populate.
