# CareFlow Design System

Read this before any UI change. The rules below are enforced by the shared
tokens in `lib/utils/app_colors.dart` and `lib/utils/app_tokens.dart`, and by
the component themes in `lib/utils/app_theme.dart`.

## 1. Brand

The mark is the supplied heart/flow artwork in
`assets/branding/careflow-logo.svg`. It is two blues on a transparent 256×256
canvas:

- `#2563EB` — primary accent
- `#3B82F6` — highlight / secondary path

The UI uses **one** accent: `#2563EB`. Teal, mint and extra blues are retired as
brand accents. Semantic success/warning/error colours are only used when they
carry meaning.

## 2. Colour

| Role | Light | Dark |
| --- | --- | --- |
| Canvas | `#F5F7FB` | `#0C1220` |
| Surface | `#FFFFFF` | `#141C2B` |
| Muted surface | `#EDF1F7` | `#1B2536` |
| Text primary | `#111827` | `#F2F5FA` |
| Text secondary | `#5B6575` | `#A7B0C0` |
| Text tertiary | `#667085` | `#7D8798` |
| Border | `#DDE3ED` | `#263246` |
| Divider | `#EBEFF6` | `#1B2536` |
| Accent | `#2563EB` | `#2563EB` |
| Accent soft | `#E8F0FE` | `#1B2C52` |
| Success | `#0E9F6E` / text `#047857` | `#6EE7B7` on `#0D2E25` |
| Warning | `#B45309` / text `#92400E` | `#FCD34D` on `#38260B` |
| Error | `#D92D20` / text `#B42318` | `#FCA5A5` on `#3B1715` |

Rules:

- 60 % tinted neutral canvas, 30 % surface, 10 % accent.
- Never pure `#000` or `#FFF` for text; tables above are the only text colours.
- Body text must stay at or above 4.5:1 contrast.
- No gradients. No glows. No decorative colour.
- Dark mode inherits the same roles through `Theme.of(context)`.

## 3. Spacing — 8 pt grid

Only these values: `4, 8, 12, 16, 24, 32, 48` (`AppSpacing.xs` … `.xxxl`).

| Relationship | Value |
| --- | --- |
| Screen gutter | 16 |
| Gap between cards | 12 |
| Gap inside cards | 12 or 16 |
| Label → field | 8 |
| Section → section | 24 |
| Icon → label | 8 or 12 |
| Page top / bottom padding | 16 |

Use one rhythm per screen. Do not mix 10/14/18 as gaps.

## 4. Radius — three values

| Token | Value | Use |
| --- | --- | --- |
| `AppRadius.sm` | 8 | badges, icon tiles, small controls |
| `AppRadius.md` | 12 | cards, inputs, buttons, avatars |
| `AppRadius.lg` | 20 | dialogs, bottom sheets |

No pills on ordinary containers, no 13/14/16/25 one-offs.

## 5. Elevation — two presets

- `AppShadows.soft` — 6 % tinted blue-black, blur 16, y +4.
- `AppShadows.raised` — 10 % tinted blue-black, blur 24, y +8.

Default surfaces use a 1 px border and **no shadow**. Shadows are reserved for
genuine overlays (dialogs, sheets, floating action surfaces). Dark mode uses
no card shadows.

## 6. Typography

Six roles, three weights (400 / 600 / 700):

| Role | Size / line-height | Weight |
| --- | --- | --- |
| Display | 24 / 1.2 | 700 |
| Title (app bar, page) | 20 / 1.25 | 700 |
| Section | 15 / 1.3 | 700 |
| Body | 14 / 1.45 | 400 |
| Label (buttons, fields, list titles) | 13 / 1.3 | 600 |
| Caption (metadata, hints) | 12 / 1.35 | 400 |

No w500/w800/w900. No 9, 10, 11, 13.5, 14.5, 18.5 sizes.

## 7. Icons and targets

- One family: Material rounded icons (`Icons.*_rounded`).
- Sizes: 16 (inline), 20 (controls/app bar), 24 (tiles), 32 (hero/empty).
- Minimum touch target: **48 × 48 dp**.
- Icon-only buttons need a tooltip.

## 8. Components

- **AppCard** — surface, 1 px border, 12 radius, 16 padding, no shadow.
- **Buttons** — 48 dp high, 12 radius, primary filled for the one main action,
  outlined/text for secondary actions.
- **Inputs** — 48 dp, 12 radius, label outside above the field (8 gap), hint in
  text tertiary.
- **Badges** — 8 radius, 11 px w600, tinted background, no pill.
- **AppEmptyState** — icon tile, title, one sentence, optional single action.
- **AppSectionHeader** — section title + one quiet text action.
- **Dialogs / sheets** — 20 radius, 24 inset, no shadow colour other than
  theme elevation.
- **Bottom bars** — top border only, safe-area padding, one primary action.

## 9. Layout rules

- Start-align content; centre only compact empty states and dialog bodies.
- Group with spacing and hairline dividers, not nested cards.
- No card inside card.
- One clear primary action per screen; secondary actions quieter.
- Never fix the height/width of a text container. Use `Expanded`, `Flexible`,
  `Wrap`, `maxLines`, `TextOverflow.ellipsis`, `LayoutBuilder` and
  `SingleChildScrollView`.
- Respect `SafeArea` and keyboard insets.
- If the app is localised RTL later, use `EdgeInsetsDirectional`,
  `AlignmentDirectional`, and `start`/`end`.

## 10. Voice

Calm, clinical, human. Sentence case for headings and buttons. No exclamation
marks, no marketing superlatives, no emoji as icons.
