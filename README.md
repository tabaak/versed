# VERSED — Style, Compared. 👟👕

A modern Flutter app for head-to-head outfit battles and curation. Built on Flutter, state-managed with Riverpod, and powered by Supabase for backend services, real-time votes, and media storage.

---

## 🛠 Tech Stack

* **Framework:** Flutter (iOS / Android)
* **State Management:** [Riverpod](https://riverpod.dev) (**Manual provider declaration only** — no code generation, `@riverpod`, or `build_runner`).
* **Backend & Auth:** [Supabase](https://supabase.com) (PostgreSQL, Supabase Auth with Google OAuth, Storage).
* **Navigation:** [GoRouter](https://pub.dev/packages/go_router) with declarative routes and Auth Guards.

---

## ✨ Features

* **Google Sign-In** — Supabase Auth with a native-feeling auth page (animated outfit matchup hero, Google-branded button). An `AuthGate` routes signed-out users to the auth page, holds signed-in users without a handle at a pick-a-handle step, and sends everyone else to the versus screen.
* **Genres** — every fit declares one of six genres (streetwear, formal, casual, Y2K, techwear, vintage), chosen in the upload picker. Matchmaking pairs within a genre, so voters judge how well an outfit is put together rather than which style they prefer, and the arena labels the battle's genre above the board. Real outfits are entered and tagged by hand with `tool/tag_fits.dart`.
* **Live matchups** — the arena asks `next_matchup()` for a pair the user has not judged yet, keeping a small prefetched queue so the next battle appears the instant a winner is crowned. Votes go through `cast_vote()`, which records the vote and moves both fits' counters in one transaction.
* **Uploads** — pick from camera or library, preview in the same 4:5 frame the arena crops to, pick the genre it competes in, then enter. Photos live in a public `fits` storage bucket under the owner's uuid.
* **Moderation** — long-press a fit in the arena to report it; a fit leaves the pool once enough people agree. Tap your own fit in the profile grid to retire it — a soft delete, so the battles it already fought still count for the fits it faced.
* **Versus battles** — the main screen pits two 4:5 outfit photos against each other in a diagonal layout (bottom-left vs top-right) with a VS badge at the seam:
  * **Tap** an outfit to pre-highlight it (subtle scale + brighter border, auto-clears after 1.5s).
  * **Double-tap** to crown the winner — it scales up with an accent glow while the loser dims, a small burst of emojis arcs and falls from the tap point, then the next pair fades in.
  * Graded haptic feedback (selection tick on tap, medium impact on the winning double-tap) and full reduce-motion support.

---

## 📁 Project Architecture

The ideal scaffold keeps the design system and showcase in the shared `core/` module, with each feature in its own module under `features/`:

lib/
├── core/                         # Shared app foundation
│   ├── l10n/                     # Localization (AppLocalizations)
│   ├── theme/                    # Design system (colors, typography)
│   ├── services/                 # Global services (Supabase, Storage)
│   ├── widgets/                  # Shared UI components (AppButton, loaders)
│   └── presentation/             # Core pages and showcase sections
│       ├── pages/
│       └── widgets/
├── features/
│   ├── auth/                     # Google sign-in, AuthGate, auth page
│   ├── fits/                     # Fit model, queries, uploads, the user's own fits
│   ├── versus/                   # Outfit battle screen (VersusPage), matchmaking, voting
│   ├── upload/                   # Photo picker, 4:5 preview, entering the arena
│   ├── profile/                  # Profile, battle record, fits grid, handle onboarding
│   └── home/                     # Signed-in tab shell

### Core Layering
1. `models/` — Pure Dart models (manual `fromJson`/`toJson`, `copyWith`, `operator ==`, and `hashCode`).
2. `services/` — Stateless Supabase queries and API calls.
3. `controllers/` — `Notifier` / `AsyncNotifier` for managing screen state.
4. `presentation/` — Screen pages (`pages/`) and reusable widgets (`widgets/`).

---

## 🧑‍💻 Developer Commands

- **Format Code:** `dart format .`
- **Analyze Project:** `flutter analyze`
- **Run in Debug Mode:** `flutter run`
- **Generate iOS Config (SPM):** `flutter build ios --config-only`
