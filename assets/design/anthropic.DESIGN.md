---
name: Anthropic
colors:
  primary: "#D97757"
  secondary: "#E3DACC"
  surface: "#000000"
  on-surface: "#FAF9F5"
typography:
  body-md:
    fontFamily: Anthropic Sans
    fontSize: 16px
    fontWeight: 400
rounded:
  md: 8px
---

# Design System Inspired by Anthropic

## 1. Visual Theme & Atmosphere

Anthropic's design system embodies a philosophy of deliberate restraint and intellectual clarity. The visual language prioritizes readability and thoughtful hierarchy through a carefully curated palette of warm earth tones balanced against a crisp, high-contrast neutral foundation. The aesthetic is sophisticated yet approachable, reflecting the organization's commitment to making complex AI research accessible. Typography serves as the primary design driver, with generous spacing and a measured typographic scale creating breathing room for ideas. The interplay between serif and sans-serif typefaces establishes both authority and warmth, while selective accent colors—particularly warm terracotta and sage green—introduce moments of intentional visual interest without overwhelming the content-first approach.

**Key Characteristics**
- High-contrast neutral palette anchored by near-black (`#141413`) and cream (`#FAF9F5`)
- Warm accent colors used sparingly for interactive and elevated moments
- Serif-driven typography hierarchy with elegant letterforms
- Generous whitespace and deliberate breathing room between elements
- Restrained use of color—accent hues reserved for specific semantic roles
- Emphasis on legibility and content hierarchy over decorative flourishes

## 2. Color Palette & Roles

### Primary
- **Primary CTA Background** (`#141413`): Deep charcoal used for high-emphasis call-to-action buttons and interactive elements
- **Primary CTA Text** (`#FAF9F5`): Off-white cream used for text on dark backgrounds, ensuring accessibility and contrast

### Accent Colors
- **Warm Accent / Success** (`#D97757`): Terracotta-rust tone used for interactive highlights, secondary buttons, and positive actions; most frequent accent color in the system
- **Earth Accent** (`#C6613F`): Deeper rust-brown used for hover states and elevated interactive elements
- **Sage Accent** (`#788C5D`): Muted green-gray used for contextual highlights and secondary accent moments
- **Soft Blush** (`#EBCECE`): Pale mauve used for subtle background fills and gentle visual separation
- **Cool Accent** (`#6A9BCC`): Muted blue used for informational or secondary contextual states
- **Mauve Accent** (`#C46686`): Soft purple used for tertiary accent moments and special states
- **Soft Seafoam** (`#BCD1CA`): Pale blue-green used for tertiary backgrounds and delicate visual separation

### Neutral Scale
- **Neutral 0** (`#141413`): Primary text, borders, and dark UI elements; deepest neutral
- **Neutral Very Dark** (`#0F0F0E`): Near-black used sparingly for maximum emphasis
- **Neutral Black** (`#000000`): Pure black used in specific contexts requiring absolute contrast
- **Neutral Dark** (`#73726C`): Dark gray for secondary text and muted interactive states
- **Neutral Medium-Dark** (`#87867F`): Medium-dark gray for tertiary text and disabled states
- **Neutral Medium** (`#B0AEA5`): Mid-tone gray for subtle borders and secondary backgrounds
- **Neutral Light** (`#C6C4BA`): Light gray for borders, dividers, and tertiary backgrounds
- **Neutral Very Light** (`#FAF9F5`): Off-white cream, primary background color and light text on dark

### Surface & Borders
- **Primary Surface** (`#FAF9F5`): Default page and card background
- **Primary Border** (`#C6C4BA`): Default stroke color for outlines and dividers
- **Secondary Border** (`#B0AEA5`): Subtle borders for secondary separations
- **Tertiary Surface** (`#E3DACC`): Warm, soft background for elevated or highlighted sections

## 3. Typography Rules

### Font Family
**Primary Serif:** Anthropic Serif (with fallback: Georgia, "Times New Roman", serif)  
**Primary Sans:** Anthropic Sans (with fallback: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif)

