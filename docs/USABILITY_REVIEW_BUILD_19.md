# Usability review: build 16 and candidate 19

October 28, 2026. Based on the [side-by-side captures](BUILD_16_VS_19.md), current
source and essential-action checks on SE 3 40 mm and Ultra 4 49 mm. These are
recommendations, not additional implemented changes or a physical-class test.

The initial missing-control finding in this review was incorrect; the original
PNG evidence contains those controls. See the [investigation and correction](TIMER_CONTROL_INVESTIGATION.md).
Other native-media and physical volume bugs remain open.

## What is working well

- Start class is the clear primary action, with duration and suggested interval
  inside the same large target. Custom schedule is visibly a separate action.
  The two-line custom label is readable on both sizes; forcing it onto one line
  would trade legibility for little benefit.
- The large count target is useful when rendered. Stopping a count, stopping the
  runtime and ending a class remain different operations. Destructive actions
  are secondary and confirmed; Stop/Resume returns to the face.
- Seconds/minutes are distinguishable by length and weight. The end wedge and
  count arc survive simulated monochrome. The 75-minute fallback avoids a false
  single-revolution progress claim.
- Both hands remain foremost, as requested. Class context stays separate from
  runtime/count state, reducing the cost of recovery while teaching.
- The visible volume widget and two-page layout remain familiar. This pass
  does not add more controls or a troubleshooting page.

## Recommended order

1. **Require direct image evidence for a rendering failure.** The original
   interpretation of the SE 3/Ultra screenshots was wrong. OCR and button-outline
   checks confirm controls in those files. New bounded capture tooling flags
   uncertain frames for review without calling them failures automatically.
   No reliable disappearing-control reproduction or rendering fix was established.
   Future native timer/media failures still need separate investigation.
2. **Make refresh acknowledgement more honest.** A checkmark and “Control
   refreshed” follow return from `focus()`, not confirmation that Crown input or
   sound recovered. Prefer a neutral, brief “Refresh requested” accessibility
   value and a non-success visual acknowledgement. Keep the generous tap target,
   native widget and immediate media-return focus mechanism. This addresses
   trust without claiming to fix the volume bug.
3. **Surface saved-class recovery failure when it actually occurs.** New
   persistence diagnostics preserve unreadable data, but the face can still
   look like an ordinary fresh start. Consider one concise notice that saved
   timing could not be restored and a clear Start class action. Avoid showing
   diagnostics routinely or silently inventing an old schedule. Add synthetic
   corrupted-data tests before shipping such a notice.
4. **Review hand/label intersections without hiding the hands.** The Ultra dim
   capture shows the seconds hand across Stop count. This is an intentional
   priority tradeoff, not a new geometry regression. Before redesigning, compare
   a small text-position/contrast trial at several hand angles while keeping
   both hands foremost. Do not repeat the earlier mistake of masking them
   behind opaque controls. Physical glance readability matters more than a
   single attractive screenshot.
5. **Observe schedule selection before changing the snapping rule.** The
   default action is clear, but an early arrival can still suggest the earlier
   class (1:10 suggests 1:00). The new quick-start guide explains it. If this
   remains confusing in use, test a clearer “Suggested start” label or a compact
   adjustment near the suggestion. Keep custom edits independent of the default.
6. **Keep count completion semantics explicit in help.** The arc reaches one
   minute at the sixth landmark; the six-pulse group completes at 64.8 seconds
   when on time. “1-min count” is a useful short label, but vibration delivery is
   not a precise promise. The guide explains the distinction; avoid adding a
   numeric countdown or more face status unless physical testing shows a need.
7. **Finish accessibility and teaching-environment validation before broader
   distribution.** Verify VoiceOver focus/labels, large text, wet-finger targets,
   dim-room glare, actual wrist-down haptics, battery and runtime renewal on
   hardware when available. This pass checked two geometries at normal text;
   earlier broader checks do not substitute for these tasks. A private support
   route and the TestFlight journal-access pilot also remain prerequisites.

## Follow-through: builds 20–21

Items 2–3 are implemented and described in the [usability follow-up](USABILITY_FOLLOWUP_2026-10-28.md).
The refresh acknowledgement is neutral, and unreadable class timing has a brief
notice and direct Start action. Item 1 was corrected after raw-image inspection;
no rendering experiment was retained. Hand placement, schedule inference,
count semantics and hardware-validation tasks remain as described above.

## Current follow-through

The old next-pass recommendation for feedback and persistence notices is complete
in builds 20–21. See the [active roadmap](ROADMAP.md) for the remaining image audit,
schedule cue, hand-label comparison and accessibility/physical pilot gates.
