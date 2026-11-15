---
name: Raksha Kawach
colors:
  surface: '#f9faf7'
  surface-dim: '#d9dad7'
  surface-bright: '#f9faf7'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f3f4f1'
  surface-container: '#edeeeb'
  surface-container-high: '#e7e8e6'
  surface-container-highest: '#e2e3e0'
  on-surface: '#191c1b'
  on-surface-variant: '#42493b'
  inverse-surface: '#2e312f'
  inverse-on-surface: '#f0f1ee'
  outline: '#727a69'
  outline-variant: '#c2c9b6'
  surface-tint: '#386a0b'
  primary: '#386a0b'
  on-primary: '#ffffff'
  primary-container: '#83bc57'
  on-primary-container: '#224a00'
  inverse-primary: '#9cd76e'
  secondary: '#5f5e5e'
  on-secondary: '#ffffff'
  secondary-container: '#e2dfde'
  on-secondary-container: '#636262'
  tertiary: '#036d38'
  on-tertiary: '#ffffff'
  tertiary-container: '#67bf80'
  on-tertiary-container: '#004b24'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#b7f487'
  primary-fixed-dim: '#9cd76e'
  on-primary-fixed: '#0b2000'
  on-primary-fixed-variant: '#265100'
  secondary-fixed: '#e5e2e1'
  secondary-fixed-dim: '#c8c6c5'
  on-secondary-fixed: '#1c1b1b'
  on-secondary-fixed-variant: '#474746'
  tertiary-fixed: '#9cf6b3'
  tertiary-fixed-dim: '#80d998'
  on-tertiary-fixed: '#00210d'
  on-tertiary-fixed-variant: '#005228'
  background: '#f9faf7'
  on-background: '#191c1b'
  surface-variant: '#e2e3e0'
typography:
  display:
    fontFamily: Plus Jakarta Sans
    fontSize: 34px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.03em
  headline-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 26px
    fontWeight: '600'
    lineHeight: 32px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 26px
    letterSpacing: -0.015em
  headline-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 17px
    fontWeight: '600'
    lineHeight: 22px
    letterSpacing: -0.01em
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
    letterSpacing: -0.01em
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
    letterSpacing: 0em
  body-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
    letterSpacing: 0.01em
  label-lg:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 18px
    letterSpacing: 0.01em
  label-md:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.02em
  label-sm:
    fontFamily: Inter
    fontSize: 10px
    fontWeight: '600'
    lineHeight: 12px
    letterSpacing: 0.04em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  gutter-sm: 0.75rem
  margin: 1.25rem
  margin-compact: 1rem
  space-xxs: 0.25rem
  space-xs: 0.5rem
  space-sm: 0.75rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2rem
  space-2xl: 2.5rem
---

## Brand & Style

This design system establishes a high-trust, protective, and frictionless interface for student transit safety, geofenced presence verification, and fleet oversight. Tailored for higher-education students, campus transport administrators, and concerned parents, the UI must balance absolute operational reliability with the effortless polish of contemporary Nordic digital products.

The aesthetic fuses **Modern Nordic Minimalism** with precise **Functional Utility**. Generous whitespace, razor-sharp typography, and restrained tactile surfaces replace unnecessary ornamentation. The interface communicates instantaneous status verification through quiet confidence rather than alarming alerts, turning daily transit check-ins into an intuitive, zero-anxiety background routine.

## Colors

The color architecture is built around crisp contrast, high legibility in variable outdoor light conditions, and intentional semantic cues.

- **Primary Accent (`#83BC57`):** Represents verified status, active geofence beacons, dynamic CTA states, and key navigational paths. It serves as the primary visual anchor across transit timelines.
- **Deep Neutral Base (`#171717`):** Applied to primary typography, hero headers, dynamic state sheets, and key navigation surfaces to establish authority and high contrast against bright daylight.
- **Background & Canvas (`#FFFFFF` / `#F5F6F3`):** Pure white serves as the top-level card plane, while Surface Grey (`#F5F6F3`) forms the architectural backdrop, separating data groupings without heavy drop shadows.
- **Supporting Semantics:**
  - **Muted Elements (`#969696`):** Secondary timestamps, bus route meta-tags, and inactive state indicators.
  - **Structural Border (`#E8EBE6`):** Subtle outline dividers that enforce layout rigor without visual clutter.
  - **Functional Accents:** Warning (`#E6A34B`) for route deviations or schedule delays, and Danger (`#DF6868`) strictly for anti-proxy alerts, missed stops, or SOS triggers.

## Typography

Typography prioritizes swift scanning under transit conditions. Heading levels utilize Plus Jakarta Sans to deliver an approachable, geometric clarity akin to contemporary transit signage. Body and metadata levels rely on Inter for its optical neutrality, tabular numeric support, and micro-legibility.

