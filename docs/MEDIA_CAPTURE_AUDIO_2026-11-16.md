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

The most specific new clue is the saved system notice:

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
2. **Test Amazon's voice-mode lead.** Record Hands-Free state and the microphone
   notice, then compare with Hands-Free disabled, keeping track, format and
   output fixed. Restore the original preference afterward. A coincident notice
   alone is not a successful diagnosis.
3. **Distinguish capture policy from general audio delivery.** Use the existing
   [unprotected phone audio fixture](../tools/phone-audio-probe/README.md) as a
   separate reference. Verify that it is audible on physical hardware first;
   use actual audio rather than an all-zero/silent fixture for this check.
   Fixture success would narrow the failure to the media/provider path, not
   prove DRM was the cause.
4. **Compare format only if needed.** Use Amazon's quality panel to keep the
   same track and change only stereo/spatial or delivery quality. The existing
   two-track observation is not a controlled codec comparison.
5. **Preserve a contemporaneous failure capture before recovery.** Record the
   first audible/silent transition, active player, route and both endpoint gains.
   A completed phone capture would be needed for its audio-session/route/policy
   evidence; Watch journals alone cannot provide it. Record any background Mac
   audio-capture activity as another factor rather than silently changing it.

Only after reliable source audibility is established should the separate
TeachingTimer stale-baseline/session tests resume. Phone screen sharing must not
be treated as a neutral observer of playback, and these setup failures do not
explain the independently captured November 13 studio zero-volume command.
Amazon through Device Hub and all YouTube Music paths remain untested.
