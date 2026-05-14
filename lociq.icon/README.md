# LOC IQ Icon

This icon represents LOC IQ as a minimal city-level demographics app. The dark background, restrained white boundary, small approximate-location signal, and quiet all-caps identity mirror the application UI.

The artwork should stay sparse: no map tiles, no search UI, no heavy charts, and no decorative gradients. The app resolves the user's current city or census-designated place, displays public Census ACS demographic signals, and draws a simple boundary outline.

Primary visual rules:

- Background: LOC IQ ink, `rgb(19, 19, 18)`.
- Typography: all-caps system sans, ultra-light for `LOC IQ`, neutral letter spacing.
- Geometry: one thin city-boundary outline with no fill.
- Accent: one small yellow approximate-location dot.
- Descriptor: keep `CITY DEMOGRAPHICS` quiet and secondary.
- Source size: square `1024 x 1024` PNG for predictable iOS app icon scaling.

Regenerate the source artwork with:

```sh
swift scripts/generate_lociq_icon.swift
```
