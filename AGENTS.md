# Flutter + Riverpod + Supabase: Architectural Guide and AI Agent Instructions

This document describes the target architecture for the **peredai** project, workflow rules for 3 developers/agents working in parallel, and detailed guidelines for AI agents on writing code.

---

## 1. Tech Stack
* **Framework:** Flutter (latest stable version)
* **State Management:** [Riverpod](https://riverpod.dev) using manual provider declarations (No code generation / No `@riverpod`).
* **Backend & Database:** [Supabase](https://supabase.com) (Auth, Database/PostgreSQL, Realtime, Storage)
* **Data Serialization:** Plain Dart classes (No `freezed`, no `json_serializable`) with manual `fromJson` and `toJson` methods.

---

## 2. Key Code Philosophy
* **Simplicity & Readability:** Code must be kept as simple, explicit, and easy to read as possible.
* **No Code Generation:** Avoid code generation entirely (`build_runner` is NOT used). All models, state classes, and Riverpod providers must be written manually as plain, readable Dart code. This prevents git merge conflicts on generated files.

---

## 3. Directory Structure
To keep the project clean, modular, and easy to scale for 3 parallel developers, each feature is organized into four main areas: `models`, `services`, `controllers`, and `presentation`.

### Project Directory Structure
```text
lib/
├── core/                         # Shared components, utilities, and services
│   ├── theme/                    # App theme, colors, typography
│   ├── services/                 # Shared services (Supabase client configuration)
│   │   ├── app_initializer.dart  # Centralized app initializer
│   │   └── supabase_service.dart # Supabase client and its provider
│   ├── widgets/                  # Shared UI components (buttons, loaders)
│   └── utils/                    # Helpers, validators, extensions
│
├── features/                     # All business features of the app
│   ├── auth/                     # Example feature: Authentication
│   │   ├── models/               # Plain Dart models
│   │   │   └── auth_model.dart
│   │   ├── services/             # Pure Supabase database queries and commands
│   │   │   └── auth_service.dart
│   │   ├── controllers/          # Riverpod controllers (UI State Management)
│   │   │   └── auth_controller.dart
│   │   └── presentation/         # Presentation Layer (UI)
│   │       ├── pages/            # Feature pages (screens)
│   │       │   └── auth_page.dart
│   │       └── widgets/          # Feature-specific widgets
│   │           └── auth_button.dart
│   │
│   ├── profile/                  # Example feature: User Profile
│   └── transfer/                 # Example feature: Money Transfers
│
└── main.dart                     # Application entry point
```

---

## 4. How the Feature Folders Work

1. **`models/`:**
   * Contains plain Dart classes for data representation. Must include custom `fromJson`, `toJson`, `copyWith`, value equality overrides (`==`/`hashCode`), and `toString`.

2. **`services/` (Data & Logic Queries):**
   * Contains stateless classes that handle raw data fetching, insertions, updates, and authentication commands directly via the Supabase client.
   * They do not manage UI state (like loading flags or errors). They simply return `Future`s or `Stream`s.
   * Exposed using a standard, manual Riverpod `Provider`.

3. **`controllers/` (UI State Controllers):**
   * Contains classes extending Riverpod's `Notifier` or `AsyncNotifier` (without generator).
   * They call methods from the feature's `Service` and map the results into UI state (loading, error, success).
   * Exposed using manual `NotifierProvider` or `AsyncNotifierProvider`.

4. **`presentation/`:**
   * **`pages/`**: Full screens/pages of the app (e.g. `auth_page.dart`). Extends `ConsumerWidget` or `ConsumerStatefulWidget` and reads state from controllers.
   * **`widgets/`**: Smaller UI components specific to this feature.

---

## 5. Workflow Rules for Parallel Collaboration (3 Developers)
To ensure 3 developers can commit code in parallel without conflicts, follow these rules:
1. **Feature Isolation:** A developer working on Feature `A` must not modify files inside the directory of Feature `B`. If Feature `A` needs data or triggers action from Feature `B`, access must be performed **strictly through controller/service providers** in Feature `B`.
2. **Single Point of Entry for Supabase Client:** Services must retrieve the Supabase client instance from the global `supabaseClientProvider` defined in `lib/core/services/supabase_service.dart`.
3. **No Generated Files:** Do not check in or generate `.g.dart` or `.freezed.dart` files. All source files must be standard Dart files written by hand.
4. **Centralized App Initialization:** All asynchronous services, environment checks, and settings that must start before `runApp` (e.g. WidgetsFlutterBinding, Supabase, Hive, SharedPreferences) must be initialized inside the `AppInitializer.init()` method. The `main()` function should be kept minimal.

---

## 6. Guidelines for AI Agents (AI Agent Guidelines)

> [!IMPORTANT]
> When writing, updating, or refactoring code, follow these rules strictly.

### 6.1. Riverpod Best Practices
* **Manual Providers:** Define providers manually.
  * For simple read-only services: use `Provider`.
  * For state logic: use `NotifierProvider` (synchronous) or `AsyncNotifierProvider` (asynchronous).
* **UI Subscription:** Use `ref.watch` in the widget's `build` method to reactively track state. Use `ref.read` only inside callbacks (e.g., button clicks).

### 6.2. Guidelines for Model Class Methods (Working with Riverpod State)
When writing models or state classes manually, include the following methods/overrides to work smoothly with Riverpod:

1. **`copyWith`**: Vital for updating specific parts of the state in Notifiers/Controllers without modifying the original object reference (preserving immutability).
2. **`operator ==` and `hashCode`**: By default, Dart compares instances by reference. Overriding these methods ensures **value equality**. Without this, Riverpod and Flutter UI will trigger redundant rebuilds when two objects with the exact same data are compared.
3. **`toString`**: Highly useful for logging, debugging, and printing state changes inside `ProviderObserver`.
4. **`empty` / `initial` representation**: A static constant or factory constructor representing the initial state.

### 6.3. UI & Widget Design Guidelines
To maintain a high-quality, maintainable, and clean user interface, follow these UI rules:

1. **Reusability of Core Widgets:** Reuse shared/global widgets from the shared core directory `lib/core/widgets/` (e.g., buttons, input fields, custom loaders, dialogs) as much as possible. Do not duplicate UI logic locally if it already exists globally.
2. **Sub-Widget Deconstruction:** If a page or layout grows too large (e.g., exceeds 300–400 lines of code), break the large UI build method into smaller sub-widgets. 
   * Prefer extracting them into separate files inside `presentation/widgets/` as self-contained `StatelessWidget` or `ConsumerWidget` classes rather than storing them as helper methods in the same page.
   * This improves code readability, performance (only sub-widgets rebuild), and testing.
3. **Separating Presentation & Logic Methods:**
   * **Do NOT write inline helper widgets in methods** (e.g., `Widget _buildHeader()`) inside the widget class. Extract them to separate classes to allow Flutter to optimize and rebuild them individually.
   * **Keep widgets declarative:** Do not write heavy business logic, calculations, formatting, or validation methods inside a widget class.
   * **Move logic to Controller/Service:** All data formatting, complex validation, API calls, and business logic must live inside the `Controller` or `Service`.
   * **UI Action Handling:** The widget should only handle purely interface-level triggers (e.g., toggling local UI state, showing a modal sheet, or triggering a dialog). If the method modifies application state or interacts with services, delegate it to the controller (e.g., `onPressed: () => ref.read(authControllerProvider.notifier).login()`).
4. **Use of Helpers & Validators (Utils):**
   * Before writing any text validation (e.g., email patterns, input checks) or formatting logic (e.g., currency, dates), check if a helper function already exists in `lib/core/utils/`.
   * **Do NOT write local helper/formatting functions inside UI files.** If it is a shared utility, place it in `lib/core/utils/`. If it is highly feature-specific, encapsulate it in the `Controller` or a separate utility file in the feature directory, never inline or local in the UI code.
5. **Centralized Modals Management:**
   * Do NOT call Flutter's native modal builders (`showModalBottomSheet`, etc.) directly inside UI features.
   * All bottom sheets must be displayed using the unified [AppModal.showBottomSheet] utility to ensure consistent wrapping, styling, margins, keyboard adjustments, and drag/close behaviors.


### 6.4. Routing Guidelines (Navigator 1.0)

There is **no router package**. The app is a single `CupertinoApp` with `home: const AuthGate()`, and every screen change is an imperative push on the one root navigator. Do not add `go_router` (or any router) back without a reason that needs it — deep links or web URLs would be such a reason; nothing currently does.

1. **Each page owns how it is opened.** Rather than a central route table, a pushed page exposes a `static` opener that takes what it needs and does the push itself. This is what keeps navigation out of the caller and avoids the merge conflicts a shared route file causes:
   ```dart
   // Inside lib/features/profile/presentation/pages/public_profile_page.dart
   class PublicProfilePage extends ConsumerWidget {
     static Future<void> open(
       BuildContext context, {
       required String userId,
       String? handle,
     }) {
       return Navigator.of(context).push<void>(
         CupertinoPageRoute<void>(
           builder: (_) => PublicProfilePage(userId: userId, handle: handle),
         ),
       );
     }
     // ...
   }
   ```
   Callers then write `PublicProfilePage.open(context, userId: fit.ownerId)` and know nothing about routes. A page that hands something back types the push and returns it (`Future<bool?>` over `push<bool>`).

   `FitViewerPage` and `PublicProfilePage` follow this. The rest — `SettingsPage`, `EditProfilePage`, `ChooseHandlePage` — are still pushed inline by their callers; prefer the opener when adding a page, and when a page picks up a second call site.
2. **`CupertinoPageRoute` by default,** so the iOS edge-swipe-back gesture and the platform transition come for free. A custom `PageRoute` is only warranted when the transition itself is the point — `FitViewerRoute` is the one instance, transparent so the grid stays visible behind the photo's Hero flight.
3. **`Navigator.of(context).pop()` is the correct way to dismiss.** It is not a workaround. Guard it with `if (!mounted) return` after any `await`, since the page may be gone by the time the future completes.
4. **Auth gating is a widget, not a redirect.** `AuthGate` watches `authControllerProvider` and `profileControllerProvider` and *builds* the auth page, the pick-a-handle step, or `HomeShell`. Add new launch-time gates there by extending that switch — never by imperatively pushing or popping from inside a page in response to auth state.
5. **Do not push tabs.** `HomeShell` keeps Versus, Upload, and Profile alive in an `IndexedStack`; switching tabs is state, not navigation. Only pages layered *over* the shell (settings, edit profile, a public profile, the fit viewer) get pushed.

#### Cross-feature navigation

A feature must not import another feature's page just to push it. Where a widget needs to open a screen that belongs elsewhere, it takes a callback and the *caller* supplies the destination:

```dart
// fits/ knows nothing about profile/; the caller wires the two together.
FitViewerPage.open(
  context,
  fit: fit,
  heroTag: heroTag,
  isOwn: false,
  onOwnerTap: () => PublicProfilePage.open(context, userId: fit.ownerId),
);
```

The exception is a top-level tab page, which has no caller above it to inject the callback — `VersusPage` importing `PublicProfilePage` directly is accepted for that reason. Keep such imports one-directional so no cycle forms.

---

## 7. Template for a New Feature File Set
When creating a new feature, generate files matching the following pattern:

#### 1. Data Model (`lib/features/chat/models/message.dart`)
```dart
class Message {
  final String id;
  final String text;
  final DateTime createdAt;
  final String senderId;

  const Message({
    required this.id,
    required this.text,
    required this.createdAt,
    required this.senderId,
  });

  // Empty initial state
  static const Message empty = Message(
    id: '',
    text: '',
    createdAt: null,
    senderId: '',
  );

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      text: json['text'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      senderId: json['sender_id'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'created_at': createdAt.toIso8601String(),
      'sender_id': senderId,
    };
  }

  Message copyWith({
    String? id,
    String? text,
    DateTime? createdAt,
    String? senderId,
  }) {
    return Message(
      id: id ?? this.id,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      senderId: senderId ?? this.senderId,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Message &&
        other.id == id &&
        other.text == text &&
        other.createdAt == createdAt &&
        other.senderId == senderId;
  }

  @override
  int get hashCode {
    return Object.hash(id, text, createdAt, senderId);
  }

  @override
  String toString() {
    return 'Message(id: $id, text: $text, createdAt: $createdAt, senderId: $senderId)';
  }
}
```

#### 2. Service (`lib/features/chat/services/chat_service.dart`)
```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../models/message.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatService {
  final SupabaseClient _client;
  ChatService(this._client);

  Future<List<Message>> fetchMessages() async {
    final response = await _client
        .from('messages')
        .select()
        .order('created_at', ascending: true);

    return (response as List)
        .map((json) => Message.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<void> createMessage(String text) async {
    await _client.from('messages').insert({
      'text': text,
    });
  }
}

// Manual provider declaration for the service
final chatServiceProvider = Provider<ChatService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return ChatService(client);
});
```

#### 3. UI State Controller (`lib/features/chat/controllers/chat_controller.dart`)
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/message.dart';
import '../services/chat_service.dart';

class ChatController extends AutoDisposeAsyncNotifier<List<Message>> {
  @override
  FutureOr<List<Message>> build() async {
    final service = ref.watch(chatServiceProvider);
    return service.fetchMessages();
  }

  Future<void> sendMessage(String text) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.watch(chatServiceProvider);
      
      // Perform database write operation via Service
      await service.createMessage(text);

      // Refetch and return new state
      return service.fetchMessages();
    });
  }
}

// Manual provider declaration for the controller
final chatControllerProvider = AsyncNotifierProvider.autoDispose<ChatController, List<Message>>(() {
  return ChatController();
});
```

---

## 8. Checklist Before Committing Changes
1. **Formatting:** Run `dart format .`
2. **Static Analysis:** Run `flutter analyze` and ensure zero errors/warnings.
3. **No Generated Files:** Ensure there are no `.g.dart` or other generated files created.
4. **Isolation:** Ensure new files reside strictly inside their designated feature directory in `lib/features/` or the shared directory in `lib/core/`.


## 🎨 Design System
Refer to `DESIGN.md` for all UI styling, colors, typography, haptics, and layout rules. Do not use generic Material colors or light mode. Also uipro skill is available to use in the root folder of the project.