### Hierarchy

| Role | Font | Size | Weight | Line Height | Letter Spacing | Notes |
|------|------|------|--------|-------------|----------------|-------|
| Display / Hero | Anthropic Serif | 104px | 300 | 104px | 0 | Largest heading scale; used for page title hero sections |
| Heading 1 | Anthropic Serif | 60px | 400 | 67px | 0 | Major section headings with elegant weight |
| Heading 1 Bold | Anthropic Sans | 60px | 700 | 67px | 0 | Bold variant for emphasis within large headings |
| Heading 2 | Anthropic Serif | 60px | 400 | 67px | 0 | Alternative large heading |
| Heading 3 | Anthropic Sans | 24px | 600 | 31px | 0 | Section subheadings and card titles |
| Heading 3 Small | Anthropic Sans | 12px | 700 | 17px | 0 | Small caps-style headings and labels |
| Body Large | Anthropic Serif | 24px | 400 | 34px | 0 | Primary body text with serif elegance |
| Body / List | Anthropic Serif | 20px | 400 | 28px | 0 | Standard list items and secondary body copy |
| Body Standard | Anthropic Sans | 17px | 400 | 26px | 0 | Main paragraph text; alternative sans-serif body |
| Link / CTA Text | Anthropic Serif | 18px | 600 | 25px | 0 | Emphasized links with serif authority |
| Link Compact | Anthropic Serif | 16px | 700 | 20px | 0 | Smaller emphasized links |
| Navigation | Anthropic Serif | 20px | 400 | 28px | 0 | Primary navigation text |
| Navigation Small | Anthropic Serif | 16px | 400 | 20px | 0 | Secondary navigation or compact menus |
| Button | Anthropic Sans | 16px | 400 | 16px | 0 | Default button label text |
| Button Large | Anthropic Serif | 20px | 400 | 28px | 0 | Large button labels with serif treatment |
| Caption | Anthropic Sans | 12px | 400 | 17px | 0 | Small captions, footnotes, helper text |
| Label | Anthropic Sans | 12px | 400 | 15px | 0 | Form labels and small identifiers |
| Small Text | Anthropic Sans | 12px | 500 | 17px | 0 | Emphasized small text |

### Principles
- **Serif for Authority:** Anthropic Serif used for primary headings, navigation, and body copy to establish intellectual credibility
- **Sans for Clarity:** Anthropic Sans used for UI controls, labels, and secondary content for functional clarity
- **Generous Line Height:** All text maintains line heights between 120–150% for comfortable reading
- **Weight Hierarchy:** Bold weights (600–700) reserve for headings, labels, and emphasized text; 400 weight for body content
- **Elegant Contrast:** Size and weight are primary differentiators; color contrast is secondary to hierarchy

## 4. Component Stylings

### Buttons

#### Primary Button (Dark)
- **Background:** `#141413`
- **Text Color:** `#FAF9F5`
- **Font:** Anthropic Sans, 16px, weight 400
- **Padding:** `8px 16px`
- **Border Radius:** `8px`
- **Border:** `1px solid #141413`
- **Line Height:** 16px
- **Height:** 36px
- **Hover State:** Background `#0F0F0E`, text `#FAF9F5`
- **Active State:** Background `#000000`
- **Disabled State:** Opacity 50%, cursor not-allowed

#### Secondary Button (Serif, No Background)
- **Background:** `rgba(0, 0, 0, 0)` (transparent)
- **Text Color:** `#141413`
- **Font:** Anthropic Serif, 20px, weight 400
- **Padding:** `0px`
- **Border Radius:** `0px`
- **Border:** None
- **Line Height:** 28px
- **Height:** 68px
- **Hover State:** Text opacity 75%
- **Active State:** Text opacity 50%

