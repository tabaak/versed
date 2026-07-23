# VERSED Design Identity

This document covers the *why* behind VERSED's look and feel — the facts that can't be read out of the codebase. It intentionally does not re-describe things that already have a single source of truth:

- **Widgets & components** → `lib/core/widgets/` and `lib/core/theme/` are the source of truth. If this doc and the code ever disagree, the code wins — fix the code or fix this doc, don't let both stand.
- **General UI/UX patterns, layout, accessibility** → use the `ui-ux-pro-max` skill.

## 1. Atmosphere

VERSED is a deliberate rejection of the polished, ad-heavy social media aesthetic: a near-black canvas with no gradients, no decorative color, and hard, sharp corners. Stripping every gradient, glow, and soft edge forces the eye onto the outfit photos themselves. There is no brand hue — the accent is white. The app should feel like an underground style registry, not a commercial catalog.

The atomic unit of the product is the 1v1 battle card stack (two outfit photos, `VS` divider between them). Authenticity signals — streak badges, relative timestamps, raw win-rate percentages — are first-class UI; vanity metrics (like counts, followers) are not used anywhere.

Dark is the only mode. There is no light variant, and none should be added — the darkroom metaphor depends on it.

## 2. Color Palette

Source of truth: `lib/core/theme/app_colors.dart`. Reference only, don't duplicate values here beyond what's needed to explain *role*.

| Role | Token | Notes |
|------|-------|-------|
| Canvas | `AppColors.canvas` (`#0A0A0A`) | Near-black, not pure `#000000` — lifted slightly for eye comfort on OLED/long sessions. Still reads as black. Full-bleed behind every screen. |
| Surface | `AppColors.surface` | Sheets, modals, settings rows. |
| Elevated surface | `AppColors.elevatedSurface` | Pressed states, chips, elevated rows. |
| Divider | `AppColors.divider` | Hairline separators. |
| Text primary/secondary/tertiary | `AppColors.textPrimary/textSecondary/textTertiary` | White down to dim grey. |
| Accent | `AppColors.accent` (`#FFFFFF`) | The primary action color — active tab, primary button fill, selected card highlight. VERSED has *no* brand hue; white is the verb. Paired with `AppColors.onAccent` (black text/icons on white fills). |
| Streak | `AppColors.streak` (amber) | Reserved exclusively for active win-streak indicators. Never used decoratively. |
| Error / Success | `AppColors.error` / `AppColors.success` | Destructive actions, failed uploads / positive results. |

**Rule**: no brand accent color gets introduced. We tried coral (`#FA5F55`) and went back to white — if a screen wants "pop", the answer is contrast and whitespace, not a new hue. `AppColors.accent` is defined as a token specifically so this can be revisited later without hunting through screens.

## 3. Typography

Source of truth: `lib/core/theme/app_text_styles.dart`. Every text role used in the app must exist as a named style there — don't invent a one-off size/weight in a screen, and don't invent a role here that isn't in the code.

- System font only (SF Pro via Flutter's default iOS font stack) — no custom typeface, ever.
- Weights concentrated at 400 / 600 / 700.
- Tabular figures (`FontFeature.tabularFigures()`) on any numeral that updates live (win-rate %, vote counts, timers) so digits don't jitter.

## 4. Spacing & Radius Tokens

- **Spacing scale (4pt base)**: 4, 8, 12, 16, 20, 24, 32, 40, 52, 76
- **Standard margin**: 16pt horizontal for text content; outfit battle cards are edge-to-edge (0pt)
- **Radius scale — sharp everywhere**: 4pt (checkboxes, tight elements) · 8pt (cards, buttons, inputs, notifications) · 12pt (sheets/modals). No full-pill/500pt shapes — buttons and the VS divider are sharp rectangles now, not capsules. True circles (avatars, the upload FAB ring) stay circular — a circle has no corner to sharpen.

## 5. Motion & Haptics

Motion and haptic feedback are part of the brand — the app should never feel like a generic cross-platform view.

- **Scroll physics**: bouncing overscroll everywhere (`BouncingScrollPhysics`), never Android-style stretch/glow.
- **Navigation**: iOS edge-swipe-back must work (`CupertinoPageTransitionsBuilder`).
- **Transitions**: spring physics, damping ~0.75 — not linear/ease curves.
- **Vote tap**: heavy haptic (`HapticFeedback.heavyImpact()`) — voting should have physical weight.
- **Tab change**: selection haptic (`HapticFeedback.selectionClick()`).
- **Sheet/modal open**: medium haptic (`HapticFeedback.mediumImpact()`).
- **Modals & action sheets**: native Cupertino presentations (`showCupertinoModalPopup` / `CupertinoActionSheet`), not Material bottom sheets.

## 6. Do's and Don'ts

### Do
- Use the near-black canvas (`#0A0A0A`) — dark enough to read as black, lifted just enough to ease eye strain.
- Keep the UI monochrome — white is the only accent; amber is reserved for active streaks.
- Keep corners sharp (4/8/12pt scale) — no pill/capsule shapes outside true circles.
- Make the 1v1 outfit card the hero of any screen it appears on.
- Surface genuine metrics (votes cast, win-rate %, streaks) with tabular numerals.
- Pair vote taps with heavy haptics.

### Don't
- Don't introduce a brand accent color — the lack of one *is* the brand.
- Don't use pure `#000000` — the canvas is deliberately `#0A0A0A`.
- Don't bring back full-pill/500pt radii on buttons or dividers.
- Don't add vanity metrics (like counts, followers, social clout scores).
- Don't add gradients, glows, or soft light overlays.
- Don't add a light mode.
- Don't use a custom display font.
- Don't hardcode one-off colors, sizes, or radii in a screen — add/reuse a token in `lib/core/theme` instead.
