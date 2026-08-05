# VERSED — Style, Compared. 👟👕

A modern Flutter app for head-to-head outfit battles and curation. Built on Flutter, state-managed with Riverpod, and powered by Supabase for backend services, real-time votes, and media storage.

---

## 🛠 Tech Stack

* **Framework:** Flutter (iOS / Android)
* **State Management:** [Riverpod](https://riverpod.dev) (**Manual provider declaration only** — no code generation, `@riverpod`, or `build_runner`).
* **Backend & Auth:** [Supabase](https://supabase.com) (PostgreSQL, Supabase Auth with Google OAuth, Storage).
* **Navigation:** [GoRouter](https://pub.dev/packages/go_router) with declarative routes and Auth Guards.
* **Other key packages:** `image_picker` (camera/library uploads), `shared_preferences` (local flags like onboarding hints), `share_plus` and `gal` (exporting fit photos to the share sheet or camera roll).

---

## ✨ Features

* **Google Sign-In** — Supabase Auth with a native-feeling auth page (animated outfit matchup hero, Google-branded button). An `AuthGate` routes signed-out users to the auth page, holds signed-in users without a handle at a pick-a-handle step, and sends everyone else into the app.
* **Home shell & tab bar** — a persistent `HomeShell` keeps the Versus, Upload, and Profile tabs alive in an `IndexedStack` so state survives switching. `AppTabBar` renders a sliding indicator behind the active tab with animated icon/text transitions.
* **Genres** — every fit declares one of six genres (streetwear, formal, casual, Y2K, techwear, vintage), chosen in the upload picker. Matchmaking pairs within a genre, so voters judge how well an outfit is put together rather than which style they prefer. The arena supports filtering the queue by category, with image preloading and a sync-reveal optimization so switching genres doesn't stall on network fetches, and an animated `_GenreRevealBanner` announces the active genre without shifting the board layout. Real outfits are entered and tagged by hand with `tool/tag_fits.dart`.
* **Live matchups** — the arena asks `next_matchup()` for a pair the user has not judged yet, keeping a small prefetched queue so the next battle appears the instant a winner is crowned. Votes go through `cast_vote()`, which records the vote and moves both fits' counters — wins, losses, and the winner's streak — in one transaction. A skeleton loading state (`MatchupBoardSkeleton`, built on the shared `AppSkeleton` shimmer) covers the gap while the first matchup loads.
* **Uploads** — pick from camera or library, preview in the same 4:5 frame the arena crops to, pick the genre it competes in, then enter. Photos live in a public `fits` storage bucket under the owner's uuid.
* **Fit viewer** — tap a fit (in the profile grid or a versus card) to open it full-screen with a hero transition, its view count, win rate and any run it is on, and actions to share it or save it to a `VERSED` camera-roll album via `FitExportService`. Both actions re-download the full-size original rather than reusing the screen-scaled image already on display.
* **Public profiles** — the owner's handle is a way through to them, both under a fit in the viewer and on a highlighted arena card: it opens a read-only `PublicProfilePage` with their identity, battle record and live fits. No settings, no edit button, and no saved section — what someone has bookmarked stays private to them. Backed by `publicProfileProvider`, an auto-disposed family that reads the profile row, `profile_stats()`, and their fits in one go.
* **Moderation** — long-press a fit in the arena to report it; a fit leaves the pool once enough people agree. Tap your own fit in the profile grid to retire it — a soft delete, so the battles it already fought still count for the fits it faced.
* **Settings** — account preferences and sign-out live on a dedicated settings page off the profile tab, reached via `AppNavigationBar`.
* **App island** — an overlay pill for confirmations and errors that, on Dynamic Island hardware, opens from the exact footprint of the cutout so the notification reads as the cutout itself stretching open; on every other device it floats under the status bar instead.
* **Versus battles** — the main screen pits two 4:5 outfit photos against each other in a diagonal layout (bottom-left vs top-right) with a VS badge at the seam:
  * **Tap** an outfit to pre-highlight it (subtle scale + brighter border, auto-clears after 1.5s).
  * **Double-tap** to crown the winner — it scales up with an accent glow while the loser dims, a small burst of emojis arcs and falls from the tap point, then the next pair fades in.
  * Graded haptic feedback (selection tick on tap, medium impact on the winning double-tap) and full reduce-motion support.
  * Highlighted (owner's-choice) cards reveal the owner's handle at the foot of the card and the win count beside a custom crown icon.
  * **Streaks** — crowning a winner reveals an amber flame badge in the bottom-right corner of that card when the fit is on two or more straight wins. It is withheld until the vote is in on purpose: a visible run would nudge the pick it is supposed to be the result of. The number is live — `VersusController` applies the vote to the on-screen pair before the request goes out, so the streak ticks up with the reveal animation rather than a round trip later.

---

## 📁 Project Architecture

The ideal scaffold keeps the design system and showcase in the shared `core/` module, with each feature in its own module under `features/`:

lib/
├── core/                         # Shared app foundation
│   ├── l10n/                     # Localization (AppLocalizations)
│   ├── theme/                    # Design system (colors, typography)
│   ├── services/                 # Global services (Supabase, Storage)
│   ├── widgets/                  # Shared UI components (AppButton, AppTabBar, AppSkeleton, AppIsland, loaders)
│   └── presentation/             # Core pages and showcase sections
│       ├── pages/                # Internal component showcase (design_system_page)
│       └── widgets/
├── features/
│   ├── auth/                     # Google sign-in, AuthGate, auth page
│   ├── fits/                     # Fit model, queries, uploads, fit viewer, export (share/save to camera roll)
│   ├── versus/                   # Outfit battle screen (VersusPage), matchmaking, voting, genre filtering
│   ├── upload/                   # Photo picker, 4:5 preview, entering the arena
│   ├── profile/                  # Profile, battle record, fits grid, handle onboarding, public profiles, settings page
│   └── home/                     # Signed-in tab shell (HomeShell)

### Core Layering
1. `models/` — Pure Dart models (manual `fromJson`/`toJson`, `copyWith`, `operator ==`, and `hashCode`).
2. `services/` — Stateless Supabase queries and API calls.
3. `controllers/` — `Notifier` / `AsyncNotifier` for managing screen state.
4. `presentation/` — Screen pages (`pages/`) and reusable widgets (`widgets/`).

---

## 🗄 Supabase

Migrations live in `supabase/migrations/` (profiles, fits, votes/matchmaking, reports, profile stats, the `fits` storage bucket, distinct-owner matchups, fit genres, the `avatars` storage bucket, and per-fit streaks). See `supabase/README.md` for the migration workflow.

## 🔧 Tooling Scripts

Standalone Dart scripts under `tool/` for backend/content maintenance, all sharing Supabase credential loading from `.env.local` or the environment via `tool/tool_env.dart`:
* `seed_identities.dart` — seeds test user identities.
* `seed_arena.dart` — seeds fits/matchups for local testing.
* `tag_fits.dart` — manually assigns genres to real, hand-picked outfit photos.

---

## 🧑‍💻 Developer Commands

- **Format Code:** `dart format .`
- **Analyze Project:** `flutter analyze`
- **Run in Debug Mode:** `flutter run`
- **Generate iOS Config (SPM):** `flutter build ios --config-only`