#### Ghost Button (Light Background)
- **Background:** `rgba(0, 0, 0, 0)` (transparent, light context)
- **Text Color:** `#FAF9F5`
- **Font:** Anthropic Sans, 16px, weight 400
- **Padding:** `0px`
- **Border Radius:** `8px`
- **Border:** None
- **Line Height:** 16px
- **Height:** 100%
- **Hover State:** Background `rgba(250, 249, 245, 0.15)`
- **Active State:** Background `rgba(250, 249, 245, 0.25)`

#### Tertiary Button (Small Label)
- **Background:** `rgba(0, 0, 0, 0)`
- **Text Color:** `#FAF9F5`
- **Font:** Anthropic Sans, 15px, weight 400
- **Padding:** `0px`
- **Border Radius:** `0px`
- **Border:** None
- **Line Height:** 15px
- **Hover State:** Opacity 75%

#### CTA Link Button
- **Background:** `#FAF9F5`
- **Text Color:** `#141413`
- **Font:** Anthropic Serif, 18px, weight 600
- **Padding:** `12px 31px`
- **Border Radius:** `0px 0px 8px 8px`
- **Border:** None
- **Line Height:** 25px
- **Height:** 49px
- **Hover State:** Background `#E3DACC`, text `#141413`
- **Active State:** Background `#C6C4BA`

### Cards & Containers

#### Card (Light Background)
- **Background:** `#FAF9F5`
- **Border:** `1px solid #C6C4BA`
- **Border Radius:** `8px`
- **Padding:** `24px` to `48px`
- **Box Shadow:** Small elevation (see Depth & Elevation)
- **Hover State:** Border color `#B0AEA5`, shadow slightly increased

#### Elevated Section (Dark)
- **Background:** `#141413`
- **Text Color:** `#FAF9F5`
- **Border Radius:** `16px`
- **Padding:** `48px` to `64px`
- **Box Shadow:** None (solid background provides depth)

#### Subtle Section (Warm Accent)
- **Background:** `#E3DACC`
- **Text Color:** `#141413`
- **Border Radius:** `0px`
- **Padding:** `32px` to `48px`
- **Box Shadow:** None

### Inputs & Forms

#### Text Input
- **Background:** `#FAF9F5`
- **Border:** `1px solid #C6C4BA`
- **Text Color:** `#141413`
- **Font:** Anthropic Sans, 17px, weight 400
- **Padding:** `12px 16px`
- **Border Radius:** `8px`
- **Line Height:** 26px
- **Height:** 40px
- **Focus State:** Border `1px solid #D97757`, outline none
- **Disabled State:** Background `#C6C4BA`, text `#87867F`, opacity 50%
- **Label:** Anthropic Sans, 12px, weight 400, color `#141413`

#### Form Label
- **Font:** Anthropic Sans, 12px, weight 400
- **Color:** `#141413`
- **Margin Bottom:** `8px`
- **Line Height:** 15px

#### Checkbox / Radio
- **Size:** 20px × 20px
- **Border:** `1px solid #B0AEA5`
- **Border Radius:** Checkbox 4px, Radio 50%
- **Background (Unchecked):** `#FAF9F5`
- **Background (Checked):** `#D97757`
- **Checkmark Color:** `#FAF9F5`

### Navigation

#### Header Navigation
- **Background:** `#FAF9F5`
- **Text Color:** `#141413`
- **Font:** Anthropic Serif, 20px, weight 400
- **Padding:** `16px 24px`
- **Line Height:** 28px
- **Link Hover State:** Text color `#D97757`, text-decoration underline
- **Link Active State:** Color `#C6613F`, text-decoration underline

#### Primary Navigation Link
- **Font:** Anthropic Serif, 16px, weight 400
- **Color:** `#141413`
- **Text Decoration:** None, underline on hover
- **Hover State:** Color `#D97757`
- **Active State:** Color `#C6613F`, text-decoration underline

#### Dropdown Menu
- **Background:** `#FAF9F5`
- **Border:** `1px solid #C6C4BA`
- **Border Radius:** `0px 0px 8px 8px`
- **Box Shadow:** `rgba(0, 0, 0, 0.01) 0px 2px 2px 0px, rgba(0, 0, 0, 0.02) 0px 4px 4px 0px, rgba(0, 0, 0, 0.04) 0px 16px 24px 0px`
- **Padding:** `8px 0px`
- **Z-index:** 10

