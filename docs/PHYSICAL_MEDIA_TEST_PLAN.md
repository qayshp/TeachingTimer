# Supervised physical volume and media test

Prepared for a short home session with the physical Watch and its paired iPhone.
Preparation does not contact devices, install an app, start playback or schedule
an unattended run. Consult [current build status](../DEVELOPMENT_STATUS.md) and
keep the [November 13/14 comparison](VOLUME_COMPARISON_2026-11-14.md) available.

## Purpose and time budget

Start with **3–5 minutes of active operation** for a working reference and the
phone-volume-change arm. The retained-idle arm adds **10–15 minutes of passive
time**. Class-before-music versus music-before-runtime is a separate paired
comparison, not the default explanation for every result. Start with Apple Music
and the iPhone speaker at a quiet, known nonzero level. Keep native Now Playing
as a separate comparison. The full catalog requires several sessions and any
needed comparison builds/routes; one short session is not every test.

The missing evidence is the ring before input, a known input direction, the first
native scalar and the phone result. The public Crown calibrator establishes its
own binding sign; Simulator subtype mapping alone cannot recover physical intent.
Do not add a custom/quantized volume counter, a recovery floor, an ignored first
movement or a gesture delay to the teaching app for this test.

## Hypothesis protocols and ready-to-run notebooks

The [scenario catalog](../scripts/physical-media-scenarios.json) is the canonical
source for each hypothesis, changed factor, supporting/counter observations,
required evidence, controlled conditions and ordered actions. A condition such
as music-first, Home, USB or wrist-down is not itself a diagnosed cause.

| Hypothesis | Named scenarios | Main discriminator |
| --- | --- | --- |
| H1: stale baseline or initialization | `retained-idle`, `phone-volume-change`, `startup-order`, `wake-timing` | Does the first timer request follow the current quiet phone level after retention/external change, and does timing/order change that result? |
| H2: stale playback association | `same-player-restart`, `source-handoff` | Does a verified phone playback change alter the retained control's destination/readiness? Pause/resume alone does not establish a new OS session. |
| H3: Crown ownership | `focus-home`, `focus-refresh` | Does input produce no native volume action until page return, versus an actual wrong scalar? A zero request means input was processed at that moment. |
| H4: native conversion/accumulation | `crown-conversion` | Does a recorded small upward physical gesture from a known nonzero baseline produce an inappropriate first value? |
| H5: scheduled host interference | `host-isolation` | Does the reference fail repeatably while a matched PR #33 build does not, with source, output and history held fixed? |
| H6: route feedback/interpretation | `route-feedback` | Does a single route transition predict failure or a state mismatch with the phone? A Watch-side zero cannot be explained by phone-only mapping. |
| H7: embedded media presentation | `media-progress` | Does embedded progress stall between source updates while phone/standalone progress advances, and do seek/reentry produce only discrete catch-up? |

Prepare a notebook for one named arm rather than improvising a broad run:

```sh
python3 scripts/physical-media-run.py catalog
python3 scripts/physical-media-run.py catalog --scenario phone-volume-change --json
python3 scripts/physical-media-run.py prepare --scenario phone-volume-change \
  --output work/support/NEW-STALE-BASELINE-RUN --build 'VERIFY INSTALLED BUILD'
```

Defaults choose Apple Music/iPhone speaker and the prepared track; these are
plans, not observed device state. Override `--source`, `--route`, `--minutes`,
`--order`, `--order-note` or `--arm` only for an explicitly recorded variant.
The default Watch bundle is the TestFlight identity,
`net.qays.TeachingTimer.watchkitapp`; use `--bundle com.qayshp.TeachingTimer` only
when the selected installation is the separate Xcode development app.

