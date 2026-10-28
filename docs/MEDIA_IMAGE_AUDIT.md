# Native-media original-image audit

October 28, 2026. This audit separates the genuine older reproduction from later
misclassified captures. It does not change TeachingTimer or prove a physical
root cause. The physical teaching installation remains build 16.

## Method

Read 68 original PNGs from the October 24 service-loss/view-reload experiments
and October 26 regression/comparison folders. Retained each SHA-256, Vision OCR
result and content-area pixel measurements. The measured region is x 10–90%,
y 22–82% of the screen; it excludes the system time and bottom page dots.

`media_evidence.py` labels positive Not Playing text, content requiring review,
or a nearly black region requiring review. It never calls a missing OCR string
a rendering failure. A black region alone cannot establish page selection,
duration, cause, lack of interaction or recovery. Original images and the
surrounding sequence must supply that context.

## Findings

- **55 images contain Not Playing text.** These include the later delayed
  captures. They cannot support the previous delayed-black interpretation or
  rank the proposed recovery variants.
- **Four original October 24 images have a completely black measured region.**
  Direct inspection confirms black content with system time and page dots.
  They are the two build-6 service-loss trials and two build-7 view-reload
  trials. Thus the original controlled Simulator reproduction remains valid.
- **Nine images require contextual review.** Eight depict timer/menu content;
  one recovery image has the native artwork/transport buttons without readable
  Not Playing text. No absence
  of OCR was treated as proof of a blank page.

| Original capture | Pixel/OCR observation |
| --- | --- |
| `sim-media-after-service-loss.png`, `sim-second-black.png` | Zero content-region signal; only clock/dots visible. |
| `sim-media-after-force-close.png` | Not Playing text and native controls present. |
| `sim-second-recovered.png` | Artwork and transport buttons present; OCR misses native text. |
| `black-before-reload.png`, `trial2-black.png` | Zero content-region signal; only clock/dots visible. |
| `after-reload.png`, `trial2-recovered.png` | Not Playing text and controls present. |
| October 26 delayed media frames | Content present; earlier black classification withdrawn. |

The original captured host/class lifecycle and native-service error events are
separate supporting evidence. Fault injection terminates a native view service
deliberately; it does not establish why the physical page sometimes goes black.
The host and view-only recovery observations do not prove a permanent fix.

## Repeatable local audit

```
python3 tools/simulator-regression/media_evidence.py \
  --output work/media-image-audit-new ORIGINAL_MEDIA_CAPTURE.png ...
```

Use screen-only media captures. The tool does not infer what page is selected
from its filename; menu/timer images can contain many bright pixels. Keep the
outputs private because OCR and filenames may contain personal information.
Four helper tests check positive text, OCR absence and exclusion of system text.

Private originals and results are in
`work/support/2026-10-28-next-pass/media-audit/`. The existing Apple report
FB25305069 already contains the October 24 originals. A concise clarification
should preserve that evidence while withdrawing the later variant ranking.

## Fresh build-21 sequence

A fresh SE 3 sequence on October 28 passed all five host/class/control lifecycle
checks after deliberate view-service termination. All six initial/delayed media
captures contain Not Playing, including the captures five seconds later. This
bounded run did not reproduce the failure; it does not establish a permanent
fix or paired-phone audio success. The 14 essential teaching actions also passed.
No new recovery policy or speculative production rendering change was adopted.