#### Breadcrumb Navigation
- **Font:** Anthropic Sans, 12px, weight 400
- **Color:** `#B0AEA5`
- **Separator:** `/` with margin `0px 8px`
- **Current Item:** Color `#141413`, weight 500

### Badges

#### Primary Badge
- **Background:** `#D97757`
- **Text Color:** `#FAF9F5`
- **Font:** Anthropic Sans, 12px, weight 600
- **Padding:** `4px 12px`
- **Border Radius:** `4px`
- **Line Height:** 17px

#### Secondary Badge
- **Background:** `#E3DACC`
- **Text Color:** `#141413`
- **Font:** Anthropic Sans, 12px, weight 600
- **Padding:** `4px 12px`
- **Border Radius:** `4px`
- **Line Height:** 17px

#### Neutral Badge
- **Background:** `#C6C4BA`
- **Text Color:** `#141413`
- **Font:** Anthropic Sans, 12px, weight 500
- **Padding:** `4px 12px`
- **Border Radius:** `4px`
- **Line Height:** 17px

## 5. Layout Principles

### Spacing System

The design system uses an 8px base unit with a flexible scale that supports both compact and generous layouts:

- **8px:** Minimal gap, tight component pairing, icon spacing
- **12px:** Tight padding for form inputs and small components
- **16px:** Standard gap between components, input/label spacing
- **20px:** Comfortable margin between sections, list spacing
- **24px:** Standard padding for cards, containers, and moderate sections
- **32px:** Generous gap between major content blocks
- **48px:** Substantial padding for elevated sections, hero padding
- **60px:** Large margin for section separation
- **64px:** Generous padding for major container sections
- **76px:** Extra-large spacing for hero section top/bottom
- **180px:** Maximum hero section padding for full-screen hero blocks

### Grid & Container

- **Max Width:** 1200px for primary content containers
- **Column Strategy:** 12-column responsive grid for desktop layouts, collapsing to single column on mobile
- **Gutters:** 16px to 24px depending on context and breakpoint
- **Section Patterns:** Full-width sections with internal max-width constraints; alternating background colors for visual rhythm

### Whitespace Philosophy

Whitespace is treated as a primary design element, creating rhythm and enabling content breathing room. Generous padding (48px–64px) between major sections prevents visual fatigue, while tighter spacing (8px–16px) at the component level maintains functional clarity. Asymmetrical whitespace is avoided in favor of consistent, predictable spacing that reflects the system's intellectual approach.

### Border Radius Scale

- **0px:** Hard corners for primary text, navigation, and clean geometric elements
- **4px:** Micro-radius for small components like badges and minor form elements
- **8px:** Primary radius for buttons, inputs, and standard interactive components
- **16px:** Generous radius for elevated containers, hero sections, and special components

### Border Widths

- **Thin:** `1px` used for all standard borders, dividers, input fields, and button strokes
- **Medium:** `2px` used for emphasis borders and selected states (if needed)

## 6. Depth & Elevation

| Level | Treatment | Use |
|-------|-----------|-----|
| Base | No shadow | Body text, backgrounds, standard page elements |
| Hover | `rgba(0, 0, 0, 0.01) 0px 2px 2px 0px, rgba(0, 0, 0, 0.02) 0px 4px 4px 0px, rgba(0, 0, 0, 0.04) 0px 16px 24px 0px` | Dropdowns, cards on hover, floating elements |
| Elevated | Solid background color (`#141413` or `#FAF9F5`) | Modal overlays, header sections, raised containers |
| Fixed | Background with border + shadow | Sticky headers, floating toolbars |

**Shadow Philosophy:** The system employs a single, refined shadow scale based on a layered opacity approach. Shadows are subtle and rarely applied, preferring solid backgrounds and borders for depth definition. When shadows are used, they should suggest slight elevation rather than dramatic floating; the soft blur radius and multiple layers create a sophisticated, non-distracting effect. Transparency values (1%, 2%, 4%) build composite shadows without overwhelming the page.

