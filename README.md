# VERSED — Style, Compared. 👟👕

A modern Flutter app for head-to-head outfit battles and curation. Built on Flutter, state-managed with Riverpod, and powered by Supabase for backend services, real-time votes, and media storage.

---

## 🛠 Tech Stack

* **Framework:** Flutter (iOS / Android)
* **State Management:** [Riverpod](https://riverpod.dev) (**Manual provider declaration only** — no code generation, `@riverpod`, or `build_runner`).
* **Backend & Auth:** [Supabase](https://supabase.com) (PostgreSQL, Supabase Auth with Google OAuth, Storage).
* **Navigation:** [GoRouter](https://pub.dev/packages/go_router) with declarative routes and Auth Guards.

---

## 📁 Project Architecture

The ideal scaffold keeps the design system and showcase in the shared `core/` module:

lib/
├── core/                         # Shared app foundation
│   ├── l10n/                     # Localization (AppLocalizations)
│   ├── theme/                    # Design system (colors, typography)
│   ├── services/                 # Global services (Supabase, Storage)
│   ├── widgets/                  # Shared UI components (AppButton, loaders)
│   └── presentation/             # Core pages and showcase sections
│       ├── pages/
│       └── widgets/

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