`run.json` embeds the exact selected catalog protocol so future catalog edits do
not silently change an existing run. `NEXT.md` renders its readiness checklist,
predictions, ordered actions, evidence requirements and stop/restoration steps.
It includes future device-specific inventory/app-open argv and bounded
before/failure/after journal commands, plus one per-device incident sysdiagnose
command with separate new destinations. No generated command is executed by this
helper. Sysdiagnose is conditional on an incident and authorization, not a routine
step on every clean run; a timeout requires capture inventory before any retry.
App opening is not playback: select the planned track and verify actual
phone progress/source/output through the rehearsed UI. Resolve Amazon/YouTube
bundle identifiers from the live app inventory rather than guessing them.

Before a physical session, obtain authorization and confirm live identifiers,
installed build, class/runtime intent, music availability and quiet output. One
operator owns input. Rehearse both screen-sharing views and a reversible touch,
then establish actual physical Crown input or use a human Crown operator.
Simulator input/injection helpers are not physical drivers. Readiness is still
unverified until that rehearsal; this preparation neither starts music nor
contacts devices. Lost/ambiguous UI, connection or output stops further input.

The separate [physical Device Hub helper](../tools/physical-media/README.md)
prepares bounded one-action requests, not a blind macro. Build/plan checks do not
send input. After authorization it must use a fresh successful physical-device
details receipt, exact Hub target and reviewed current display geometry; input
must not switch the selected device implicitly. Rehearse touch and Crown delivery
before using it for hypothesis evidence, and stop on an unsupported hierarchy
instead of reusing old coordinates. Its receipt proves submission only; verify
native actions and phone/audible output separately. A human Crown operator is a
valid fallback if remote Crown delivery cannot be established quickly.

Start with the working reference and phone-volume-change protocol, then separate
Home/refresh ownership and known slow Crown-conversion checks. Use matched-build
A/B, source and route arms afterward; do not change them together. A
3–5-minute fast session is a selected subset, not a promise to complete the full
catalog in that time. If a dependency or artifact is unavailable, defer that arm
and preserve its outcome as inconclusive rather than inventing a passing result.

Record a reasoned interpretation only after inspecting the evidence:

```sh
python3 scripts/physical-media-run.py assess \
  --run work/support/NEW-STALE-BASELINE-RUN --result inconclusive \
  --note 'The phone level changed, but first native request records are missing' \
  --deviation 'Control identity was not retained in the available journal'
```

`supports`, `weakens` and `mixed` additionally require saved evidence references;
those references are not copied or validated by the notebook. Assessments are
operator interpretations, never automatic native/physical pass results. The
summary retains missing assessments, deviations and inconclusive outcomes.
Free-form `prepare --arm ...` remains available for exploratory observations,
but cannot be assessed as a specified hypothesis test. System logs may not
retain native scalars or identifiers; missing records remain missing evidence.

## Stale volume-state hypothesis and separate test arms

Use **stale volume state** as the umbrella term. Two different mechanisms remain
possible: a **stale volume baseline**, where the retained native control's inner
value no longer matches the current phone volume, and a **stale playback-session
association**, where the control has not caught up with the current playback
source or endpoint. Neither mechanism is established on hardware. A control
showing a value does not identify its destination, and no response does not prove
it is controlling an old session. In the artificial Simulator experiment, a
current getter coexisted with a stale slider/sequencer; no outgoing zero or
functional native Crown response was reproduced.

The class/music-order comparison below is one test factor, not a substitute for
these stale-state checks. Prepare each as a separate arm; do not combine an
external volume change, provider handoff and route change in the same trial.