- **Numerics:** All numeric time indicators, distance trackers, and bus IDs must use tabular lining figures (`font-variant-numeric: tabular-nums`) to prevent horizontal jitter during live GPS updates.
- **Hierarchy:** Reserve `display` strictly for onboarding screens, pass validation headers, or critical trip status summaries. Keep metadata in `body-sm` or `label-sm` with slight uppercase tracking to provide crisp structural definition.

## Layout & Spacing

The layout is optimized for single-thumb Android interaction across standard portrait viewports (390×844px baseline). 

- **Grid Architecture:** 4-column fluid mobile grid with `1.25rem` (20px) outer canvas margins and `1rem` (16px) column gutters.
- **Vertical Rhythm:** Built on an 8pt baseline grid with an integrated 4pt micro-scale for compact tags and status indicators.
- **Interactive Thumb Zones:** Primary action triggers, biometric verification touchpoints, and sheet grab points must inhabit the lower 40% of the screen height. Live map viewports and route topology anchor the upper 60%.
- **Safe Area Insets:** Account for standard Android edge-to-edge gestures and camera cutouts with a minimum safe top padding of `2.75rem` and bottom padding of `2rem`.

## Elevation & Depth

This system avoids deep blur drop-shadows and skeuomorphic bevels, choosing instead an editorial layering strategy defined by tonal containment and hairline perimeter borders.

- **Base Layer (Level 0):** Background surface in `#F5F6F3` hosting persistent maps or static layouts.
- **Card Surfaces (Level 1):** Solid `#FFFFFF` surfaces delineated by an exact `1px` border of `#E8EBE6`. Shadows are strictly soft ambient diffusions: `0 4px 16px -2px rgba(23, 23, 23, 0.04)`.
- **Interactive Modals & Floating Cards (Level 2):** Bottom sheets and floating map status overlays sit on `#FFFFFF` with a heightened diffusion: `0 12px 32px -4px rgba(23, 23, 23, 0.08)` and an upper hairline outline.
- **Anti-Proxy Identity Overlays (Level 3):** Full-screen dynamic verification sheets employ a high-translucency charcoal backdrop (`rgba(23, 23, 23, 0.6)`) paired with `backdrop-filter: blur(8px)`.

## Shapes

The geometric signature combines generous, organic card corners with pill-shaped data pills.

- **Cards and Containers:** Feature a baseline corner radius of `1.125rem` (18px) to `1.5rem` (24px), providing a tactile, hand-held card appearance reminiscent of physical student credentials.
- **Pills and Badges:** Strict 9999px fully rounded geometry for route codes, live status badges, and geofence indicators.
- **Action Triggers:** Buttons and text entry containers adhere to `1.125rem` (18px) rounding to harmonize with card architectures while remaining distinctly tappable.

## Components

### Buttons & Interactive Controls
- **Primary Action (Board / Verify):** Surface filled with Dark Charcoal (`#171717`) or Primary Green (`#83BC57`), text in contrasting bold label typography, height `54px`, radius `18px`. Active tap scales down subtly (`scale(0.98)`).
- **Secondary Action (View Schedule / Route Details):** Background `#FFFFFF`, `1px` solid `#E8EBE6` border, text `#171717`.
- **Destructive / SOS Action:** Deep danger fill (`#DF6868`) or ghost red tint with high-contrast text, accompanied by deliberate swipe-to-activate patterns to prevent accidental triggers.

### Badges & Pill Chips
- **Live Status Chip:** Pill shape (`9999px`), `4px 10px` interior padding. Verified / On-Bus states utilize a `10%` tint of `#83BC57` with solid `#4FA76B` text and an animated 6px pulsing presence dot.
- **Bus & Seat Identifiers:** Dark Charcoal (`#171717`) background with white bold mono/sans text for high-concurrency visual recognition.

### Transit & Verification Cards
- **Live Route Card:** Elevated Level 1 surface, 20px padding, 20px radius. Contains a vertical step line showing previous, active, and upcoming transit stops, annotated with real-time ETA countdowns.
- **Anti-Proxy Identity Card:** Features dynamic high-frequency cryptographic QR codes, animated watermarks, dynamic timestamps, and biometric match confirmation indicators, framed within a 24px rounded card with an outer `#E8EBE6` boundary.

### Input Fields & Search
- **Route Search & Stop Selectors:** Height `48px`, background `#FFFFFF`, radius `18px`, `1px` border in `#E8EBE6`. Focused state activates a `1.5px` border in `#171717`. Left-anchored minimalist outline icons in `#969696`.

### List Items
- **Stop & Passenger Rosters:** Separated by zero-margin dividers (`#E8EBE6`, `0.5px`). Left side displays student avatar or stop sequence node, center displays primary and secondary text, right side houses attendance verification timestamp chips.