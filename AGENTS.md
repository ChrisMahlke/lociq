# AGENTS.md

## Project Goal

Improve the demographic profile screen while preserving the current minimal, dark, premium visual style.

The existing screen has a strong composition: a small geographic boundary/map element on the left and clean demographic statistics on the right. The goal is to add visual interest and better information design without making the screen feel crowded, decorative, or overbuilt.

## Design Principles

- Keep the interface minimal, quiet, and editorial.
- Do not add decorative graphics that do not carry information.
- Preserve the dark background and restrained contrast.
- Use the existing gold/yellow accent sparingly.
- Avoid visual clutter, heavy icons, excessive labels, and unnecessary lines.
- Statistics should feel integrated into the layout, not pasted on as charts.
- The screen should still read as premium, calm, and spatial.

## Left-Side Geography Enhancement

### Objective

Use the city geographic boundary as a subtle visual data object rather than leaving the area beneath it feeling empty.

### Required Treatment

Add a density-related visual treatment inside the city boundary.

Preferred approaches:

1. **Soft interior fill**
   - Fill the boundary shape with a subtle translucent gray or muted smoky gold.
   - The fill should be quiet and low-contrast.
   - The existing outline should remain visible.
   - The current gold location dot should remain the primary accent.

2. **Dot texture clipped to the boundary**
   - Use tiny, evenly distributed dots inside the boundary.
   - The dots should imply density without becoming a choropleth map.
   - Dots should be low-opacity gray, with optional very limited gold accenting.
   - Do not make the dot pattern visually busy.

3. **Fine hatch or micro-grid texture**
   - Use a very faint architectural-style hatch or micro-grid inside the boundary.
   - The texture should feel measured and restrained.
   - It should not compete with the right-side statistics.

### Data Integrity Rule

Do **not** create internal shading variation unless actual sub-area data exists.

Do not make one part of the city boundary darker than another just to make it look interesting. That would imply a choropleth or internal density distribution that may not be supported by data.

If only city-level density is available, the entire city boundary should receive a uniform treatment.

### Optional Density Label

Add a small density label near or below the boundary map only if it does not crowd the composition.

Suggested format:

```text
DENSITY
1,2XX / SQ MI
```

Style:

- Small uppercase label
- Light gray text
- Density value slightly brighter than the label
- No large chart title
- No additional explanation unless required

## Right-Side Statistic Enhancements

### Objective

Turn selected percentage-based statistics into quiet visual bars while preserving the existing clean numeric hierarchy.

### Keep as Mostly Numeric

The following should remain primarily text/numeric:

- Population
- Median age
- Households
- Median household income

These numbers are already clear and do not need chart treatment.

### Convert to Minimal Bars

The following existing stats should receive subtle bar treatments:

1. **Renters / Owner Occupied**
   - Current values:
     - 26% renters
     - 74% owner occupied
   - Represent as a thin horizontal segmented bar.
   - The owner-occupied portion should be visually dominant.
   - The renters portion should be secondary.
   - Use restrained contrast.

2. **Education**
   - Current value:
     - 59% bachelor's or higher
   - Represent as a thin horizontal progress bar.
   - The filled portion represents 59%.
   - The remainder should be a faint track.
   - Keep the numeric value visible.

### Bar Style

Bars should be:

- Thin
- Minimal
- Horizontal
- Low-profile
- Aligned with the existing stat column
- No taller than necessary
- Built from simple rectangles or line segments
- Free of shadows, gradients, 3D effects, and animation unless already part of the app style

Suggested visual language:

```text
RENTERS
26%
[█████░░░░░░░░░░░░░░░]
74% OWNER OCCUPIED
```

For education:

```text
EDUCATION
59%
[████████████░░░░░░░░]
BACHELOR'S OR HIGHER
```

The actual implementation should use vector bars, not text characters.

## Layout Guidance

### Left Column

The left column should contain:

- Location's/City's boundary outline
- Existing gold location dot
- Subtle density treatment clipped inside the boundary
- Optional small density label

Do not add drive-time rings, regional access diagrams, nearby city labels, arrows, or icons below the geography. Those would feel unrelated to the current composition and too visually busy.

### Right Column

The right column should retain the existing vertical hierarchy:

- City name
- Population
- Median age
- Households
- Median household income
- Renters / owner occupied bar
- Education bar

The percentage-based bar sections should not become louder than Population or Income.

## Color Guidance

Use the current palette:

- Background: near-black / charcoal
- Primary text: soft white
- Secondary labels: muted gray
- Accent: existing gold/yellow
- Map outline: soft gray
- Bar tracks: very dark gray or low-opacity gray
- Bar fills: muted gray or subtle gold accent

Use gold carefully:

- Keep the location dot gold.
- Use gold only as a small accent in the density fill or bar fill if it helps connect the visuals.
- Do not turn every chart element gold.

## Typography Guidance

- Maintain current uppercase label style.
- Keep labels small and understated.
- Numeric values should remain clean and legible.
- Do not introduce new font styles unless already used elsewhere in the app.
- Avoid making chart labels longer than the current text blocks.

## Motion / Interaction Guidance

If the screen supports interaction, any added chart animation should be extremely subtle.

Acceptable:

- Bars gently fill on load.
- Density fill fades in softly.

Avoid:

- Bouncy animations
- Pulsing dots
- Moving particles
- Tooltips unless the app already uses them
- Interactive chart behavior that makes the screen feel analytical rather than editorial

## Accessibility

- Maintain sufficient contrast for all text and essential data.
- Do not rely on color alone to distinguish renters vs owner occupied.
- Keep numeric values visible alongside any visual bar.
- Ensure the density treatment does not obscure the boundary outline.
- Respect reduced-motion settings if animations are added.

## Implementation Notes

- The density treatment should be clipped to the city boundary geometry.
- If using SVG, apply the fill, dot pattern, or hatch pattern within a clipPath.
- If using canvas, mask the pattern to the polygon boundary.
- If using a static image asset, make sure it scales cleanly across device sizes.
- Bars should be data-driven from the same values displayed in the text.
- Avoid hard-coding visual percentages separately from displayed stat values.

## Acceptance Criteria

The enhancement is successful when:

- The left-side empty space feels intentional but not filled for its own sake.
- The city boundary remains the visual anchor on the left.
- The density treatment does not imply unsupported internal variation.
- The right-side percentage stats are easier to understand at a glance.
- The design still feels minimal, quiet, and premium.
- No new element competes with the city name or main population figure.
- The screen looks more polished without looking more complicated.

## Do Not Do

- Do not add a choropleth map.
- Do not fake neighborhood-level or block-level density.
- Do not add drive-time rings below the map.
- Do not add nearby city labels around the map.
- Do not add large icons.
- Do not add a second map.
- Do not add heavy gridlines.
- Do not use bright saturated colors.
- Do not make the bar charts look like a dashboard.
- Do not overfill the left-side empty space.