| Arm | Deliberate change while TeachingTimer's native control is retained | First-return check |
| --- | --- | --- |
| Retained/idle reference | Keep the same phone player, track, output and quiet nonzero volume through the passive Home/wrist-down interval. | Record whether the process/control was retained or recreated. Capture the ring and phone level before one small known volume-up turn. |
| External volume change: stale-baseline test | First establish working timer Crown volume at quiet level A. Leave TeachingTimer via Home without force-quitting, retaining the class and recorded runtime intent. Using only the phone's volume controls, change to a distinct but still quiet nonzero level B; keep player/track/output fixed. Record both times/levels. | Reopen the timer and capture ring versus phone level **before touching the Crown, refreshing or visiting media**. Make one small known up turn. Save the first outgoing native scalar, if logs expose it, and phone/audible result. A matching ring is useful but does not prove every inner value is current. |
| Playback-source handoff: stale-association test | After a working reference, retain the timer control via Home. Pause the current phone player and start an already available second player, keeping the output and quiet baseline as stable as possible. Ensure the first player is paused. Use Apple Music → Amazon Music only if both are usable. Label the provider change explicitly; it may also change audio-session behavior. | Confirm the phone's actual playing source/output independently, then return directly to the timer for pre-input evidence and one small known up turn. Only after preservation compare TeachingTimer's embedded media page and, separately, Apple's Now Playing app. A native source label alone does not identify the volume command's destination. |

Keep the handoff arm separate from the initial fast run if time or account access
is limited; it is part of the prepared follow-up, not a prerequisite to testing
the retained baseline. A pause/resume of the same player can be a smaller
comparison, but do not call it a new audio session unless system records establish
that. Keep runtime intent fixed for the baseline and handoff arms; do not manually
Stop it as an extra factor. Home can itself change runtime/foreground state;
record any automatic recovery as a lifecycle difference. A separate timer-selected,
wrist-down comparison can test phone volume A/B without adding Home/return.
Defer USB/AirPlay route changes to their own arms. An app relaunch, control
replacement or automatic setup on return must be recorded rather than assumed
away. Preserve the same class context; use the failure/capture and restoration
procedures below for every arm.

## Prepare before the devices are needed

- Create a private run folder, timestamp marker terminal and screenshot/recording
  destinations. Check free disk space. Have [journal copying](DIAGNOSTIC_TOOLS.md)
  and [system capture/transfer](WATCH_LOG_COLLECTION.md) commands ready with the
  **current explicit Watch and phone identifiers**, rather than historical IDs.
- Read the installed Watch build/OS, phone OS, wrist/Crown orientation, playback
  source, route and current class/session intent. Save all three journals to a
  new `journals-before` folder. Use the installed build for the reference; label
  an experimental build separately and verify any installation before testing.
- Record the current class ID/schedule, runtime state and persisted running or
  intentional-Stop intent before changing anything. Plan a supervised test class
  if none exists, or reuse the existing class with an explicit recorded running
  intent. The class/runtime start order is a test factor. Start/resume and, when
  appropriate, Stop are planned home-test steps; End, New Class, reset and a new
  installation require a separately understood fixture context. Never retire a
  real class merely to obtain a clean arm. If safely obtaining a no-runtime
  music-first arm requires clearing real context, defer and label that arm.
- Select an already playable Apple Music track. Verify the route really is the
  iPhone speaker, playback is advancing, and the current output is quiet and
  nonzero. Record its visible level; a slider screenshot is not an exact scalar
  or an acoustic measurement. Do not aim for a loud historical 0.625 merely to
  match the incident numerically.
- Confirm **audible playback before any Crown trial**, not just a Pause button,
  advancing song time or a nonzero slider. During the November 15 rehearsal, the
  user reported silent Apple Music playback and black music video with phone
  Device Hub sharing active, followed by audible playback after sharing stopped.
  Treat that as capture-related playback interference with an unconfirmed cause,
  not evidence that TeachingTimer sent zero. Stop phone screen sharing and
  confirm it is actually stopped; keep the Watch timer/control context unchanged
  where possible. Ask the operator to confirm quiet sound on the intended output
  before continuing. Record the sharing transition and audibility confirmation.
  If silence persists, stop the volume arm as a setup failure/inconclusive result.
- Prepared content choices: Brian Eno's **Thursday Afternoon** (catalog ID
  `714821163`, 60:50.8) avoids a track transition during the volume-retention arm.
  For a separate progress comparison, **An Ending (Ascent)** (catalog ID
  `714861225`, 4:26.2) makes ring advancement easier to see. These were catalog
  lookups, not a playback/subscription check. Confirm availability on the phone;
  use an already playable substitute if necessary. Keep the same content within
  a controlled comparison, and do not mix the shorter progress arm into the
  volume/startup-order comparison.
