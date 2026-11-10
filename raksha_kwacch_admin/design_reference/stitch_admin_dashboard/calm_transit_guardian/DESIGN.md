---
name: Calm Transit Guardian
colors:
  surface: '#f8f9ff'
  surface-dim: '#cbdbf5'
  surface-bright: '#f8f9ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#eff4ff'
  surface-container: '#e5eeff'
  surface-container-high: '#dce9ff'
  surface-container-highest: '#d3e4fe'
  on-surface: '#0b1c30'
  on-surface-variant: '#564241'
  inverse-surface: '#213145'
  inverse-on-surface: '#eaf1ff'
  outline: '#8a7171'
  outline-variant: '#ddc0bf'
  surface-tint: '#a43a40'
  primary: '#a43a40'
  on-primary: '#ffffff'
  primary-container: '#e56b6f'
  on-primary-container: '#5c0111'
  inverse-primary: '#ffb3b3'
  secondary: '#575e70'
  on-secondary: '#ffffff'
  secondary-container: '#d9dff5'
  on-secondary-container: '#5c6274'
  tertiary: '#655c5d'
  on-tertiary: '#ffffff'
  tertiary-container: '#998e8f'
  on-tertiary-container: '#2f2829'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#ffdad9'
  primary-fixed-dim: '#ffb3b3'
  on-primary-fixed: '#410009'
  on-primary-fixed-variant: '#84222b'
  secondary-fixed: '#dce2f7'
  secondary-fixed-dim: '#c0c6db'
  on-secondary-fixed: '#141b2b'
  on-secondary-fixed-variant: '#404758'
  tertiary-fixed: '#eddfe0'
  tertiary-fixed-dim: '#d0c3c5'
  on-tertiary-fixed: '#211a1b'
  on-tertiary-fixed-variant: '#4d4546'
  background: '#f8f9ff'
  on-background: '#0b1c30'
  surface-variant: '#d3e4fe'
typography:
  display:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 40px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
    letterSpacing: -0.015em
  headline-md:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
    letterSpacing: -0.01em
  headline-sm:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '600'
    lineHeight: 24px
    letterSpacing: -0.005em
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  body-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
  label-lg:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
  label-md:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
  label-sm:
    fontFamily: Inter
    fontSize: 11px
    fontWeight: '600'
    lineHeight: 14px
    letterSpacing: 0.02em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  gutter-desktop: 1.5rem
  margin: 1rem
  margin-desktop: 2rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2rem
---

## Brand & Style

The design system is structured for school transport operators, school administrators, and concerned parents who need immediate clarity without visual fatigue. The overarching tone is dependable, humane, and tranquil. It strips away alarmist, militaristic fleet-telematics patterns in favor of a quiet, workspace-grade utility reminiscent of high-focus software productivity tools. 

Visual style choices follow a refined Modern Minimalist approach:
- High signal-to-noise ratio with unencumbered whitespace and crisp, purposeful structural dividers.
- Warm, protective brand accents counterbalanced by cool, slate-tinted canvas neutrals to convey safety and administrative composure.
- Grounded, human-scale density designed to handle dense rosters, live routes, and status logs without visual clutter.

## Colors

The palette establishes an orderly, quiet workspace environment where vital telematics, student manifests, and route milestones stand out naturally.

- **Canvas & Surfaces**: The base canvas is `#F8FAFC`, while cards, structural drawers, and sidebars utilize pure `#FFFFFF` to produce distinct, calm elevation steps.
- **Brand Accent**: `#E56B6F` provides a compassionate, protective primary action color, paired with `#FFF1F2` for softly highlighted interactive surfaces and active navigation states.
- **Typography & Structural Contrast**: Base text uses deep `#111827` for high legibility, supplemented by `#64748B` for secondary operational metadata and structural dividers at `#E2E8F0`.
- **System Feedback**:
  - Success: `#16A34A` (completed trips, boarded riders, on-schedule status)
  - Warning: `#D97706` (delays, pending authorizations, route variance)
  - Error/Destructive: `#DC2626` (sos alerts, missed stops, critical hardware errors)

## Typography

The typography uses Inter across all levels to maintain clarity, rapid scanning, and institutional neutrality. Numbers, ETA trackers, and vehicle IDs rely on tabular figure configurations to prevent layout shift during real-time dashboard updates.

