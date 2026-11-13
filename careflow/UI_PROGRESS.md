# CareFlow UI Polish — Progress

Status key: `[ ]` todo · `[~]` in progress · `[x]` done and analyzed

## Phase 0 — Audit (baseline recorded)

- [x] List every screen, shared widget and auth/empty state
- [x] Grep hard-coded colors, font sizes, paddings, radii, shadows, magic numbers
- [x] Run `flutter analyze` (baseline: 0 errors, 0 warnings, 6 info deprecations)
- [x] Write 10-line inconsistency summary (below)
- [x] Create `UI_PROGRESS.md`

### Baseline `flutter analyze`

```
6 issues found (all info / deprecated_member_use):
base_map_screen.dart:92  desiredAccuracy
map_picker_screen.dart:65 desiredAccuracy
map_picker_screen.dart:66 timeLimit
ai_service.dart:285       desiredAccuracy
speech_service.dart:45    listenFor
speech_service.dart:46    pauseFor
```

### Audit: most common values / inconsistencies

1. **Colors:** 121 inline `Color(0xFF…)` literals; blue `#2563EB` plus teal `#0D9488`, mint `#10B981`, info `#0284C7` all compete as accents. 18 copies each of `#134E4A` (teal container) and `#1E3A8A` (blue container).
2. **Font sizes:** 19 distinct sizes (9–25), with 257 inline `fontSize:` declarations and weights w500/w600/w700/w800/w900 mixed on the same hierarchy level.
3. **Radii:** 15 distinct values (4, 6, 8, 9, 10, 11, 12, 13, 14, 15, 16, 20, 25, 30, 999); identical cards use 12/13/14/16 in different files.
4. **Spacing:** 189 `EdgeInsets` with many one-off values (3, 6, 7, 9, 10, 11, 13, 14, 18, 20, 22); screen padding alternates 16/18/20.
5. **Elevation:** 11 inline `BoxShadow`s with 3–22% opacity and black/blue tints; cards sometimes border-only, sometimes shadow+border.
6. **App bars:** every screen repeats `backgroundColor: cardColor` + a manual 1 px divider; some use `AppBarTheme`, some override it.
7. **Duplication:** avatar initials, section headers, empty states, loading spinners, and primary button min-heights are re-implemented in almost every screen.
8. **Hierarchy:** several screens have 3–4 equally loud actions; primary vs secondary actions are not visually distinct.
9. **Accessibility:** some touch targets are 32–38 dp; body/label contrast is generally fine, but `textTertiary` on white is below 4.5:1 for small text.
10. **Brand:** in-app mark (invented teal cross) does not match the supplied heart/flow logo; splash, icon and UI speak three different brand languages.

## Phase 0.5 — Logo and app icon

- [x] Copy source SVG to `assets/branding/careflow-logo.svg` (original untouched)
- [x] Record logo colors, shapes, viewBox, transparency (256×256, heart/flow, `#2563EB` + `#3B82F6`, transparent)
- [x] Register `assets/branding/` in `pubspec.yaml`
- [x] Produce `app_icon.png` (1024², opaque, padded)
- [x] Produce `app_icon_foreground.png` (1024², transparent, 574 px art inside central 60% safe zone)
- [x] Produce `app_icon_monochrome.png` (transparent silhouette)
- [x] Add `flutter_launcher_icons` dev dependency + config
- [x] Run `dart run flutter_launcher_icons`
- [x] Verify Android mipmaps / iOS appiconset / AndroidManifest / no default Flutter icon
- [x] Align in-app `CareFlowLogo` with supplied source mark

## Phase 1 — Design tokens + DESIGN.md

- [x] Spacing scale (4/8/12/16/24/32/48) in `AppSpacing`
- [x] Radius scale (8/12/20) in `AppRadius`
- [x] Shadow presets (2) in `AppShadows`
- [x] Color tokens derived from logo blue + tinted neutrals + semantics
- [x] Typography scale (6 styles, 3 weights) in `AppTypography`
- [x] Icon sizes (16/20/24) + single icon family
- [x] Wire ThemeData + component themes (AppBar, buttons, inputs, cards, dialogs, sheets, chips, list tiles, nav)
- [x] Write `DESIGN.md`
- [x] Add “Read DESIGN.md before any UI change.” to `AGENTS.md`

## Phase 2 — Shared components

- [x] `AppCard` (border-first, optional soft elevation)
- [x] `ActionButton`
- [x] `AppBadge`
- [x] `StarRatingWidget`
- [x] `CareFlowLogo`
- [x] `AppEmptyState` (new shared state block)
- [x] `AppSectionHeader` (new shared section header)
- [x] Feedback dialog styling — token Dialog, neutral rating panel, keyboard-aware padding
- [x] Remove one-off duplicated state/header/button styling (moving to Phase 3 per screen)

## Phase 3 — Screen checklist

### Auth & entry
- [x] Auth loading screen (`_AuthLoadingScreen`) — token spinner, shared surface
- [x] Auth error screen (profile load failure) — `AppEmptyState`, scroll-safe error text
- [x] Doctor account-under-review screen — `AppEmptyState` warning tone, dark-aware tint
- [x] Unknown profile screen — `AppEmptyState`, safe-area + scroll
- [x] Guest home — one accent, 2-line specialty labels, wrapping hero chips
- [x] Login — compact brand row, token form, wrapped register link, 48 dp primary
- [x] Signup — segmented role control, token fields, wrapped login link

### Patient
- [x] Patient home shell (bottom nav, unread badge) — theme nav, bordered card surface, 99+ cap
- [x] Patient dashboard content — shared service cards, token layout, wrapped empty banner
- [x] Doctor search — theme app bar, scrollable filters, avatar/badge cards, shared empty states
- [x] Doctor details / booking — section headers, wrapped actions, 48 dp slots, sticky booking bar
- [x] Doctors list — shared avatar/card/empty state, wrapped metadata
- [x] Patient map + map bottom sheet — relocated location button, stacked bottom actions
- [x] AI voice chat / triage — token header/bubbles, semantic banner, 48 dp composer
- [x] Schedule & history — segmented tabs, shared cards/empty state, wrapped dates
- [x] Chats list — token search, avatar unread dot, shared empty state
- [x] Chat room — compact app bar, token bubbles, themed composer
- [x] Profile / account settings

### Doctor
- [x] Doctor home shell (bottom nav, request badge)
- [x] Doctor dashboard
- [x] Pending requests
- [x] Patient reviews
- [x] Manage availability slots
- [x] Signup clinic map picker
- [x] Doctor map / base map

### Admin
- [x] Admin dashboard / doctor verification

### Cross-screen
- [x] Feedback rating dialog — token Dialog, neutral rating panel, keyboard-aware padding
- [x] All dialogs, snackbars, empty/loading/error states — semantic colors, AppRadius.lg, AppSpacing scale
- [x] Overflow tests at 320×568, 360×640, 412×915 × textScale 1.0/1.5 — 20 tests passing