- Rehearse one Watch/phone screen capture and the already-established sysdiagnose
  action. One operator owns device input. The Simulator input helper rejects
  physical devices and must not be repurposed by removing that guard.

Prefer a short clip of the real Watch, Crown movement and phone indicator when
an existing Mac/external camera can see them. Phone screen sharing/recording is
not a neutral replacement for physical evidence: establish that it does not
change playback before using it in a later separate arm. During a phone-sharing-off
reference, use operator phone observations and time-marked Watch screenshots;
without a motion clip, keep the
operator's direction report separate from captured evidence. Avoid opening the
phone Camera app during playback: it can change the audio session. Continuous
screen sharing can affect wake/focus; establish it before the reference or leave
it disconnected throughout the passive interval and record any reconnection.
Apple documents protected-video blackout and app responses to screen capture,
but not a Device Hub-specific explanation for this observed audio silence.
See [the capture caveat](../tools/physical-media/README.md#capture-related-playback-interference)
before choosing another mirroring/recording route; DRM remains a hypothesis.

## Short reference and retained-state comparison

| Stage | Operation | Save / decision |
| --- | --- | --- |
| Class-first reference, about 60–90 s | With test music paused, open TeachingTimer. Start the planned test class/runtime if none is active, or confirm and record the reused class's explicit running intent. Dismiss the Class sheet and allow existing startup preparation to finish. Then start the phone music and record both actions' actual times. Capture the pre-input ring; make one small deliberate volume-up movement, then one small opposite movement while staying nonzero. | Record class ID, whether this was class creation or runtime Start/resume, and `start_requested`/`runtime_started` when present. Save before/after ring, direction, phone indicator/play state and marker intervals. This is not a fresh-object arm unless the journal establishes one. If music could not be paused first, label the order as reused/other rather than class-first. |
| Native media comparison, about 30 s | Visit TeachingTimer's media page. Confirm it represents the same iPhone source before making one small up/down comparison; then return to timer. | Record source/route and page times. Do not tap Play on an ambiguous Watch-local source. Stop at the failure procedure below if either control behaves unexpectedly. |
| Retained Home/music-first setup, about 30 s | In a safely reusable test context, explicitly Stop the runtime and verify the stopped intent; retain the class and native control. Go Home without force-quitting. Pause/restart the same phone music while TeachingTimer is backgrounded and no runtime is running, retaining the quiet baseline and route. Mark passive start. | Save the Stop and music-start times. Do not End/reset the class. An already running or automatically renewed runtime makes this a different arm; record it or defer the clean arm. Do not combine it with a route/provider or build change. |
| Passive, 10–15 min | Leave playback running quietly and use normal wrist-down/wake behavior; no scripted Crown input, polling gestures or repeated reconnection. | No active observation is required. Record interruptions or a system app relaunch rather than silently treating the state as retained. |
| Music-first return, about 60 s | Reopen TeachingTimer and mark foreground. Start/resume the planned class/runtime while music is already playing. Capture ring and phone level **before** Crown input; record runtime Start and any startup preparation. Make one small deliberate up movement, then one small down movement if normal. | Correlate app open, control focus, class action, `start_requested`/`runtime_started`, music start and the first outgoing native value. Confirm retained control ID/process. A relaunch is a different arm; do not hide it with retries. |
| Finish, about 30 s | Pause test music. Restore the pre-test running or intentional-Stop intent as appropriate, preserving the existing class/schedule/settings. Copy `journals-after`, mark finish and compare with the pre-test snapshot. | Record any unavoidable state change, new test-class context or changed runtime ID rather than claiming identical state. Report bounded success or the exact failed stage. Focus-call returns alone do not establish functional focus. |

The current staged setup is preserved. Once ready, input goes directly to the
native control; the operator's deliberate timing does not become a production
startup/input delay. Neither a lack of symptoms in this short run nor a returned
focus call establishes that the intermittent fault is fixed.

## On the first unexpected zero, silence or loss of response

1. Stop further Crown input. Mark the symptom immediately, preserving whether it
   is **observed zero**, **silent output**, or **no response**. Save the ring,
   phone indicator, play/pause state and route before any page change or refresh.
   Playback advancing silently is different from paused playback.
2. Copy the three small app journals first to a new `journals-failure` folder.
   Bound this initial attempt; if access stalls, proceed to system capture rather
   than spending minutes retrying the copies. A suitable prepared invocation is:

   ```sh
   python3 scripts/watch_device.py journals --device 'CURRENT_WATCH_IDENTIFIER' \
     --bundle net.qays.TeachingTimer.watchkitapp \
     --output work/support/NEW-PHYSICAL-RUN/journals-failure --timeout 8 --budget 30
   ```

3. Start one Watch and one phone sysdiagnose promptly using the rehearsed route
   in [the collection guide](WATCH_LOG_COLLECTION.md). Record the request time and
   actual acknowledgement separately. Starting capture has priority over large
   downloads or offline analysis. A timeout may leave collection in progress;
   inventory existing captures before any retry. Do not improvise button holds.
4. After preservation/capture initiation, mark one recovery attempt. Prefer the
   same-source native media page and a small up movement; if necessary use the
   phone's own volume control. Record which device/control restored sound. Save
   a post-recovery journal snapshot, then stop test music.
5. Download existing captures, retain original bytes, hash and validate gzip/tar
   integrity, and check incident-second coverage. The complete chain is request,
   acknowledgement, completed archive, transfer, validation and useful records;
   a screenshot or progress percentage does not establish all of it.

Use normal-user access first for journal copying and the Watch. Request native
administrator authentication only when the chosen phone/collection operation
actually requires it; do not store credentials or default all operations to
privilege elevation. November 14 normal-user journal/Watch capture and elevated
phone capture had different outcomes. Generic `DiagnoseError 0` is not a diagnosis.

## Precise operator markers

Use the reusable [physical-media notebook](../scripts/physical-media-run.py).
`prepare` records local metadata and writes commands for later review; it does
not contact devices or perform the planned actions. Prepare separate notebooks
for the two arms, with the intended source, route, order and installed build:

```sh
python3 scripts/physical-media-run.py prepare \
  --output work/support/NEW-PHYSICAL-RUN \
  --arm retained-music-first --source 'Apple Music, selected track' \
  --route 'iPhone speaker' --order playback-before-class \
  --order-note 'Stopped runtime before Home; Start/resume after returning' \
  --minutes 15 --build 'VERIFY INSTALLED BUILD'

python3 scripts/physical-media-run.py mark --run work/support/NEW-PHYSICAL-RUN \
  --event crown_input --intent increase --direction 'operator describes movement' \
  --magnitude 'one small turn; angle unmeasured' --note 'before first return input'
```

Review generated `NEXT.md` before device availability. Use `playback_started`,
`class_started`, `watch_foreground`, `ring_before`, `crown_input`, `ring_after`,
`incident`, `capture_started`, `recovery`, `audio_stopped` and `run_stopped` marks;
use `note` for runtime Stop, passive start/end, phone volume A/B changes, player
handoff and a gesture's end. Use `source_confirmed` and `route_confirmed` after
the change; distinguish the planned values from actually observed state. Mark whether
`class_started` means a new class, resumed runtime, or confirmation of a reused
running context. Attach saved evidence paths with `capture_saved`. Each mark
records UTC/Pacific wall time and host monotonic time. Human marks bracket actions;
they are not exact device events or proof that a prepared command ran. Use native
request timestamps and synchronized video to resolve incident seconds. Preserve
clock offsets when comparing powerlog.

## Optional follow-up: one factor per run

Only after the basic loop is usable, change one of provider (Amazon Music or an
already usable YouTube source), output (USB/AirPlay), input timing after wake,
or count vibrations. Keep track/source, route, baseline, build and transition
history otherwise fixed. Record whether a backgrounded provider actually keeps
playing; do not assume a subscription or background-playback capability. Test
PR #33 against the reference separately; do not combine it with new providers,
route changes or control replacement in the first comparison.

For frozen progress (FB25379883), capture two native positions several seconds
apart alongside independent player time and playback state, then mark one
page-away/back recovery. A separately prepared Watch-local silent-audio fixture
can test progress without a paired source; it does not test companion volume.
Its actual player clock and metadata/native extrapolation are different signals.
Retain the [October 30 evidence](MEDIA_PROGRESS_INCIDENT_2026-10-30.md), and keep
blank media, focus loss, unexpected zero and stale progress as distinct outcomes.
No unattended/overnight run is scheduled by this plan.

## November 15 supervised physical result

The physical SE 3 and paired iPhone used Beta **1.0 (261113.2020.62)**. The
volume-host-isolation experiment in PR #33 was **not installed** for this test.
These are bounded observations, not a fix or a repeatable silencing reproduction.

The initial reference was inconclusive: the operator reported a moving timer
volume ring with no useful audible result, but audible source playback had not
been independently established. The operator subsequently found that iPhone
screen sharing through Device Hub suppressed Apple Music audio and blacked out
music video on this setup. Do not classify that silence as Watch-caused muting,
or assume DRM is its established cause. This does not explain the separate
studio incident, where no Device Hub sharing was reported.

A usable reference was then established with **iPhone Mirroring** for the phone
and Device Hub sharing **only the Watch**. The iPhone's Device Hub view remained
unshared. Apple Music identified the output as iPhone to the Mac; this was not a
direct iPhone-speaker, USB or studio AirPlay test. The operator confirmed that
Crown input changed the Watch ring, phone volume and sound heard through the Mac.
No audio recording was introduced during the comparison.

| Retained-control H1 step | Observed result |
| --- | --- |
| Establish the current level A | Phone player slider approximately 55%; usable Crown/audio reference confirmed by the operator. |
| Change only the phone slider to B | Approximately 23%; the Watch ring followed without a timer refresh or page switch. |
| Drop wrist, wake and make the first small physical increase | Operator reported a normal increase from the quieter level. The captured phone slider was approximately 39%, with the same song and Mirroring route. No zero or jump to the former A was observed. |
| Check saved app journals | The same launch/native-control identities were retained. No control replacement, timer/media page change or media reload occurred during A to B and the physical increase. The runtime remained running. |

Percentages are estimates from screenshots, not public native-volume readings.
Operator reports identify physical intent and audible behavior; marker timestamps
are report times, not exact native Crown dispatch times. The first outgoing
native scalar and command destination were not captured in system records.

This **weakens H1 for an ordinary phone-volume change on this route**. It does
not rule out a stale internal sequencer under other conditions, H2's obsolete
session/endpoint association, or an intermittent USB/AirPlay failure. Preserve
those as separate hypotheses. The earlier `focus()` returns do not themselves
prove ownership; the later functional reference supplies a stronger observation.

Manual trackpad scrolling over the Device Hub replica Crown was confirmed by
the operator. The helper's single synthetic line-scroll request produced no
independently verified volume change, so it was not used as the known physical
input for the H1 result. Future automation must establish its actual delivery
and direction before interpreting a no-response result as an app failure.

All three small journals were copied and validated after the comparison. Earlier
Watch/phone sysdiagnose requests timed out without a retrieved archive; a phone
inventory showed no new capture from those requests, and the Watch inventory
also timed out. Those attempts supply no first-setter evidence. Raw screenshots,
identifiers, notebooks and journal files remain private under ignored `work/`.
The test playback was paused, its pretrial volume restored, and the temporary
class was ended after evidence collection.
