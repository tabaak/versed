# VERSED — Style, Compared. 👟👕

A modern Flutter app for head-to-head outfit battles and curation. Built on Flutter, state-managed with Riverpod, and powered by Supabase for backend services, real-time votes, and media storage.

---

## 🚀 Key Features (MVP)

- **1v1 Outfit Battles:** Head-to-head outfit card comparisons. Tapping an outfit records a vote and dynamically loads the next contender.
- **Vote & Curation Metrics:** Real-time tracking of community engagement via **Votes Cast** and outfit performance via **Style Win-Rate (%)**.
- **Photo Uploads:** Quick photo picker allowing users to upload their outfits directly into the battle arena.
- **Dual Language Support (Localization):** Default language is **English**.
- **One-Tap Google Auth:** Fast and secure social login using Google Authentication via Supabase OAuth.

---

## 🛠 Tech Stack

* **Framework:** Flutter (iOS / Android)
* **State Management:** [Riverpod](https://riverpod.dev) (**Manual provider declaration only** — no code generation, `@riverpod`, or `build_runner`).
* **Backend & Auth:** [Supabase](https://supabase.com) (PostgreSQL, Supabase Auth with Google OAuth, Storage).
* **Navigation:** [GoRouter](https://pub.dev/packages/go_router) with declarative routes and Auth Guards.

---

## 📁 Project Architecture

The project is structured into feature-isolated modules (`features/`) and a shared core (`core/`):

lib/
├── core/                         # Shared app foundation
│   ├── l10n/                     # Localization (AppLocalizations)
│   ├── theme/                    # Design system (colors, typography)
│   ├── services/                 # Global services (Supabase, Storage)
│   └── widgets/                  # Shared UI components (AppButton, loaders)
│
└── features/                     # Feature modules
    ├── auth/                     # Google Auth & session handling
    ├── battle/                   # Head-to-head battle screen & voting logic
    ├── onboarding/               # Welcome flow for first-time users
    └── profile/                  # User profiles, outfit uploads, and stats

### Feature Layering
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

---

## 🎨 Development Standards & Rules

To maintain codebase cleanliness and prevent merge conflicts, follow these guidelines (detailed in `AGENTS.md`):

### 1. Riverpod Without Code Generation
* All providers are declared **manually** (`Provider`, `NotifierProvider`, `AsyncNotifierProvider`).
* Code generators like `build_runner` or `@riverpod` are **strictly forbidden** to prevent merge conflicts in `.g.dart` files.

### 2. Data Model Requirements
Every data model must implement:
- `copyWith` method for state immutability.
- `operator ==` and `hashCode` overrides for value equality.
- `toString()` for clean debug logging.
- `static const ... empty` for predictable initial states.

### 3. UI Guidelines
* **Reusability:** Use shared widgets from `lib/core/widgets/` (e.g., `AppButton`, input fields, text placeholders).
* **Clean Build Methods:** Avoid deeply nested widget trees. If a file exceeds 300 lines, extract sub-trees into standalone `ConsumerWidget` or `StatelessWidget` classes in `presentation/widgets/`.
* **No Business Logic in UI:** Widgets only dispatch events to controllers. All calculations, vote validation, and data formatting must reside inside controllers or services.
* **Modals:** Open all bottom sheets through `AppModal.showBottomSheet`.

### 4. Navigation (GoRouter)
* **Decentralized Routes:** Each screen defines its route as a static `route` getter inside its class file. The main router (`lib/core/router/app_router.dart`) imports and registers them.
* **Named Navigation:** Use `context.goNamed(...)` over raw path strings.
* **Auth Guards:** Access control is managed reactively at the `GoRouter` level, avoiding imperative checks inside screens.