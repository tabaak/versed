# Design System Specification for VERSED (iOS / Flutter)

## 1. Visual Theme & Atmosphere

VERSED's interface is a deliberate rejection of the polished, ad-heavy social media aesthetic. The interface is a true-black canvas (`#000000`) with almost no chrome, no gradients, and no decorative color — a stark, photographic darkroom where the only thing that matters is the real-world outfit photos facing off. There is no brand color in the UI. The accent is white. This is a design philosophy, not an oversight: by stripping every gradient, glow, and tint, VERSED forces the eye entirely onto the fits themselves. The app feels less like a commercial catalog and more like an underground style registry.

The signature element is the dual 1v1 battle layout: two edge-to-edge outfit cards stacked vertically with a high-contrast `VS` divider dividing them. This comparison card layout is the atomic unit of the entire product — it appears in the battle feed, in profile history, and in daily highlight archives. Everything else (battle metrics, win-rate indicators, style tags) is layered on top of or around these cards in plain white text on black. Authenticity signals are first-class UI: a "🔥 10 STREAK" badge for active win streaks, relative timestamps, and raw percentage indicators ("78% WIN RATE") instead of vanity like counts.

Typography is San Francisco (SF Pro) used plainly — no custom typeface, no display weights, no expressive type moments. Headlines are compact, functional, and white. The most expressive "type" moment in the app is the top battle bar displaying active streak metrics. The restraint in type mirrors the restraint in color — VERSED is anti-design as design, and the consistency of that stance is what makes it feel honest and edgy.

**Key Characteristics:**
- True-black canvas (`#000000`) — maximum starkness, no warm-black softening
- No brand accent color — the accent is white; deliberate chromatic minimalism
- Dual 1v1 battle card stack: top vs bottom outfit cards with clean 18pt rounded corners
- Authenticity tags as UI: "🔥 STREAK" badges, relative timestamps, and percentage win-rates
- High-contrast voting mechanics — clean tap/swipe feedback, no like counters
- SF Pro at 400 / 600 / 700, no custom font, no display sizes
- Bottom tab nav: Battle Feed / Upload / Leaderboard / Profile
- Heavy haptics on card selection and vote submission

## 2. Color Palette & Roles

### Canvas & Surfaces (Dark — the only mode)
- **Canvas Black** (`#000000`): The primary and only canvas — true black, full-bleed behind every screen.
- **Surface 1** (`#1C1C1E`): Sheets, bottom modals, style tag trays, settings rows.
- **Surface 2** (`#2C2C2E`): Elevated rows, pressed states, chip backgrounds, filter trays.
- **Divider** (`#2C2C2E`): Hairline separators between battle cards and profile sections.

### Text
- **Text Primary** (`#FFFFFF`): Usernames, style tags, headlines, all primary text.
- **Text Secondary** (`#8E8E93`): Timestamps, "votes cast", metadata, category strings, placeholder text.
- **Text Tertiary** (`#636366`): Disabled labels, very low-emphasis hints.

### Accent (Intentionally Monochrome)
- **Accent White** (`#FFFFFF`): The primary action color — active tab, primary button fill, selected card highlight. VERSED has *no* brand hue; white is the verb.
- **On-Accent Black** (`#000000`): Text/icon on white-filled buttons (intentional inversion, like the vote submit button).

### Semantic
- **Streak Amber** (`#FFD60A`): The "🔥 STREAK" badge and hot-run indicator — the single warm color, used only for active win streaks and hot matchups.
- **Error Red** (`#FF453A`): Failed uploads, connection-lost, destructive confirm ("Delete Outfit").
- **Success Green** (`#30D158`): Matchup results and positive win-rate indicators.

### Light Mode (Not Used)
VERSED's app is dark-only by design — the photographic darkroom metaphor depends on true black. No light variant ships.

## 3. Typography Rules

### Font Family
- **Primary**: `SF Pro Text` / `SF Pro Display` (system) — VERSED ships no custom typeface
- **Fallback Stack**: `-apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Segoe UI', Roboto, Helvetica, Arial, sans-serif`
- **Numerals**: Tabular figures for win-rate percentages and battle timers so digits don't jitter

