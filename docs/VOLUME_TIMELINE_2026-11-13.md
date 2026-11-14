# Playback and volume timeline — November 13

Amazon Music was playing before the evening class was started in TeachingTimer.
The phone began audio output at **18:48:23.457**; the Watch observed Amazon Music
playing at **18:48:24.922**. TeachingTimer returned to the foreground at
**18:55:14**, and the evening Start workflow followed at **18:55:16–17**.

This sanitized timeline extends the [physical incident report](VOLUME_INCIDENT_2026-11-13.md)
with the opening, route and playback sequence. It also supplies the historical
context for the [stable volume host experiment](VOLUME_HOST_ISOLATION.md).
Raw captures, account/device identifiers and detailed correlation records remain
private.

## Established sequence

All times are **November 13, 2026 PST (UTC−08:00)**, rounded to milliseconds.
Phone and Watch unified logs provide process, playback, route and command
evidence. The app journal provides class, runtime, page and focus-request events.
These sources describe software state; they do not measure the sound at the
external equipment or reconstruct the volume ring's pixels.

| Time | Recorded evidence |
| --- | --- |
| Before 18:43 | The previous class had been reset and its runtime ended normally at 15:02. The app then entered background. Its native volume control was retained from earlier in the day. This is the last recorded app state before the requested interval. |
| 18:45:33.171–.178 | watchOS reports TeachingTimer suspended and not visible. Clock-face complication activity is a separate surface and does not establish that TeachingTimer opened. The owner confirms that **18:45 remained the correct scheduled class anchor** when the evening class was started later. |
| 18:48:08.222–.437 | The phone registers **AB13X USB Audio** and routes to it. Its route notification supplies volume **0.71425**. The Watch mirrors speaker removal, a brief empty-output/default-zero state, then USB output with Absolute volume capability and **0.71425**. This initialization zero is distinct from an outgoing mute request. |
| 18:48:12.557; 18:48:16.649 | Amazon Music is freshly spawned on the phone; its scene subsequently changes to foreground. Process creation and scene presentation are separate observations. The exact physical opening gesture is unrecorded. |
| 18:48:23.457–24.922 | Phone audio logs begin Amazon's unmuted output. Phone MediaRemote changes Paused → Playing at **23.954** and playback rate to 1 at **23.955**. The Watch receives Paused → Playing at **24.922**; its next explicit playback-state fetch also returns Playing. |
| 18:48:26.939–33.451 | Phone SpringBoard issues volume operations: **0.71425 → 1**, then decreases to **0.625**. The phone observes the final level at **33.348** and the Watch observes it at **33.451**. These records identify phone-side operations; hardware buttons versus phone UI are unresolved. |
| 18:48:34.447–35.239 | Phone unified logs record display-off with a LockButton source, then locked state at **35.167**. Amazon becomes not visible while playback continues. No later phone lock/display transition is established through the incident window. |
| 18:55:14.081–.265 | TeachingTimer becomes foreground/visible on the Watch. Its journal resumes on the timer page with the previous runtime stopped. This is an app return, before the evening class-start workflow, rather than a fresh process launch. |
| 18:55:14.212–.347 | The app's old remote-device proxy disconnects with an XPC interruption; a replacement connects. MediaPlayer briefly reports **0 / unavailable / None**, then two endpoint reads return **0.625** and the model becomes available with Absolute capability. The zero-to-correct-model interval is about **41 ms**, ending about **2.58 seconds before** the Start request. No outgoing TeachingTimer zero request occurs here. |
| 18:55:15.286–17.002 | The class-options sheet is requested. The Start workflow records a new class identity timestamp of **18:55:16**, requests the runtime at **16.926**, saves class context at **16.947**, and confirms the runtime running at **17.002**. The exact touch instant and initial-start subsecond value are not exported. Runtime start does not replace the **18:45 scheduled anchor**. |
| 18:55:18.028–.330 | Background-return setup reuses the existing native volume control, calls resign-focus, then focus; the calls return. The journal explicitly leaves actual focus unobserved. |
| 18:55:59.944–.982 | TeachingTimer selects its media page, refreshes the media host and resigns the timer volume control's focus. This is the first recorded evening media-page selection in the app. |
| 18:57:38.074; 19:01:47.366 | Long dimmed wakes trigger additional media-host refreshes while the media page remains selected. These events do not establish a black/frozen page or an audio repair. |
| 19:04:04.254–.486 | Another long dimmed wake refreshes the media host. Fresh endpoint reads return **0.625** at **04.483**; its MediaPlayer model logs **0.625** at **04.486**. |
| 19:04:05.052–.486 | The timer page is selected at **05.052**. The retained volume control's focus call returns at **05.062**. A separate six-landmark count begins at **05.486**, using ten-second intervals. |
| 19:04:22.628–.737 | After several dim/inactive and wake transitions, the timer scene becomes active with full luminance. watchOS also reports an awake, unlocked Watch before Crown input. These are state observations, not a ring image. |
| 19:04:25.532–26.527 | Two count haptics are submitted. Their Watch-local vibration-only actions finish before the first logged Crown scroll. Haptic policy explicitly disallows setting route or volume; no local audio operation bridging them to the companion zero was found. |
| 19:04:26.636–27.048 | Crown-associated Scroll events reach the TeachingTimer window. At **27.047**, UIKit dispatches a control action; its activity then issues TeachingTimer's explicit companion-volume request of **0** at **27.048**. Twenty-five Scroll routing records precede the write; input continues afterward. Direction, magnitude and the native ring value are unavailable. |
| 19:04:27.140–.193 | The phone receives the matching companion volume message and requests endpoint **0**. Its audio logs then record USB hardware mute and an observed **0.625 → 0** change at **27.193**. Hardware mute follows the request. Amazon receives the zero-volume notification. |
| 19:04:31.210–.397 | TeachingTimer selects its media page, refreshes the media host and resigns the timer volume control's focus. Fresh endpoint reads correctly return **0**. The native media service survives; view reconstruction is separate from a process restart. |
| 19:04:32.431–34.535 | Native Now Playing issues **28 increasing volume requests**, **0.016406 → 0.784375**. The phone observes the final level at **34.524**; TeachingTimer receives it at **34.535**. This establishes software volume recovery. Audible recovery is separately owner-reported. |
| 19:04:35.588–.606 | The timer page is selected again and its retained native control's focus call returns. Count pulses continue; no volume-control replacement is recorded. |
| 19:05:52.504–53.062 | TeachingTimer itself issues gradual nonzero changes, **0.77875 → 0.73975 → 0.73825 → 0.737875**, and receives acknowledgments. Through 19:06, the journal retains the same running evening runtime without a restart or expiration. |