### Opacity Levels

- **1% (`0.01`):** Extremely subtle hover or disabled states
- **34% (`0.34`):** Secondary or muted interactive elements
- **50% (`0.50`):** Disabled elements, inactive states, secondary text

### Z-index / Layering

- **Base:** `1` (default document flow)
- **Raised Content:** `2` (cards, slightly elevated sections)
- **Overlay Content:** `3` (semi-transparent overlays, light backgrounds)
- **Fixed Navigation:** `5` (fixed/sticky headers, always above content)
- **Dropdown:** `10` (dropdown menus, contextual popups)
- **Sticky Elements:** `101` (sticky headers, floating toolbars)
- **Modal:** `1000` (modal dialogs, major overlays)
- **Toast/Alert:** `9999` (notifications, highest priority alerts)

## 7. Do's and Don'ts

### Do

- **Use serif fonts for primary headings and navigation** to establish intellectual authority and elegance
- **Reserve accent colors for interactive elements and calls-to-action** to guide user attention without visual noise
- **Maintain generous whitespace around major content blocks** (48px–64px padding) for breathing room and emphasis
- **Apply subtle borders (`1px`) instead of shadows** for depth and visual separation in most contexts
- **Use the neutral scale (`#141413` for text, `#FAF9F5` for backgrounds)** as the foundation; accent colors are punctuation, not the baseline
- **Group related form inputs with 16px gaps** and use clear label hierarchy with 12px sans-serif labels
- **Implement the small shadow only on interactive hover states** and dropdowns to create micro-feedback
- **Ensure all text meets WCAG AA contrast minimums** (4.5:1 for body, 3:1 for large text)
- **Use consistent padding scales** (multiples of 8px) across all components for predictable layouts
- **Combine serif and sans thoughtfully:** Serif for meaning-making content, sans for UI and functional text

### Don't

- **Don't use multiple accent colors in a single section** without clear semantic distinction
- **Don't apply shadows to static content or non-interactive elements**
- **Don't mix serif and sans fonts within a single text block** or heading
- **Don't reduce whitespace below 16px between major sections** to maintain visual rhythm
- **Don't use pure black (`#000000`) for primary text**; use `#141413` for softer on-screen rendering
- **Don't apply border radius greater than 16px** unless creating explicit soft, rounded visual metaphors
- **Don't stack more than 2–3 font sizes or weights** in a single heading for clarity
- **Don't apply opacity-based disabled states without also reducing saturation** or changing color slightly
- **Don't use accent colors as background fills** for large areas; reserve them for buttons, badges, and interactive accents
- **Don't create custom button styles outside the defined set**; enforce consistency through the system

## 8. Responsive Behavior

### Breakpoints

| Breakpoint | Width | Key Changes |
|------------|-------|-------------|
| Mobile | 320px–767px | Single column, 16px gutters, stack navigation, reduce padding to 24px, font sizes reduce by 10–15%, full-width cards, touch targets 44px minimum |
| Tablet | 768px–1023px | Two-column grid, 20px gutters, 32px padding, larger font sizes, modal navigation menus, optimized spacing |
| Desktop | 1024px–1199px | 12-column grid, 24px gutters, 48px+ padding, full navigation bar, card layouts enabled, optimized for mouse/keyboard |
| Wide | 1200px+ | Max-width 1200px container, generous 48px–64px padding, full featured layouts, optimized for large screens |

### Touch Targets

- **Minimum Touch Target:** 44px × 44px for all interactive elements on touch devices
- **Recommended Touch Target:** 48px × 48px for primary interactive elements
- **Spacing Between Targets:** Minimum 8px of clearance between interactive elements to prevent accidental activation
- **Button Padding:** Increase padding to 12px 24px on mobile devices to meet touch minimums

### Collapsing Strategy

