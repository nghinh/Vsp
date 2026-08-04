---
name: Vietnam Smart Golf Platform
colors:
  surface: '#0b1326'
  surface-dim: '#0b1326'
  surface-bright: '#31394d'
  surface-container-lowest: '#060e20'
  surface-container-low: '#131b2e'
  surface-container: '#171f33'
  surface-container-high: '#222a3d'
  surface-container-highest: '#2d3449'
  on-surface: '#dae2fd'
  on-surface-variant: '#e2bfb2'
  inverse-surface: '#dae2fd'
  inverse-on-surface: '#283044'
  outline: '#a98a7e'
  outline-variant: '#5a4138'
  surface-tint: '#ffb599'
  primary: '#ffb599'
  on-primary: '#5a1c00'
  primary-container: '#f66018'
  on-primary-container: '#4f1700'
  inverse-primary: '#a73a00'
  secondary: '#ffb690'
  on-secondary: '#552100'
  secondary-container: '#ec6a06'
  on-secondary-container: '#4a1c00'
  tertiary: '#68dba9'
  on-tertiary: '#003825'
  tertiary-container: '#25a475'
  on-tertiary-container: '#00311f'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#ffdbce'
  primary-fixed-dim: '#ffb599'
  on-primary-fixed: '#370e00'
  on-primary-fixed-variant: '#7f2b00'
  secondary-fixed: '#ffdbca'
  secondary-fixed-dim: '#ffb690'
  on-secondary-fixed: '#341100'
  on-secondary-fixed-variant: '#783200'
  tertiary-fixed: '#85f8c4'
  tertiary-fixed-dim: '#68dba9'
  on-tertiary-fixed: '#002114'
  on-tertiary-fixed-variant: '#005137'
  background: '#0b1326'
  on-background: '#dae2fd'
  surface-variant: '#2d3449'
typography:
  display-metrics:
    fontFamily: Fira Code
    fontSize: 48px
    fontWeight: '700'
    lineHeight: 56px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Fira Sans
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
  headline-md:
    fontFamily: Fira Sans
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  body-lg:
    fontFamily: Fira Sans
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Fira Sans
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  label-caps:
    fontFamily: Fira Sans
    fontSize: 12px
    fontWeight: '700'
    lineHeight: 16px
    letterSpacing: 0.05em
  metric-sm:
    fontFamily: Fira Code
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  unit: 8px
  touch-target: 44px
  margin-mobile: 16px
  margin-desktop: 32px
  gutter: 16px
---

## Brand & Style
The design system is engineered for a dual-environment ecosystem: high-stakes outdoor mobile navigation and high-efficiency desktop course management. The brand personality is authoritative, operational, and precise, reflecting the technical nature of GPS data and the prestige of the sport.

The design style follows a **Modern / Professional** approach with a **Soft UI Evolution**. It avoids heavy gradients or glass effects in favor of crisp layouts, subtle tonal layering, and high-contrast information density. The goal is to provide a "quiet" interface that prioritizes legibility under direct sunlight and minimizes cognitive load during administrative tasks. Emotional responses should be "Calm Focus" on the course and "Reliable Control" in the portal.

## Colors
The palette is built on high-performance functionalism. 

- **Primary & Secondary:** Energetic oranges are used for critical actions, active states, and focus indicators.
- **Success/Verified:** A deep emerald green denotes official data and validated metrics.
- **Surface Strategy:** 
  - **Mobile On-Course:** Uses the `background_dark` and `surface_muted` tiers to reduce glare and save battery life.
  - **Mobile Profile/Discovery:** Transitions to a Warm-White (Primary Background #FFFFFF with subtle #F8FAFC accents) to provide a lifestyle feel.
  - **Portal:** Utilizes an Enterprise Light theme with a dark sidebar to establish professional hierarchy.
- **Interactive:** The focus ring strictly follows the primary #EA580C to ensure accessibility during rapid navigation.

## Typography
Typography is split between functional UI text and technical data. 

- **Fira Sans** handles all interface copy, labels, and navigation for its humanist legibility and excellent Vietnamese diacritic support. 
- **Fira Code** is reserved for distances, yardages, coordinates, and technical metrics. Its monospaced nature prevents layout "jitter" when numbers update rapidly via GPS.
- **Scale:** On-course mobile views prioritize `display-metrics` for at-a-glance readability from a distance (e.g., when the phone is mounted on a cart).
- **Minimums:** No body text on mobile should fall below 16px to ensure accessibility in outdoor lighting conditions.

## Layout & Spacing
This design system utilizes an **8pt Grid System** for absolute spatial consistency.

- **Mobile Layout:** Employs a fluid 4-column grid with 16px side margins. Large touch targets are mandatory, with a minimum height of 44pt for interactive elements (buttons, inputs, map controls).
- **Portal Layout:** A fixed-fluid hybrid. The sidebar is fixed at 280px, while the main content area uses a 12-column grid to accommodate data-heavy tables and map editing tools.
- **Rhythm:** Use 8px (base), 16px (small), and 24px (standard) increments for padding and internal component spacing to maintain a "tight" operational feel.

## Elevation & Depth
Depth is communicated through **Tonal Layering** and **Low-Contrast Outlines**.

- **Surfaces:** In the dark theme, the primary background is the deepest level. Cards and panels sit one "step" above using a lighter grey (#201C27). 
- **Outlines:** Instead of shadows, use `rgba(255, 255, 255, 0.08)` borders to define boundaries. This ensures visibility is maintained regardless of screen brightness.
- **Portal Elevation:** The portal uses subtle 1px borders and soft, large-radius shadows (0px 4px 20px rgba(0,0,0,0.05)) on white cards to create a clean, organized hierarchy.

## Shapes
Shapes are **Soft (0.25rem / 4px base)** to strike a balance between modern friendliness and professional rigidity.

- **Standard Elements:** Buttons, input fields, and small cards use 4px corners.
- **Large Containers:** Course cards and modal sheets use `rounded-lg` (8px).
- **Pills:** GPS confidence indicators and badges use fully rounded (pill) shapes to differentiate them from interactive buttons.

## Components
- **Distance Panels:** Prominent Fira Code display. Primary yardage in #FFFFFF, secondary hazard distances in #F97316.
- **GPS Confidence Pills:** Small badges with a pulse icon. Color-coded: Green (High), Yellow (Medium), Red (Searching).
- **Official-Data Badges:** 
  - *Chính thức:* Solid Green background, White text.
  - *Ước tính:* Green border, Green text.
  - *Cộng đồng:* Dark grey background, White text.
  - *Đã cũ:* Red text, transparent background with strikethrough metric.
- **Map Controls:** Floating round buttons (48dp) with high-contrast vector icons. No text labels.
- **Scorecard Steppers:** Linear progress trackers with numeric hole indicators. Active hole highlighted in Primary Orange.
- **Portal Sidebar:** Dark #0F172A background with active states using a vertical 4px orange strip on the left edge.
- **Hazard Rows:** Lists featuring specific vector icons for bunkers, water, and out-of-bounds, paired with Fira Code yardage on the right alignment.
- **Audit Timeline:** Vertical line with nodes representing "Biên tập bản đồ" or "Hiệu chỉnh" events, using time-stamps in `metric-sm`.