- **Headlines**: Semi-bold weights with negative tracking keep page headers and section summaries compact and sharp.
- **Body Text**: Tuned for high legibility across student rosters, logs, and driver reports with proportional vertical rhythm.
- **Labels & Microcopy**: Medium and semi-bold weights for badges, table column headers, status markers, and operational breadcrumbs.

## Layout & Spacing

The layout is built upon an 8px base rhythm arranged into a clean, workspace-driven grid architecture:
- **Application Shell**: A fixed 240px lateral navigation rail paired with a fluid content canvas anchored on `#F8FAFC`.
- **Data Workspaces**: Fluid 12-column grid system utilizing 24px desktop gutters and 32px canvas margins. On mobile monitors and driver views, the grid collapses to 4 columns with 16px margins and gutters.
- **Component Geometry**: Internal component spacing relies primarily on `space-sm` (8px) and `space-md` (16px) tokens to preserve high operational density without sacrificing breathing room.

## Elevation & Depth

This design system avoids dark or heavy shadows, relying on tonal surface contrast and hairline borders (`1px solid #E2E8F0`) to establish hierarchy.

- **Level 0 (Canvas)**: `#F8FAFC` base application background.
- **Level 1 (Surfaces & Cards)**: `#FFFFFF` resting planar elevation with `border: 1px solid #E2E8F0` and no shadow.
- **Level 2 (Popovers, Select Menus, Tooltips)**: `#FFFFFF` with `border: 1px solid #E2E8F0` and an ambient shadow: `box-shadow: 0 4px 12px rgba(17, 24, 39, 0.05), 0 1px 2px rgba(17, 24, 39, 0.03)`.
- **Level 3 (Modals & Route Focus Drawers)**: `#FFFFFF` with a crisp outer edge and soft ambient scrim (`rgba(17, 24, 39, 0.2)`), grounded with `box-shadow: 0 12px 32px rgba(17, 24, 39, 0.08)`.

## Shapes

The interface embraces a unified 8px (`0.5rem`) corner radius across inputs, buttons, cards, and modal frames. This radius softens the administrative software experience while avoiding overly playful or consumerized pill shapes. Compact nested elements (status dots, tags, checkboxes) scale down harmoniously to 4px (`0.25rem`), retaining precision and alignment.

## Components

- **Buttons**:
  - *Primary*: Solid `#E56B6F` background, white text, 8px radius, height 36px (or 40px for touch/tablet). Hover: subtle tone darken (`#D95D61`).
  - *Secondary / Neutral*: `#FFFFFF` surface, `#111827` text, `1px solid #E2E8F0`. Hover: `#F8FAFC`.
  - *Subtle / Ghost*: Transparent background, `#64748B` text. Hover: `#F8FAFC` background with `#111827` text.
- **Navigation Items**:
  - Resting: Transparent surface, `#64748B` text, 8px radius.
  - Active: `#FFF1F2` background, `#E56B6F` text and icon weight, optional 3px left indicator bar.
- **Input Fields**:
  - `#FFFFFF` background, `1px solid #E2E8F0`, 8px radius, text in `#111827`, placeholder in `#94A3B8`.
  - Focus state: `1px solid #E56B6F` with an outer soft ring (`box-shadow: 0 0 0 3px rgba(229, 107, 111, 0.15)`).
- **Cards & Data Tables**:
  - Cards feature a flat `#FFFFFF` fill, 8px radius, and clean `#E2E8F0` border.
  - Table headers use `#F8FAFC` with 11px uppercase label typography, horizontal borders only (`#E2E8F0`), and cell heights set to a compact 44px.
- **Status Badges & Chips**:
  - Subtle tinted background with deep-toned text:
    - Normal / Active Route: `#F0FDF4` background, `#16A34A` text.
    - Delayed / Notice: `#FFFBEB` background, `#D97706` text.
    - Alert / Deviation: `#FEF2F2` background, `#DC2626` text.
- **Roster & Route Timeline Components**:
  - Vertical rail nodes with 2px connecting lines in `#E2E8F0`.
  - Checkpoint nodes use 8px circular pips: empty `#E2E8F0` for upcoming, solid `#16A34A` for passed, and glowing `#E56B6F` for active stop location.