### Hierarchy

| Role | Font | Size | Weight | Line Height | Letter Spacing | Notes |
|------|------|------|--------|-------------|----------------|-------|
| Streak Metric | SF Pro Display | 24pt | 700 | 1.1 | -0.3pt | "🔥 12 STREAK" battle header headline |
| Screen Title | SF Pro Display | 22pt | 700 | 1.2 | -0.3pt | "Battles", "Leaderboard" nav title |
| Username (Card) | SF Pro Text | 17pt | 600 | 1.2 | -0.2pt | Poster's handle above or on the outfit card |
| Style Tag / Caption | SF Pro Text | 16pt | 400 | 1.35 | 0pt | Optional outfit description or tags (e.g. #Streetwear) |
| Body | SF Pro Text | 15pt | 400 | 1.4 | 0pt | Profile stats descriptions, settings labels |
| Win Rate Label | SF Pro Text | 14pt | 600 | 1.3 | 0pt | "78% WIN RATE" indicator |
| Meta / Timestamp | SF Pro Text | 13pt | 400 | 1.3 | 0pt | "2h ago", "Paris, France", "1,240 votes" |
| Hot Streak Badge | SF Pro Text | 12pt | 700 | 1.1 | 0.2pt | "🔥 10 STREAK" status tag |
| Button (Primary) | SF Pro Text | 17pt | 600 | 1.0 | -0.2pt | "Upload Fit", "Confirm Vote" |
| Tab Label | SF Pro Text | 10pt | 600 | 1.0 | 0.1pt | Bottom tab bar labels |

### Principles
- **System font only**: No custom face — VERSED's identity is the battle layout and true-black canvas, not type
- **Weight concentrated at 400 / 600 / 700**: Regular for body/tags, semibold for handles/buttons, bold for metrics
- **Tabular numerals on percentages & stats** — numbers must not shift horizontally when updating
- **White on black, always** — there is no colored text anywhere except the amber streak badge

## 4. Component Stylings

### Buttons

**Upload Button (Floating Action Button)**
- Shape: Circle, 76pt outer ring, 4pt white stroke, transparent center
- Inner: 64pt solid white disc on press with `+` glyph
- Pressed: scale 0.92, paired with `.impactOccurred(.heavy)` haptic
- Opens `image_picker` / camera flow for fit submission

**Primary Button ("Upload Fit" / "Confirm")**
- Background: `#FFFFFF`
- Text: `#000000` (intentional inversion for contrast on black)
- Padding: 14pt vertical, 32pt horizontal
- Corner radius: 500pt (full pill)
- Font: SF Pro Text 17pt weight 600
- Pressed: opacity 0.85, scale 0.97

**Secondary Button ("Tag Fit" / "Retake")**
- Background: transparent
- Text: `#FFFFFF`
- Border: 1pt solid `rgba(255,255,255,0.4)`
- Padding: 12pt vertical, 24pt horizontal
- Corner radius: 500pt
- Font: SF Pro Text 16pt weight 600
- Pressed: border opacity → 1.0

### Cards & Containers

**Outfit Battle Card (THE signature)**
- Aspect: 1:1 square or 4:5 vertical card
- Back photo: full-bleed, corner radius 18pt
- Card shadow: `rgba(0,0,0,0.6) 0 8px 24px` (registers on black via opacity)
- Tap Card: Triggers selection state + heavy haptic `.impactOccurred(.heavy)`, submitting vote for that outfit and loading next contender pair

**VS Divider Badge**
- Position: Centered horizontally between Top and Bottom Outfit Cards
- Shape: Pill container, 36pt height, background `#1C1C1E`, border 1pt `rgba(255,255,255,0.12)`
- Text: "VS" in SF Pro Text 14pt w700 `#FFFFFF`

**Profile Stat Card**
- Background: `#1C1C1E`
- Corner radius: 18pt
- Displays: "VOTES CAST" and "STYLE WIN-RATE (%)" side-by-side with vertical 1pt hairline divider `#2C2C2E`

### Navigation

**Bottom Tab Bar**
- Height: 52pt + safe area
- Background: `#000000` (opaque true black, no blur)
- Tabs: Battles, Upload, Leaderboard, Profile
- Icon size: 26pt
- Active: `#FFFFFF` filled glyph; Inactive: `rgba(255,255,255,0.45)` outline
- Labels: SF Pro Text 10pt w600
- Top hairline: `rgba(255,255,255,0.08)` 0.5pt

**Top Bar (Battle Arena)**
- Height: 48pt + safe area
- Left: "VERSED" wordmark (lowercase/bold, 18pt w700 `#FFFFFF`)
- Center: Category filter pill (e.g. "Streetwear", "All")
- Right: Current user streak badge ("🔥 12")

### Input Fields

**Caption / Tag Field**
- Background: transparent (overlaid on black or sheet)
- Placeholder: "Add style tags (#streetwear, #thrift)…", 16pt w400 `#8E8E93`
- Text: `#FFFFFF` 16pt
- No border, single line, centered

### Distinctive Components

**Hot Streak Banner**
- Full-width pill at the top of an outfit card during high-streak duels
- Background: `rgba(0,0,0,0.6)` with light blur, 1pt `rgba(255,215,10,0.4)` amber border
- Text: "🔥 ON FIRE — 10 Wins in a row" — amber `#FFD60A`

**Authenticity / Streak Tag**
- Inline pill next to handle: "🔥 10 STREAK"
- Background: transparent; text + glyph in amber `#FFD60A`, 12pt w700

## 5. Layout Principles

### Spacing System
- Base unit: 4pt
- Scale: 4, 8, 12, 16, 20, 24, 32, 40, 52, 76
- Standard margin: 16pt horizontal for text; outfit battle cards go **edge-to-edge** (0pt)
- Battle feed vertical rhythm: 12pt gap between Top Card, VS Divider, and Bottom Card

### Grid & Container
- Content width: full device width; cards are full-bleed, text content inset 16pt
- Profile grid: 3-column outfit thumbnail grid, 2pt gap

### Whitespace Philosophy
- **The photo owns the screen**: Two outfits max per viewport in battle mode — no cluttered lists
- **Minimal chrome**: Almost no padding or boxing; text floats directly on black
- **Dense only in history grid**: Profile history is intentionally tight like a contact sheet

### Border Radius Scale
- Square (0pt): Almost nothing — VERSED avoids hard squares
- Tiny (6pt): Profile grid thumbnails
- Card (18pt): The 1v1 outfit battle cards
- Comfortable (24pt): Bottom sheets, modals
- Full Pill (500pt): Primary/secondary buttons, VS divider, search bar
- Circle (50%): Avatars, upload FAB ring

## 6. Depth & Elevation

| Level | Treatment | Use |
|-------|-----------|-----|
| Flat (Level 0) | No shadow | Text on canvas, tab bar, battle background |
| Card (Level 1) | `rgba(0,0,0,0.6) 0 8px 24px` | Outfit cards lift off black |
| Sheet (Level 3) | `rgba(0,0,0,0.8) 0 -16px 48px` | Upload sheet, category filters, comments sheet |
| Blur Overlay | `rgba(0,0,0,0.5)` + backdrop-blur 30 | Streak banner, full-screen image inspect |

**Shadow Philosophy**: Because the canvas is pure black, shadows register through high opacity (0.6–0.8) and generous blur so white card edges separate from the void. There are no colored glows.

### Motion
- **Vote Submission**: Tapping Card A causes Card B to fade out (150ms), Card A briefly highlights with a 1.02 scale bump, then two new contender cards slide in vertically over 300ms ease-out, paired with heavy haptic `.impactOccurred(.heavy)`.
- **Card Selection**: 0.3s spring animation (damping 0.75).

## 7. Do's and Don'ts

### Do
- Use pure black `#000000` as the canvas — true black darkroom feel
- Keep the UI monochrome — white is the only accent; amber is reserved for active win streaks
- Make 1v1 outfit cards the hero of the battle screen
- Surface genuine performance metrics: "Votes Cast", "Style Win-Rate (%)", "🔥 Streaks"
- Render stats with tabular numerals so values update smoothly
- Pair vote taps with heavy haptics for physical feedback

### Don't
- Don't introduce a brand accent color — the lack of one *is* the brand
- Don't use warm-black (`#121212`) — VERSED is true `#000000`
- Don't add vanity like counts, follower numbers, or social clout scores
- Don't beautify with gradients, glows, or soft light overlays
- Don't add a light mode — it breaks the darkroom aesthetic
- Don't use a custom display font — system SF Pro only

## 8. Responsive Behavior

### Device Sizes
| Device | Width | Key Changes |
|--------|-------|-------------|
| iPhone SE (3rd gen) | 375pt | Outfit cards scaled to 1:1 aspect ratio to fit viewport |
| iPhone 13/14/15 | 390pt | Standard 4:5 vertical card aspect ratio |
| iPhone 15/16 Pro | 393pt | Dynamic Island clears top bar |
| iPhone 15/16 Pro Max | 430pt | Max card height 340pt; profile grid stays 3-col |

### Orientation
- All screens: **portrait-locked** — VERSED is a mobile-first portrait experience.

### Touch Targets
- Outfit Cards: Full card area is tap-vulnerable for voting
- Upload FAB: 76pt — unmissable CTA
- Tab icons: 26pt glyph, 44pt effective hit

## 9. Native iOS Implementation Guidelines (Flutter)

To ensure VERSED feels like an authentic, native iOS application built with Swift/UIKit rather than a generic cross-platform web view, all Flutter implementations must strictly adhere to native Apple behaviors:

### 1. Motion & Scroll Physics
- **Bouncing Overscroll:** All scroll views (`ListView`, `GridView`, `SingleChildScrollView`) MUST use `BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics())`. Never use Material ink ripples or Android stretch glow physics.
- **Edge-Swipe Back Navigation:** Page navigation must use `CupertinoPageTransitionsBuilder` so users can perform the iOS edge-swipe back gesture to pop screens.
- **Spring Animations:** Modal presentations and card transitions must use spring physics (`CupertinoWithAppleMotion` or `SpringSimulation` with damping ~0.75).

### 2. Physical Acoustics & Taptic Feedback
- **Card Vote Tap:** Trigger `HapticFeedback.heavyImpact()` on every outfit card vote to give the selection physical weight.
- **Tab Change:** Trigger `HapticFeedback.selectionClick()` when switching bottom bar tabs.
- **Modal Trigger:** Trigger `HapticFeedback.mediumImpact()` when opening the upload sheet or action dialogs.

### 3. Native Dialogs & Modals
- Bottom action sheets and confirmation popups MUST use `showCupertinoModalPopup` with `CupertinoActionSheet` rather than Material bottom sheets.
- Destructive actions ("Delete Fit") must be styled with `isDestructiveAction: true` (`#FF453A` red text).

### 4. Native Typography & System Fallback
- Do not ship custom fonts for standard text — allow Flutter to use system `-apple-system` / `SF Pro Text` / `SF Pro Display`.
- All updating numerical values (Win-Rate %, Vote Counts, Timer) MUST enable tabular figures using `FontFeature.tabularFigures()` so text layout doesn't jitter during updates.

### 5. SafeArea & Screen Insets
- All screen roots MUST respect `SafeArea` margins for the Dynamic Island / Notch and the bottom Home Indicator bar.
- The bottom navigation bar must sit above the Home Indicator with full true-black padding extending to the screen edge.

## 10. Agent / Developer Quick Reference

### Quick Color Reference
- Canvas: `#000000`
- Surface 1 (sheets): `#1C1C1E`
- Surface 2 (rows/chips): `#2C2C2E`
- Divider: `#2C2C2E`
- Primary text: `#FFFFFF`
- Secondary text: `#8E8E93`
- Tertiary text: `#636366`
- Accent (action): `#FFFFFF`
- On-accent: `#000000`
- Streak amber: `#FFD60A`
- Error red: `#FF453A`