The phone's historical powerlog requires its stored clock offset before comparison
with unified logs. After calibration and cross-checking matching volume changes,
incident battery samples are approximately **66%**. The earlier uncalibrated
**63%** and **18:55:08 lock** claims were withdrawn. The lock sequence above is
directly supported by unified logs at **18:48:34–35**. These corrected state facts
do not explain why the Watch selected zero.

## What can be said about redraw and native state

The journal records one native companion-volume control creation at
**12:23:35.580**, followed by continued use of the same recorded object. It records
no later replacement or dismantling in this report. That object spans route and
playback changes while the app is suspended, followed by the remote-proxy
replacement on return.

Creation, model reload, focus requests and painting are different events. The
saved records establish the **18:55:14 model reload**, the **18:55:18 and
19:04:05 focus calls**, and the later explicit volume commands. They do **not**
record when the native control was painted or redrawn. A one-second clock
schedule, a retained object identity, a returned focus call or a visible app
window cannot supply that missing measurement.

The process did obtain the correct **0.625** value before class start, and native
Now Playing fetched it again immediately before the timer-page interaction.
Those are positive synchronization observations. The private controller prefixes
do not identify every native child object, and the captures do not reveal its
slider value, interaction accumulator or complete subscription state.

## Direct findings and remaining hypotheses

The direct chain is **music already playing → TeachingTimer foreground return
and correct nonzero model → later Crown-associated control action → explicit
zero sent to the same phone USB route → native media-page increases → later
normal timer-side changes**. The zero is separate from the earlier route and
model initialization zeros.

A retained native interaction baseline becoming inconsistent across suspension,
proxy replacement, focus or display transitions is a plausible engineering
hypothesis. The brief unavailable/default-zero model on return supplies a
specific readiness boundary to test. It does not prove that an inner control
latched zero: the process corrected its model within about 41 ms, and the
explicit zero occurred more than nine minutes later. A large, accelerated or
coalesced downward Crown movement reaching minimum remains possible because
signed input and the ring display were not captured.

The [stable volume host experiment](VOLUME_HOST_ISOLATION.md) changes the rendering
boundary while preserving control identity, class/runtime/count owners and
focus policy. It remains an isolation experiment, not proof that this native
state boundary is repaired. **Music before class is a useful test
sequence** and should be preserved in comparison runs; changing that order is
not an established remedy. The [incident report](VOLUME_INCIDENT_2026-11-13.md)
contains the broader evidence limits and physical-validation requirements.
