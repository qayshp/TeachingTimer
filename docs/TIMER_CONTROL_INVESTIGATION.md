# Timer-control investigation and correction — October 28, 2026

No reliable control-disappearance reproduction or production rendering fix was
established. Build 16 remains on the physical Watch; no physical device was used.

## Correction to the previous review

The earlier build-16/build-19 comparison incorrectly interpreted controls as
missing from screenshot previews. Re-examining the original stored files shows:

- `16-se3-count.png`: Vision OCR reads Class. The foreground hands cross the
  count label, affecting recognition; this is not evidence of an absent Class control.
- `19-ultra-count.png`: Vision OCR reads Class and Stop count; direct pixel
  sampling finds both straight sides of the button outline.
- Each file's Git object hash matches its originally committed image. The
  evidence was not replaced to obtain this result. No cause in the image viewer
  or model's visual processing has been established; the earlier interpretation
  itself was wrong.

The comparison, current status and usability review now carry this correction.
This does not retract physical black-media reports or diagnose prior timer-return
failures. It removes these two incorrectly classified screenshots as evidence.

## Bounded tests

Xcode 27.1, watchOS 27.0 (24R362), disposable Ultra 4 49 mm Simulator. Each run
starts a default class, then performs two count/Lock/wake/cancel cycles with
33 screenshots. The live runtime/count journals verify the requested actions.

| Variant | Frames | Count-outline warnings | Outcome |
| --- | --- | --- | --- |
| Build 19 baseline | 33 | 0 | No verified disappearing count outline |
| Timelines confined to drawing layers | 33 | 0 | No reproducible improvement over baseline; removed |
| Shared composition group | 33 | 0 | No established benefit; removed |

OCR flags partly hidden text as well as genuinely absent text. The hands remain
foremost and can cross Class/Stop count; these warnings are retained for review,
not counted as app failures. The outline helper samples the full-width button's
two straight sides and does not certify the native volume glyph, Class outline,
touch response, arbitrary layouts or the whole frame.

No speculative timeline/compositing changes are retained. The native volume
adapter, focus calls and media-refresh policy are preserved. Actual Crown/audio
behavior remains unverified in this Simulator setup.

## Repeatable evidence collection

Use `tools/simulator-regression/timer_controls.py` with an ad-hoc-signed Watch
Simulator app, an explicitly selected booted disposable Watch named
`TeachingTimer Regression…`, and `--reset-test-app`. It saves originals, OCR,
outline measurements and journals privately, and always labels rendering as
requiring review. It never accepts a physical device or repairs the environment.

If a control appears missing again, inspect the original PNG and corroborate
the relevant text/border pixels before diagnosing a rendering defect. Record
duration, touchability and recovery separately. Do not add blind reloads or
change the working Crown mechanism without a demonstrated benefit.

Private logs/source experiments are under ignored
`work/support/2026-10-28-controls/`. No raw journals were published.