- **Navigation:** Collapse primary navigation into hamburger menu below 768px; maintain dropdown structure in mobile menu
- **Spacing:** Reduce section padding from 64px to 48px below 768px; reduce to 24px below 480px
- **Typography:** Reduce display heading from 104px to 72px on tablet, 48px on mobile; reduce body from 24px to 18px on mobile
- **Grid Layout:** Shift from 12-column to 6-column on tablet, single column on mobile; maintain consistent gutter ratio
- **Cards:** Stack card elements vertically; use full width on mobile with reduced padding
- **Hero Sections:** Reduce hero padding from 180px to 120px on tablet, 60px on mobile; adjust heading size accordingly
- **Whitespace:** Reduce gaps systematically: 32px gaps become 20px, 24px gaps become 16px, maintaining hierarchical relationships

## 9. Agent Prompt Guide

### Quick Color Reference

- **Primary CTA Background:** Dark Near-Black (`#141413`)
- **Primary CTA Text:** Cream Off-White (`#FAF9F5`)
- **Primary Accent / Highlight:** Terracotta-Rust (`#D97757`)
- **Secondary Accent:** Earth Brown (`#C6613F`)
- **Tertiary Accent:** Sage Green (`#788C5D`)
- **Body Text:** Deep Charcoal (`#141413`)
- **Secondary Text:** Medium Gray (`#B0AEA5`)
- **Disabled / Muted Text:** Dark Gray (`#87867F`)
- **Borders:** Light Gray (`#C6C4BA`)
- **Subtle Background Fill:** Warm Cream (`#E3DACC`)
- **Page Background:** Cream Off-White (`#FAF9F5`)

### Iteration Guide

1. **Font Foundation:** All body text uses Anthropic Serif 20–24px for primary content; navigation uses Anthropic Serif 16–20px; UI labels use Anthropic Sans 12–16px. Headings layer serif at 60px+ with weight 300–400 for elegance.

2. **Color Discipline:** Use `#141413` for text and `#FAF9F5` for backgrounds as baseline. Accent colors (`#D97757`, `#C6613F`, `#788C5D`) are reserved for interactive elements, buttons, and intentional visual hierarchy—never as primary backgrounds or text.

3. **Spacing Consistency:** All padding uses 8px multiples (8, 12, 16, 20, 24, 32, 48, 64px). All gaps between sections use 20px minimum; section containers use 48px–64px padding. Never use asymmetrical padding unless intentional.

4. **Border & Shadow Minimalism:** Use `1px` borders (`#C6C4BA` or `#B0AEA5`) for all standard dividers and input fields. Apply the soft shadow only to dropdowns and hover card states; static elements use borders, not shadows.

5. **Interactive Component Variants:** Primary buttons are dark (`#141413` background, `#FAF9F5` text); secondary buttons are transparent serif text; tertiary buttons are small sans-serif labels. All buttons use 8px border-radius except decorative serif buttons which use 0px radius.

6. **Form & Input Treatment:** Text inputs use `#FAF9F5` background with `1px #C6C4BA` border, `1px` focus state in `#D97757`. Labels are Anthropic Sans 12px, `#141413`, positioned above inputs with 8px margin-bottom.

7. **Navigation Strategy:** Primary navigation uses Anthropic Serif 16–20px, dark text on light background; links underline and shift to `#D97757` on hover. Dropdowns are light background with small shadow, positioned below trigger element at z-index 10.

8. **Responsive Collapsing:** Reduce padding by 25% on tablet (768px), another 25% on mobile (480px). Font sizes reduce 10–15% on tablet, 20–25% on mobile. Navigation converts to hamburger menu below 768px. Maintain 44px minimum touch targets throughout.

9. **Elevation & Hierarchy:** Use solid backgrounds (`#141413`, `#FAF9F5`, `#E3DACC`) for depth, not shadows. Modals and overlays sit at z-index 1000+. Fixed/sticky headers sit at z-index 101. Dropdowns at z-index 10. Content separation achieved through whitespace, borders, and background color shifts.