# Apple feedback status

Refreshed and inspected in Feedback Assistant on October 28, 2026. All submitted attachment
uploads completed. Submission is not an Apple diagnosis or a verified fix.
Raw device logs, identifiers, and private evidence packages stay outside Git.

| Report | Scope | October 26 action |
| --- | --- | --- |
| **FB25329087** | Seconds hand moves backward across Always-On transitions | Filed with standalone TimelineView probe, recordings, frame analysis, and comparisons. |
| **FB25329139** | Intermittent Watch developer-tunnel failure | Filed with failed/successful installs of the same build, launch verification, and collection history. |
| **FB25329167** | Native companion volume control loses Crown response after widget replacement | Filed with build-12/build-13 source comparisons, Simulator captures, and focused physical logs. |
| **FB25305069** | Embedded native Now Playing remains black after service loss | Updated with view-only recovery trials, automatic refresh, physical observations, and the separate zero-volume event's ordering. |
| **FB25294079** | Paired Simulator cannot discover/control iPhone media | Updated with the bounded Watch-local experiment and the outstanding Simulator-support question. |
| **Draft only; no submitted FB ID** | Unexpected silencing during native volume adjustment | Saved in Feedback Assistant with the October 23 timeline and focused Watch/iPhone excerpts. |

Project follow-up is now tracked in [six public GitHub issues](ISSUE_TRACKER.md).
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

- **Seconds hand:** the minimal probe reproduces in Simulator; the physical
  symptom is similar, but that probe was not tested on hardware. A fresh
  transition-time diagnostic and a newer watchOS runtime comparison remain
  useful. See [transition investigation](ALWAYS_ON_HAND_TRANSITION.md).
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
- **Black media:** earlier view-only trials reported recovery; their image
  classifications need revalidation.
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
  asks Apple to clarify the supported action/limits. No device-log attachment
  was needed for this documentation-only report.
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
