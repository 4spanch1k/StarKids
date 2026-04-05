# Flutter Design System

## 1. Semantic token map

### brand

- `brand.primary`: `#EB0876`
- `brand.primaryPressed`: `#C70662`
- `brand.secondary`: `#09A284`
- `brand.accent`: `#F29F24`
- `brand.highlight`: `#FAEB0B`

### action

- `action.primaryBg`: `#EB0876`
- `action.primaryPressed`: `#C70662`
- `action.primaryFg`: `#FFFFFF`
- `action.secondaryBg`: `#FFFFFF`
- `action.secondaryPressed`: `#FFF1E3`
- `action.secondaryFg`: `#171316`
- `action.ghostFg`: `#EB0876`
- `action.disabledBg`: `#F2E8ED`
- `action.disabledFg`: `#C9C1C8`

### surface

- `surface.canvas`: `#FFF8F1`
- `surface.primary`: `#FFFFFF`
- `surface.secondary`: `#FFF1E3`
- `surface.tertiary`: `#FCE3EF`
- `surface.inverse`: `#171316`

### text

- `text.primary`: `#171316`
- `text.secondary`: `#6E6572`
- `text.inverse`: `#FFFFFF`
- `text.onHighlight`: `#171316`
- `text.disabled`: `#A69EA6`

### border

- `border.default`: `#E9DDE4`
- `border.strong`: `#DCC5D3`
- `border.focus`: `#EB0876`
- `border.error`: `#D6455D`

### status

- `status.success`: `#1C9A6D`
- `status.successSurface`: `#E6F7F0`
- `status.warning`: `#F29F24`
- `status.warningSurface`: `#FFF2E2`
- `status.error`: `#D6455D`
- `status.errorSurface`: `#FDEBED`

### overlay

- `overlay.scrim`: `#17131699`
- `overlay.imageTop`: `#17131633`
- `overlay.imageBottom`: `#17131680`

## 2. Component states matrix

### Primary button

| State | Background | Foreground | Border | Shadow |
|---|---|---|---|---|
| Default | `brand.primary` | `text.inverse` | none | depth 1 |
| Pressed | `brand.primaryPressed` | `text.inverse` | none | depth 0 |
| Disabled | `action.disabledBg` | `action.disabledFg` | none | none |
| Loading | `brand.primary` | `text.inverse` | none | depth 1 |

### Secondary button

| State | Background | Foreground | Border | Shadow |
|---|---|---|---|---|
| Default | `surface.primary` | `text.primary` | `border.default` | none |
| Pressed | `surface.secondary` | `text.primary` | `border.default` | none |
| Disabled | `surface.secondary` | `action.disabledFg` | `border.default` | none |

### Ghost button

| State | Background | Foreground | Border |
|---|---|---|---|
| Default | transparent | `brand.primary` | none |
| Pressed | `surface.tertiary` | `brand.primaryPressed` | none |
| Disabled | transparent | `action.disabledFg` | none |

### Input field

| State | Fill | Text | Border | Helper |
|---|---|---|---|---|
| Default | `surface.primary` | `text.primary` | `border.default` 1px | `text.secondary` |
| Focused | `surface.primary` | `text.primary` | `border.focus` 2px | `brand.primary` |
| Error | `surface.primary` | `text.primary` | `border.error` 2px | `status.error` |
| Disabled | `surface.secondary` | `text.disabled` | `border.default` 1px | `text.disabled` |

### Select field

Same shell as input field plus chevron icon on the trailing edge.

### Chips

| State | Fill | Text | Border |
|---|---|---|---|
| Default | `surface.secondary` | `text.primary` | none |
| Selected | `surface.tertiary` | `brand.primary` | none |
| Disabled | `#F5EDF1` | `text.disabled` | none |

### Promo card

| State | Surface | Overlay | CTA |
|---|---|---|---|
| Default | `surface.primary` | none or image bottom scrim | primary |
| Pressed | `surface.secondary` | same | primary pressed |
| Featured | `surface.primary` with `highlight` price chip | image bottom scrim | primary |

### Birthday package card

| State | Surface | Price chip | Border |
|---|---|---|---|
| Default | `surface.primary` | `highlight` | `border.default` |
| Selected/featured | `surface.primary` | `highlight` | `brand.primary` |

### Bottom nav item

| State | Indicator | Icon | Label |
|---|---|---|---|
| Inactive | transparent | `text.secondary` | `text.secondary` |
| Active | `surface.tertiary` | `brand.primary` | `brand.primary` |

## 3. Icon system

- Style: rounded, minimal, Material symbols or Cupertino equivalents with soft geometry.
- Sizes:
  - `16`: inline metadata
  - `20`: chips, field suffix/prefix
  - `24`: navigation, app bars, primary actions
  - `32`: feature highlights, empty states
- Required:
  - form feedback
  - map/call/WhatsApp quick actions
  - bottom navigation
  - facility metadata
- Optional:
  - section headers
  - promo cards when the image already carries meaning
- Do not use icons as decoration without semantic value.

## 4. Image system

- Hero image ratio: `4:5` or `3:4`
- Gallery image ratio: `4:5`
- Promo image ratio: `16:10`
- Branch cover ratio: `16:10`
- Hero radius: `32`
- Gallery radius: `12`
- Promo radius: `20`
- Use image bottom overlay only when text sits on top of a photo.
- Never add colored overlays strong enough to distort real park colors.
- Hero images must prioritize real children, attractions, birthday scenes, or branch interiors.
- Gallery images stay clean, edge-to-edge, and without heavy labels.

## 5. Flutter implementation plan

### `app/theme`

- `app_theme.dart`: public entrypoint
- `star_kids_theme.dart`: builds `ThemeData`
- `star_kids_text_theme.dart`: text theme factory
- `star_kids_component_theme.dart`: button, input, snack, nav, app bar themes

### `core/design_system/foundations`

- `star_kids_colors.dart`
- `star_kids_spacing.dart`
- `star_kids_radii.dart`
- `star_kids_shadows.dart`
- `star_kids_icon_sizes.dart`

### `core/design_system/widgets`

- `star_kids_button.dart`
- `star_kids_input_field.dart`
- `star_kids_select_field.dart`
- `star_kids_section_header.dart`
- `star_kids_bottom_cta_bar.dart`

### naming conventions

- foundations: `StarKidsColors`, `StarKidsSpacing`
- widgets: `StarKidsButton`, `StarKidsInputField`
- private helpers inside widgets use `_` prefix only

### ownership rules

- tokens and theme factories never live in feature modules
- reusable UI primitives live in `core/design_system/widgets`
- business-specific blocks like `BirthdayHeroSection` stay inside their feature package

## 6. MVP-first implementation scope

Build now:

- color tokens
- text styles
- spacing
- radii
- shadows
- app theme
- buttons
- inputs
- section header
- bottom CTA bar

Delay:

- advanced promo variants
- custom loaders
- custom icon pack
- ornamental animation components
