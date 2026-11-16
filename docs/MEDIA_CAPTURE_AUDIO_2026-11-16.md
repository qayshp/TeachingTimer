# Capture-related audio silence: November 16 investigation

Offline follow-up to the [November 15 physical media experiments](PHYSICAL_MEDIA_TEST_PLAN.md#november-15-supervised-physical-result).
Physical-device testing remains paused. This investigation reads saved artifacts,
existing historical Mac logs and public documentation; it does not reconnect to
devices, change settings, start playback or test a new app build.

## Findings and limits

The two failures concern different phone-screen transports and should not be
combined into one diagnosed bug. Apple documents Mac audio output and unavailable
iPhone microphone access for iPhone Mirroring. That contract does not establish
how Device Hub forwards physical-device audio, or explain either observed silence.
[Apple's iPhone Mirroring guide](https://support.apple.com/en-us/120421)

| Condition | Established evidence | What it does not establish |
| --- | --- | --- |
| Apple Music with phone Device Hub sharing | Operator reported silent audio and black music-video content. Saved player UI shows advancing time and a nonzero phone level. | Audible playback was not independently established before the first Crown test. Output was changed during troubleshooting; this was not a controlled same-route sharing-on/off comparison. |
| Apple Music through iPhone Mirroring | Operator confirmed audible Mac output and working timer Crown volume. | The path differs from direct iPhone speaker, studio USB audio and phone Device Hub sharing. |
| Amazon Music through iPhone Mirroring | Native microphone-unavailable notice, advancing player UI, laptop output indication and nonzero phone media level. Operator reported silence before any post-handoff Crown input; one phone Play retry remained silent. | No active audio-session category, speaker-rendered samples, native endpoint UID or per-source output gain was captured on the phone. |
| Amazon through direct iPhone speaker | Audible; a timer Crown increase raised sound and ring after TeachingTimer was reopened. | Automatic runtime recovery/refocus intervened. This does not rule out the separate stale playback-session association hypothesis. |

The original November 15 session has screenshots, host input receipts and app
journals, but no completed phone or Watch sysdiagnose for these interactions.
Both fresh capture requests timed out. The phone's inventoried older archives
predate the trial and cannot supply its missing native audio events. Later Mac
historical-log observations are a separate evidence source, not a recovered
phone or Watch capture. Raw artifacts and identifiers remain private in ignored
`work/`.

## Additional historical Mac evidence

A read-only November 16 query of the Mac's persisted logs recovered host-side
events for the earlier test periods. It did not contact a phone or Watch. The
retained coverage is uneven: the early Apple Music windows contain little of
the audio-service detail retained for the later Amazon window. Absence of an
earlier error or capture-client message is not a valid comparison.

- During Amazon's silent period, `coreaudiod` recorded the built-in speaker
  at nonzero gain with mute off around 11:37–11:38 and 11:42 a.m. Pacific.
  This argues against a global built-in-speaker mute at those samples. It does
  not prove Amazon was delivering samples to that output, exclude per-source
  gain or establish the route at every instant.
- A background Mac system-audio client negotiated repeatedly around the silent
  interval. The experiment did not deliberately start an audio recording, but
  the host cannot be described as capture-free. These events establish client
  negotiation, not continuous recording, delivered samples or a DRM decision.
  Whether that activity affected the mirrored player is another test variable.
- Host app messages do not expose a specific Amazon audio-policy refusal or a
  zero-volume command. Mirroring's logging was rate-limited before Amazon was
  opened; that limits diagnosis. The log's quarantine wording refers to
  **logging volume**, not quarantined playback or a proven audio failure.

Exact queries, time-zone labels, retained records and hashes remain private.
These records improve the output/capture context but do not replace the missing
phone audio-session evidence.

## Codex system-audio client follow-up

Read-only inspection of the installed Codex app identifies
`system-audio-spectrum` as the helper for **Settings → General → Toys → Audio
visualizer**, the optional audio-reactive conversation rail. The inspected app
is version **26.1111.21308 (27194)**. This is today's installed implementation,
not cryptographic proof of the exact binary running in the historical trial.
The helper was never executed for this investigation.

The native helper creates a global stereo Core Audio process tap with an empty
process-exclusion list, feeds a private aggregate device, and computes frequency
levels with FFT operations. The app receives 24 numeric levels for the visualizer.
This path is output capture, not a direct microphone selection. Input-device
negotiations in daemon logs do not prove that those microphones were recorded.
The parent starts the helper on its first subscriber and stops it when the last
subscriber leaves; visible enabled rails can subscribe, while hidden documents
and reduced-motion state gate subscription. That lifecycle can cause starts and
stops, but it does not prove the timing of historical helper restarts.

Static disassembly shows an explicit **unmuted** tap setting. Apple documents
that this setting preserves hardware playback while capturing. The helper's
imported API surface contains property reads, not direct volume or default-device
setters. This argues against deliberate source muting or a direct volume-zero
setter in this implementation. It does not rule out a Core Audio interaction,
format/routing problem or a producer reacting to capture.
[Apple's tap mute behavior](https://developer.apple.com/documentation/coreaudio/catapmutebehavior),
[Core Audio tap architecture](https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps)

The historical named-client records establish repeated format negotiation.
Some client-scoped blocks contain unsupported virtual-input voice-processing
negotiation errors. These are not an identified Amazon output failure. Other
records show recording clients starting and stopping near the negotiation
bursts, but their numeric identities cannot be tied conclusively to this helper
from the saved rows. The original export remains preserved; a later broader
historical query returned no timestamped rows and cannot fill the lifecycle gap.

Two open reports in OpenAI's repository describe this visualizer interfering
with dictation or other microphone apps, with users reporting recovery after
disabling it. These are primary user observations, not an OpenAI confirmation
of our mirrored-music symptom. They make unintentional tap/Core Audio contention
a concrete test candidate; they do not establish protected-music suppression.
[Visualizer blocks dictation, #42229](https://github.com/openai/codex/issues/42229),
[Dictation startup stalls, #44596](https://github.com/openai/codex/issues/44596)

No inspected Apple contract says that simply starting an unmuted output tap
must silence protected music through iPhone Mirroring. Capture omission and
actual speaker silence are different observations. No Codex setting, permission,
audio service, process or device state was changed for this follow-up. Bundled
implementation excerpts, hashes and static-analysis receipts remain private;
no proprietary app source or binary is added to this repository.

## Apple Music and Device Hub

The black-video observation is **consistent with protected-video capture
handling**. Apple documents automatic exclusion of FairPlay-protected video,
while audio protection requires additional app behavior. Its screen-capture
documentation also explains that apps can react to being captured. Therefore
black video is not proof that the system automatically muted the music.
The older `isCaptured` API is deprecated in favor of scene capture state; this
is documentation of capture behavior, not a proposal to add that old API to
TeachingTimer. [Apple's capture documentation](https://developer.apple.com/documentation/uikit/uiscreen/iscaptured)

The leading investigation branches are:

- **Capture-policy or protected-output interaction:** the player or system may
  treat the developer capture path differently from iPhone Mirroring. This fits
  the observed difference, but no policy-denial event has been established.
- **Route or gain changed by the capture setup:** the first intended route was
  iPhone speaker; a later screenshot shows a TV selected after the initial
  unsuccessful adjustment. Do not attribute that later route to the earlier
  gesture or assume the entire period had one output. A nonzero phone slider
  alone cannot establish the final audible output or all downstream gains.

Apple also documents camera/microphone access conflicts while controlling a
physical device in Device Hub. Those concern input sensors, not a published
explanation for silent Apple Music playback. The Device Hub audio-I/O controls
documented for **simulated devices** are not evidence of the physical phone's
audio transport. [Physical-device interaction limits](https://developer.apple.com/documentation/xcode/interacting-with-your-app-in-device-hub),
[Simulator audio configuration](https://developer.apple.com/documentation/xcode/configuring-the-environment-of-a-simulated-device)

No inspected Device Hub documentation or [Xcode 27.2 release note](https://developer.apple.com/documentation/xcode-release-notes/xcode-27_2-release-notes)
identifies this exact Apple Music silence as an intended restriction or a known
fixed issue. That search result is not proof that the behavior is unsupported.

## Amazon Music and iPhone Mirroring

Another specific clue is the saved system notice:

> iPhone microphone is not available from Mac.

It appears on Amazon launch and was acknowledged before playback. Apple's
Mirroring guide documents that microphone limitation. Amazon documents a
configurable **Hands-Free with Alexa** mode in its iPhone app, as well as a
separate Alexa-button voice mode. An input/voice-session interaction is therefore
a useful first comparison. We have not established that Hands-Free was enabled,
that Alexa triggered the notice, or that a microphone restriction caused audio
output to fail. The notice is not an output-denied message.
[Amazon's voice-mode instructions](https://digprjsurvey.amazon.co.uk/csad/help/node/TzbKcMj0RrHqG25TrM)

Audio-session configuration and routing are another branch. Apple's public
categories distinguish playback-only from input/output sessions. Those contracts
do not reveal which category Amazon used, and traditional AirPlay category rules
must not be assumed to describe iPhone Mirroring's transport.
[Playback category](https://developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/playback),
[Input/output category](https://developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/playandrecord)

An **Atmos-only explanation is insufficient** for the saved observations. The
first silent player is labelled UHD; a later, different track is labelled Dolby
Atmos. Neither badge proves which samples were actually rendered. Amazon's
quality panel can distinguish current quality, source capability, playback device
and output, and offers a stereo/spatial comparison. Capture that detail in a
later test rather than inferring it from a badge. First compare the same UHD
track across capture methods; do not change track and format together.
[Amazon's audio-quality guide](https://digprjsurvey.amazon.com/csad/help/node/GN6KRDWLKJ6FR9LJ)

No official Apple or Amazon acknowledgment of this exact Amazon/Mirroring
failure was located. Apple's general warning about premium **video** restrictions
does not establish a policy forbidding Amazon music through Mirroring.

## Later supervised comparisons, in priority order

These are plans only; none is executed by this offline investigation.

1. **Separate capture from Crown behavior.** With no Watch adjustment, use one
   fixed, already playable track and a quiet audible reference. Compare no phone
   sharing with Device Hub sharing, then separately with iPhone Mirroring.
   Record actual route changes as well as phone and Mac output/mute levels.
   If a transport necessarily changes the output, label the result as a combined
   capture/route comparison rather than a pure capture-state test.
2. **Isolate the Codex visualizer.** For the same Amazon track and Mirroring/Mac
   output, establish a quiet reference with the visualizer off and verify its
   helper is absent. Compare with it on, then off again if needed, without Watch
   input or volume/route changes. Preserve evidence before recovery and record
   any normal app restart as an additional transition. Do not reset Core Audio
   or permissions as part of this comparison. This plan does not change the
   setting during the paused investigation.
3. **Test Amazon's voice-mode lead.** Record Hands-Free state and the microphone
   notice, then compare with Hands-Free disabled, keeping track, format and
   output fixed. Restore the original preference afterward. A coincident notice
   alone is not a successful diagnosis.
4. **Distinguish capture policy from general audio delivery.** Use the existing
   [unprotected phone audio fixture](../tools/phone-audio-probe/README.md) as a
   separate reference. Verify that it is audible on physical hardware first;
   use actual audio rather than an all-zero/silent fixture for this check.
   Fixture success would narrow the failure to the media/provider path, not
   prove DRM was the cause.
5. **Compare format only if needed.** Use Amazon's quality panel to keep the
   same track and change only stereo/spatial or delivery quality. The existing
   two-track observation is not a controlled codec comparison.
6. **Preserve a contemporaneous failure capture before recovery.** Record the
   first audible/silent transition, active player, route and both endpoint gains.
   A completed phone capture would be needed for its audio-session/route/policy
   evidence; Watch journals alone cannot provide it. Record any background Mac
   audio-capture activity as another factor rather than silently changing it.

Only after reliable source audibility is established should the separate
TeachingTimer stale-baseline/session tests resume. Phone screen sharing must not
be treated as a neutral observer of playback, and these setup failures do not
explain the independently captured November 13 studio zero-volume command.
Amazon through Device Hub and all YouTube Music paths remain untested.
