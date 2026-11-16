# Apple feedback status

Last inspected in Feedback Assistant on November 5, 2026, read-only. Submission
is not an Apple diagnosis or a verified fix. Raw device logs, identifiers and
private evidence packages stay outside Git. Earlier attachment/submission
results are recorded in the dated history below.

## November 13: silencing evidence is ready for submission

The [new physical incident](VOLUME_INCIDENT_2026-11-13.md) now has matched,
validated Watch and phone sysdiagnoses. Crown-associated input and a native
control action in TeachingTimer issue zero at 19:04:27 PST; the phone applies it
to its USB output. Native Now Playing supplies the recovery increases at
19:04:32–34. The native model had previously read 0.625, and the same retained
timer control later sends normal nonzero changes.

This is sufficient to report an **intermittent suspected native-control value
jump**, with exact times, build/source and capture provenance. It is not proof
of a particular framework defect. Crown direction/delta, ring appearance and a
deterministic trigger remain missing and must be explicit. Apple specifically
recommends [diagnostic logs for bugs without reliable reproduction](https://developer.apple.com/news/?id=vvrgkboh).

A concise new draft and focused source/log package are prepared privately beside
the original captures. **No new silencing report has been submitted and no FB ID
is assigned.** FB25329167 remains the separate focus-regression report; shared
causation is not established. This readiness assessment does not constitute a
new inspection of Apple's inbox or replies.

On November 14, the existing Feedback Assistant draft was revised and saved as
**Native companion volume control unexpectedly silences iPhone playback during
Crown adjustment**. Closing and reopening verified the new title and description.
The revised focused package and original paired captures are staged locally for
attachment; the draft still lists its older evidence ZIP. No Submit action or
Apple inbox/reply review occurred. The [experimental PR](https://github.com/qayshp/TeachingTimer/pull/33)
tests stable volume hosting separately; it is not a claimed fix in the report.

**November 6 project resolution:** GitHub [issue #4](https://github.com/qayshp/TeachingTimer/issues/4)
is closed as fixed by builds 33–34, supported by the reproduced mechanisms,
passing follow-up recordings and no recent owner-observed physical recurrence.
This does not change FB25329087's last inspected status below or imply that its
prepared follow-up was sent. See the [resolution](ALWAYS_ON_HAND_TRANSITION.md#resolution--november-6).

The subsequent [November 6 issue review](ISSUE_REVIEW_2026-11-06.md) also resolves
GitHub #1 (blank media) and #2 (Crown focus) using the app corrections and
follow-up evidence. FB25305069 and FB25329167 retain their separate last-inspected
statuses below. No Apple messages were sent. A new hosted awake-runtime rejection
is tracked as GitHub #27, without a new Apple report or established root cause.

## November 5 current status

| Report | Scope | Displayed resolution |
| --- | --- | --- |
| **FB25379883** | Frozen native song progress | Open |
| **FB25294079** | Paired Simulator media discovery/control | Open |
| **FB25305069** | Blank embedded native media | Open |
| **FB25347535** | Device Hub Lock documentation | Open |
| **FB25329167** | Native companion-volume Crown focus | Open |
| **FB25329087** | Always-On seconds-hand backstep | Open |
| **FB25329139** | Watch developer connection failures | Investigation complete - Unable to diagnose with current information |

The six Open reports' visible author/date lists contain the existing maintainer
messages; no new technical Apple reply was found. The connection report shows
an **Apple Feedback** message dated **October 28, 2026 at 15:28**, as displayed.
That establishes the message's displayed time, not when its resolution changed.
The November 5 Requests mailbox contains this connection report; no new technical
reply was found in the other six reports after refreshing Feedback Assistant.

The existing Apple request asks for a fresh reproduction, ideally using the
[CoreDevice logging profile](https://developer.apple.com/bug-reporting/profiles-and-logs/?name=CoreDevice),
then `xcrun devicectl diagnose`. Its output should include host and relevant-device
sysdiagnoses; collect missing captures separately. This is an older request
rechecked during today's inspection, not a new response or a completed collection.

No report, follow-up, attachment, new request or device action was made during
this Feedback Assistant inspection. Private UI text captures are retained under
the active review worktree's `work/review-2026-11-05/apple-status/`.

Useful follow-ups remain prepared or newly identified, not submitted by this review:

- **FB25329087:** send the exact-Date precision and fixed-anchor comparisons
  described below, retaining the distinction from physical validation.
- **FB25379883:** add the supervised Beta 35 comparison with standalone Now
  Playing and the recurrence on TestFlight `261104.1939.6` after timeline isolation.
- **FB25305069 / volume-silencing draft:** preserve the maintainer's November 5
  correction that neither blank media nor unexpected silencing has recurred
  since recent changes. That is mitigation evidence, not a root-cause diagnosis.
- **FB25329139:** the missing coordinated host/device capture requires a fresh
  connection failure and relevant physical devices; no substitute capture was
  attempted during the Simulator review.

The subsequent [exact-Date clock investigation](ALWAYS_ON_HAND_TRANSITION.md#november-2-exact-date-precision-diagnosis)
found context Dates one representable step below whole-second boundaries;
Calendar correctly selects the preceding second, while Unix conversion hides
the difference. This narrows the local explanation without establishing a
compositor defect or the cause of every physical report. Build 33's bounded
normalized probe corrected the exercised inputs with no measured backward tick;
build 34 also fixed the moving schedule anchor. Later results support the
project resolution above. The evidence and follow-up draft are local and have
**not been sent** to FB25329087.

## October 26–28 reporting history

| Report | Scope | October 26 action |
| --- | --- | --- |
| **FB25329087** | Seconds hand moves backward across Always-On transitions | Filed with standalone TimelineView probe, recordings, frame analysis, and comparisons. |
| **FB25329139** | Intermittent Watch developer-tunnel failure | Filed with failed/successful installs of the same build, launch verification, and collection history. |
| **FB25329167** | Native companion volume control loses Crown response after widget replacement | Filed with build-12/build-13 source comparisons, Simulator captures, and focused physical logs. |
| **FB25305069** | Embedded native Now Playing remains black after service loss | Updated with view-only recovery trials, automatic refresh, physical observations, and the separate zero-volume event's ordering. |
| **FB25294079** | Paired Simulator cannot discover/control iPhone media | Updated with the bounded Watch-local experiment and the outstanding Simulator-support question. |
| **Draft only; no submitted FB ID** | Unexpected silencing during native volume adjustment | Saved in Feedback Assistant with the October 23 timeline and focused Watch/iPhone excerpts. |

Project follow-up is tracked in [public GitHub issues](ISSUE_TRACKER.md).
No new Apple submission is implied by creating those issues.

On October 28, [FB25305069 received the recovery comparison](APPLE_MEDIA_UPDATE_2026-10-28.md),
including delayed captures and failed recovery candidates. Submission/read-back
and attachment upload completed. The connection report now reads “Investigation complete - Unable to diagnose
with current information”; no change timestamp was established. The other four
submitted reports remain Open, with no new technical reply found.
At 01:04 PDT a correction was submitted: the nine delayed captures actually
contain Not Playing, so the delayed-blank and variant-ranking claims should
be disregarded. Physical incidents remain reported and unresolved.

## Remaining evidence gaps

- **Seconds hand:** the uncorrected minimal probe reproduced in Simulator;
  the physical symptom was similar, but that probe was not tested on hardware.
  The app issue is now resolved; a fresh physical transition-time diagnostic
  would be useful if it recurs. The November 2 watchOS 27.2 comparison is
  complete locally but has not been submitted; see
  [transition investigation](ALWAYS_ON_HAND_TRANSITION.md).
- **Connection:** the Watch was already unlocked, fully awake, and on top of the
  laptop during the October 26 failure. The same build 16 installed on retry,
  with no restart, re-pairing, trust prompt, or settings change. The command
  timeout changed from 120 to 90 seconds; that is not a diagnosed remedy.
  Coordinated Mac/Watch diagnostics with CoreDevice profiles around failure
  and recovery are missing. The report states that gap and was submitted
  without the requested fresh sysdiagnose. See [collection history](WATCH_LOG_COLLECTION.md).
- **Volume focus:** retaining the widget avoided the controlled Simulator
  regression. A smaller volume-only sample and physical mitigation validation
  are still needed. Ring feedback does not prove paired-iPhone audio response,
  Crown ownership, or a silencing fix. See [focus comparison](SIMULATOR_VOLUME_FOCUS.md).
- **Black media:** original October 24 black/recovery frames are confirmed by
  the image audit; later comparison rankings were withdrawn.
  Current refresh is preventive, not blank-view detection. Two successful
  physical classes do not prove resolution. Capture any recurrence and compare
  standalone Now Playing when practical. See [service recovery](NOW_PLAYING_SERVICE_RECOVERY.md).
- **Simulator discovery:** a known-working paired-media baseline or Apple
  guidance is still needed. The unsuccessful Watch-local test does not prove
  the same cause and cannot validate physical volume behavior.
- **Silencing:** a recorded zero-volume request followed the black screenshot;
  neither causality nor a shared failure is established. Crown direction/delta,
  displayed starting level, precise endpoint state, and a deterministic trigger
  remain missing. See [physical incident](MEDIA_INCIDENT_2026-10-23.md).

The October 26 reporting work changed documentation only; the submissions did
not change the installed app or device settings. See the
[current project status](../DEVELOPMENT_STATUS.md) for subsequent source/tooling work.

## October 28 roadmap follow-through

- Filed **FB25347535**, “Document Device Hub Lock for Watch Always-On testing,”
  under Developer Tools & Resources → Developer Documentation. Submission and
  the new ID were verified at 02:13 PDT. It quotes the current instruction,
  links both official articles, describes Simulator luminance observations and
  asks Apple to clarify the supported action/limits. The evidence was included in the text and links. An attachment-button attempt
  failed in Feedback Assistant; no attachment was submitted or claimed.
- Cross-referenced it from **FB24696786** and closed that original control-
  availability report at Apple's September 22 request. This closure does not
  claim that the new documentation issue is fixed.
- Updated **FB25305069** at 02:16 PDT after the
  [original-image audit](MEDIA_IMAGE_AUDIT.md): four October 24 black captures
  are confirmed, their recovery images contain native controls, and the later
  comparison's delayed-blank/ranking claims remain withdrawn. One fresh build-21
  sequence rendered Not Playing in all six captures and passed five lifecycle
  checks. That is a bounded success, not physical resolution.
- **FB25329139** currently reads “Investigation complete - Unable to diagnose
  with current information.” The change time is unknown. Coordinate a fresh
  failure/recovery capture before sending another connection update.

The other active reports have no new technical Apple reply at the last refresh.
A check of report status is not a claim that Apple has accepted a diagnosis.
Private submission/read-back evidence stays under
`work/support/2026-10-28-next-pass/apple/`. Reports used the maintainer's requested
writing-style workflow. Neither a physical Watch nor iPhone was queried or changed.

## October 30 paired-Simulator follow-up

Sent a concise follow-up to **FB25294079** explaining that absent paired media
control blocks meaningful playback-progress, volume and recovery testing. Asked
whether NowPlayingView and companion WKInterfaceVolumeControl are supported
between paired simulators, whether setup is missing, and what alternative Apple
recommends or requires physical devices. Referenced the existing clean-pair/native
local-audio fixture. Submission is visible in the report at 00:51 Pacific; status
remains Open. This is an outgoing follow-up, not an Apple response or new evidence.

## October 30 — frozen native song progress

Filed **FB25379883**, “NowPlayingView progress freezes while Pause and volume
still work,” through Feedback Assistant. Submission was acknowledged at 23:43
PDT; FeedbackCore confirmed all attachment uploads complete at 23:44:02
(task 128032842). Attached the validated incident Watch sysdiagnose and a compact
evidence package containing three app journals, correlation notes, validation
metadata and sparse phone media-log excerpts. Raw files remain private.

The report distinguishes working Pause/volume from incorrect progress, temporary
recovery and recurrence during one song. It labels the 14:58–15:00 recollection
as approximate and 15:01/15:02 page cycles as candidate recoveries, not measured
freeze timestamps. It requests targeted logging/reproduction guidance, links
Simulator blocker FB25294079 and distinguishes blank-page FB25305069. No claim
of deterministic reproduction, root cause or validated build-25 mitigation.
See [incident assessment](MEDIA_PROGRESS_INCIDENT_2026-10-30.md).
