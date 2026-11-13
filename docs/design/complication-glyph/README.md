# Monochrome rolled-mat complication artwork

The Watch-face launcher uses the same rolled yoga mat and clock composition as
the app icon, simplified to a single template silhouette. The clock rim, broad
hands, one roomy mat curl and flat base remain; gradients, small ticks and badges
are omitted for small-slot readability. Interior gaps and the background are
transparent so the Watch can supply its own foreground color.

- `mat-clock-source.png` is the reviewed full-resolution transparent artwork.
- `MatClockGlyph.imageset` provides 40-point template PNGs at 1x/2x/3x for
  resizable corner/circular layouts and the explicit 30-point rectangular icon.
- `MatClockInlineGlyph.imageset` provides a separate 14-point template image at
  1x/2x/3x, keeping the natural inline size small.
- The image set declares template rendering. Explicit SwiftUI Image views also
  request template rendering and inherit the Watch face's foreground style.

Regenerate the image sets from the repository root:

```sh
swift scripts/render-complication-glyph.swift
```

The source was derived with the built-in image-generation tool using the existing
rolled-mat app icon as a reference. The selected generation prompt was:

> Create a perfectly clean FLAT BLACK silhouette/template icon on genuinely transparent background based on the reference Teaching Timer logo. Keep the rolled yoga mat with one large spiral curl at lower left, flat mat base extending right, clock ring behind it and two clock hands pointing to twelve and four. REMOVE the app-icon square and dark background completely. Use ONLY solid opaque BLACK for the graphic and actual ALPHA TRANSPARENCY for the background and interior holes. Absolutely NO white shapes, gray, gradients, shading, speckles, distress, texture, shadows, bevel, tiny ticks, text or badges. This is a tiny watch-face glyph, so simplify to thick smooth clean rounded vector-style paths and ample open negative space. Clock circle interior must be empty/transparent except two thick hands. Spiral must be a single clean roomy inward curl with transparent gaps. Mat roll joins broad flat mat along the bottom. Tightly centered composition with modest equal margins, high contrast bold simple shape that is recognizable at 18–32 points. Deliver just the black-on-alpha icon, no mockup.

The initial PDF wrapper was discarded before committing. Simulator logs showed
`Widget archival failed due to image being too large`: the 1,254-pixel embedded
raster exceeded the corner snapshot's image budget even on a 24-point PDF page.
The selected PNG renditions bound the decoded image dimensions. Automated checks
protect that size budget and template/alpha metadata; real Simulator inspection
remains necessary for visual readability.

See the [teaching-face guide](../../TEACHING_FACE_GUIDE.md#quick-launch-from-a-watch-face)
for installation and current Simulator/physical evidence boundaries.
