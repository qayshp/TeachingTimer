# Watch form-factor validation

The [build-39 aligned-dial candidate](#november-2-build-39-aligned-dial-candidate)
is the latest layout comparison. The October 23 review below retains its original
runtime, device catalog and limits; those are not instructions to recreate old devices.

## Simulator form-factor review — October 23, 2026

Reviewed application revision `24705cb` (application source unchanged since
`6d2e444`, version 1.0/build 5). Xcode 27.1 (27A9275), macOS 27.0.1 (26A434),
watchOS 27.0 (24R362). This is a bounded Simulator usability review, not a new
application build feature or a physical-device certification.

## Coverage

The installed watchOS runtime supports 13 Watch profiles with eight distinct
display geometries. One representative of each geometry was created/used,
installed, launched, visually inspected, and exercised in Device Hub. Profiles
listed as equivalent were compared through installed display dimensions and
masks, not individually booted. This does not claim identical hardware behavior.

| Representative tested | Display pixels | Logical points | Same display geometry in installed catalog |
| --- | --- | --- | --- |
| SE 3 40 mm | 324 × 394 | 162 × 197 | — |
| SE 3 44 mm | 368 × 448 | 184 × 224 | — |
| Series 9 41 mm | 352 × 430 | 176 × 215 | — |
| Series 9 45 mm | 396 × 484 | 198 × 242 | — |
| Series 12 42 mm | 374 × 446 | 187 × 223 | Series 10/11 42 mm |
| Series 12 46 mm | 416 × 496 | 208 × 248 | Series 10/11 46 mm |
| Ultra 2 49 mm | 410 × 502 | 205 × 251 | — |
| Ultra 4 49 mm | 422 × 514 | 211 × 257 | Ultra 3 49 mm |

Older profiles visible in the global device-type catalog but unsupported by the
installed watchOS runtime were not counted as available test destinations.

## Results

- Clean signed Simulator build succeeded; all nine deterministic suites passed.
  Layout checks cover 44-point targets and 5,760 count-track points; geometry
  checks cover 17,280 ray intersections.
- All eight representatives rendered the idle face, default Start sheet, custom
  schedule at maximum app Dynamic Type, and native Now Playing empty-source UI.
- Actual taps opened Start, confirmed a default class, and started a count on
  every size. Seven were explicitly cancelled; the SE 3 40 mm count completed
  naturally at approximately 64.86 seconds. Journals corroborated these outcomes.
- Lock produced monochrome/reduced-luminance rendering on every size. Two locked
  captures per size showed changed hand and count-arc positions. This establishes
  progression between captures, **not guaranteed 1 Hz cadence**.
- Horizontal swipes reached Now Playing and returned to a nonblank timer on all
  eight. Journals recorded both page selections with runtime phase `running`.
  The intermittent blank-page problem was not reproduced in this pass; this is
  not evidence that it is fixed.
- Both hands remained above the controls; dial ticks and the scheduled-end wedge
  remained visible. The inner dashed count track stayed clear of control bounds.
- Maximum-text class-present/session-off captures retained readable Count/Resume
  controls and status. Class timing survived these app-only relaunches. The
  runtime itself was not assumed to survive termination.
- On the smallest display, the maximum-text custom form scrolled to Start custom
  class and Back to default; Back to default returned to the default Start sheet.
  This pass did not exhaustively exercise the duration picker, every settings
  toggle, VoiceOver, every locale, or all class lifecycle combinations.

Several count runs stopped vibrations after late submissions while continuing
the visual arc. The warning was visible and readable; seven of eight runs logged
this condition. Multiple simulators were booted concurrently, so these runs are
not a physical haptic reliability or performance benchmark. No scheduling or
vibration behavior was changed.

## Remaining polish findings

1. At maximum app Dynamic Type, the native **Custom class** navigation title is
   truncated/faded on the smallest SE/Series displays. Form actions remain
   readable and reachable; shortening the title is a possible later polish.
2. The maximum-text split **1-min count / Resume** layout is visually tight on
   some intermediate sizes, especially Series 12 42 mm. Targets remain separate
   and labels fit, but an earlier fallback to **Count** could improve breathing
   room. No text/layout behavior was changed during this verification.

The user's deliberate foreground-hand priority remains: hands can briefly cross
control labels. This is not treated as a new regression or silently reversed.

## Pairing and media limits

All eight Watch simulators have retained pair records with the existing
TeachingTimer Clean iPhone (iPhone 17, iOS 27.0). Only one pair is active at a time;
the original TeachingTimer Clean SE 3 40mm pair remains active. Other Watches may
show the disconnected-phone indicator while inactive. Creating pair records does
not establish healthy companion media discovery.

The iPhone and Watches were left booted for manual testing. Added devices are
named **TeachingTimer Size ...**. They contain test class state; use Class to
manage it or Resume if the session is off. The separate Audio Probe fixture on
the iPhone was preserved. No physical Watch or iPhone was changed.

Native Now Playing rendered **Not Playing**, not a completely black media page.
Actual iPhone playback control, route-specific volume, Crown responsiveness, and
physical vibration perception remain unverified by this pass. Focus lifecycle
calls are diagnostic evidence, not proof of effective volume control.

Apple feedback **FB25294079** asks whether paired Simulator media discovery is
supported. See [paired media testing](PAIRED_SIMULATOR_MEDIA_TEST.md) and
[blank-page reconstruction](BLANK_PAGE_RECONSTRUCTION.md) for separate evidence.

## Representative captures

These are unmodified Simulator screenshots from the tested application, captured
at different times/count positions. They are not physical-Watch photographs.

| SE 3 40 mm | SE 3 44 mm |
| --- | --- |
| ![SE 3 40 mm](images/form-factors-2026-10-23/se40.png) | ![SE 3 44 mm](images/form-factors-2026-10-23/se44.png) |

| Series 9 41 mm | Series 9 45 mm |
| --- | --- |
| ![Series 9 41 mm](images/form-factors-2026-10-23/s9-41.png) | ![Series 9 45 mm](images/form-factors-2026-10-23/s9-45.png) |

| Series 12 42 mm | Series 12 46 mm |
| --- | --- |
| ![Series 12 42 mm](images/form-factors-2026-10-23/s12-42.png) | ![Series 12 46 mm](images/form-factors-2026-10-23/s12-46.png) |

| Ultra 2 49 mm | Ultra 4 49 mm |
| --- | --- |
| ![Ultra 2 49 mm](images/form-factors-2026-10-23/u2.png) | ![Ultra 4 49 mm](images/form-factors-2026-10-23/u4.png) |

| Locked SE 3 40 mm | Maximum-text custom title |
| --- | --- |
| ![Locked count](images/form-factors-2026-10-23/se40-locked-b.png) | ![Truncated custom title](images/form-factors-2026-10-23/se40-custom-max.png) |

| Small-screen custom actions after scrolling | Tight maximum-text split controls |
| --- | --- |
| ![Custom actions](images/form-factors-2026-10-23/se40-custom-footer.png) | ![Count and Resume](images/form-factors-2026-10-23/s12-42-active-max.png) |

## November 2 build-39 aligned-dial candidate

[Issue #19](https://github.com/qayshp/TeachingTimer/issues/19) implements a shared
rounded-rectangle frame below the header. This candidate is independent of the
build-38 native-media experiment: it branches from main's build-37 behavior.
It is not uploaded to TestFlight or installed on a physical Watch.

`TimerFaceLayout` supplies the dial bounds, center, radius and insets. Ticks,
class-progress perimeter, end wedge, both hands and the inner count track use
that coordinate system. Insets reduce both bounds and radius; the circular-corner
approximation now agrees with the ray math. It is not a measurement of physical
display curvature. The dial retains almost all width, with a shorter height and
lower center to clear Class/settings and watchOS time.

Status text, including optional minutes left, sits as a second line inside the
count control to avoid the relocated hand hub. Targets remain at least 44 points.
Both hands remain foremost and can cross lettering at some angles, preserving
the maintainer's priority. Class inference/state, runtime/renewal, count scheduling
and the native companion-volume implementation are unchanged. The volume widget
moves with the layout; the focus runner has an explicit refresh coordinate for
current versus pre-alignment comparisons.

### SE 3 before and after

| Build 37 | Candidate 39 |
| --- | --- |
| ![SE 3 baseline: offset count track and dial through header](images/aligned-39/SE-3-40mm-before37-count.png) | ![SE 3 candidate: nested tracks below a clear header](images/aligned-39/SE-3-40mm-count.png) |

These original captures used the same Simulator, saved class bytes and settings.
They are successive count runs, not the same instant: hand angles and count
positions differ. Settings enabled Minutes left and disabled count vibrations;
the existing active visual-count status takes precedence while counting.

### Five current display sizes

| SE 3 44 mm | Series 12 42 mm |
| --- | --- |
| ![SE 3 44 mm active count](images/aligned-39/SE-3-44mm-count.png) | ![Series 12 42 mm active count](images/aligned-39/Series-12-42mm-count.png) |

| Series 12 46 mm | Ultra 4 49 mm |
| --- | --- |
| ![Series 12 46 mm active count](images/aligned-39/Series-12-46mm-count.png) | ![Ultra 4 49 mm active count](images/aligned-39/Ultra-4-49mm-count.png) |

| SE 3 reduced luminance | Ultra reduced luminance |
| --- | --- |
| ![SE 3 verified dimmed count](images/aligned-39/SE-3-40mm-dim-count.png) | ![Ultra verified dimmed count](images/aligned-39/Ultra-4-49mm-dim-count.png) |

| SE 3 maximum app text | Ultra maximum app text |
| --- | --- |
| ![SE 3 maximum-text face](images/aligned-39/SE-3-40mm-maximum-text.png) | ![Ultra maximum-text face](images/aligned-39/Ultra-4-49mm-maximum-text.png) |

All 22 originals were captured November 2 on the five already-booted watchOS 27.2
(24S118) Simulators with Xcode 27.2 (27B52); ten are curated here. No device was
created or re-paired. Candidate metadata retains its pre-commit dirty revision;
private manifests preserve source/binary identity, hashes, captures and verified
luminance states. The first script attempt read preferences before their
asynchronous disk write completed; polling the actual saved preference corrected
that driver issue before the successful pass. No preferences daemon was killed.

Geometry checks cover eight sizes, 5,760 full count-dot/control clearances and
34,560 ray/contour checks. All 13 Swift suites and 132 Python tests, Simulator and
unsigned archive paths pass. All 21 UI actions and six focus/lifecycle checks pass,
including refresh at its new target, same host/class/native volume identity, and
media-to-timer return. The 33-frame controls run and complete locked count pass.
Simulator checks do not certify physical Crown volume, haptic delivery, guaranteed
Always-On cadence or teaching-length reliability.
