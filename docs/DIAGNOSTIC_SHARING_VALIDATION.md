# Diagnostic sharing: validation record

November 6, 2026 · [Issue #26](https://github.com/qayshp/TeachingTimer/issues/26).
The tests below were completed under the owner's initial Simulator-only scope.
No physical device, account, recipient, backend or TestFlight distribution was
changed during those tests. The owner subsequently approved merge after review
and CI, followed by an internal TestFlight installation and sharing test after
class. That planned test is not a received-file result; delivery remains pending.
[PR #28](https://github.com/qayshp/TeachingTimer/pull/28) merged at
`3e480165d0dc2946206a18fc59478b0dabb9a8a0`.
[Release run 42278471558](https://github.com/qayshp/TeachingTimer/actions/runs/42278471558)
subsequently made **1.0 (261106.1118.29)** available to the Maintainer pilot at
11:38:20 PST: Apple processing `VALID`, testing notes, group membership and
`IN_BETA_TESTING` were read back. Upload completed at 11:33:42 PST; availability
was confirmed 277.19 seconds later. Installation and physical sharing remain
unverified. See [current status](../DEVELOPMENT_STATUS.md).

## What was tested

Xcode 27.2 (27B52), watchOS 27.2 (24S118), an existing SE 3 40 mm regression
Simulator. Local development builds were used; their version number is not a
new TestFlight release. No additional Simulator or developer platform was created.

1. Built and launched the isolated [native sharing probe](../tools/diagnostic-share-probe/README.md).
   Both the small JSON and representative report opened the native sharing
   sheet. Only Messages was offered in this configuration.
2. Opened Messages compose without choosing a recipient. Compared its staged
   attachment with the original fixture, parsed the JSON and checked SHA-256.
   Both files matched exactly:

   | Fixture | Bytes | SHA-256 |
   | --- | ---: | --- |
   | Small synthetic JSON | 139 | `c2a1150159b8a96a9ad8e4429461124e121737dd7b58e0b38ca369d22a73f26e` |
   | Representative synthetic report | 1,401,371 | `ba51781e318b926d9391ce0c6ca01a895404e9f6d29006bc0a1ce4359e1b44d1` |

3. Cancelled compose and sharing; the probe returned. This checked cancellation,
   not delivery failure or successful delivery.
4. Built Teaching Timer with the draft **Settings → About → Share diagnostics**
   flow and prepared a report from its Simulator journals. The selected two-hour
   interval produced a 7,626-byte version-1 report with 11 events. Its Messages
   compose attachment matched the prepared file exactly and parsed successfully
   (SHA-256 `73df555cdd8204776f8d76a9a017d294e53213c25fe5d44da1f73736892201c1`).

These are **app-to-system staging results**, not recipient receipts. No message
was sent. They establish that file representation and the integrated report
builder hand usable bytes to Messages in this environment. They do not establish
that a tester can deliver or retrieve the attachment, that Mail is supported,
or that a Messages-to-phone-to-email relay is practical. The support email is
not assumed to be an iMessage address.

## Automated coverage

The existing CI commands include the new tests:

- `scripts/check.sh`: 15 Swift suites, including report filtering/redaction,
  immutable file preparation and the existing session/count controllers.
- `scripts/check-tools.sh`: 275 Python tests, including nine synthetic fixture
  and received-file-verifier tests.

The report checks cover inclusive time windows, subsecond cutoff boundaries,
future-dated events after a clock correction, unknown fields and free-form
errors, consistent run-ID replacement, deterministic serialization, incomplete
sources, write failures and the 2 MiB encoded limit. Typed in-memory snapshots
preserve available timestamp precision; original disk journals may already have
whole-second timestamps.

The complete local build-verification command also passed repository/link checks,
information QR checks, the Watch Simulator build, Simulator helper builds, an
unsigned development archive and an unsigned distribution rehearsal. These do
not sign, upload or install a TestFlight build. The Swift compilation check treated
warnings as errors; Xcode separately emitted its existing AppIntents metadata
extraction warning because this app does not link AppIntents.

Snapshot checks prove that preparation does not repair or rewrite source files,
create absent journals or recovery copies, or lose queued events after failed
writes. Active controller tests using WatchKit test doubles preserve the session
object, start/invalidation
counts, saved class bytes, recovery intent, count anchor/deadline/wait and haptic
submission count. Native sharing can independently take foreground; these
preparation tests do not promise uninterrupted runtime during a share activity.

File tests cover exact hashes, atomic immutable writes, name collisions, size and
retention boundaries, unrelated files and symlinks, failed writes, protected files,
and concurrent preparation. Twelve simultaneous requests yield eight files and
four explicit capacity errors. Cleanup uses an epoch in the owned filename,
not filesystem timestamp APIs. Files are not deleted just because a view closes.

The fixture verifier is tested against synthetic inputs. Pointing it at a source
fixture validates the verifier, not native delivery. For the next delivery test,
save the attachment through the receiving app and verify that independently
received file as described in the probe README.

## Hosted PR verification

[Watch checks 42275512149](https://github.com/qayshp/TeachingTimer/actions/runs/42275512149)
passed on synthetic merge `cf929b3b1e091effee5d2972c3f16f002fdb1337`, testing code
head `684b76f`. The runner used Xcode 26.6 (17F113) and watchOS 26.5 (23T570).
Its Series 6 40 mm and Ultra 49 mm smoke checks each exercised ten app launches.
The 15 Swift suites, 275 Python tests, repository/model/QR checks, Simulator and
helper builds, and both unsigned archive paths passed. This hosted lifecycle
coverage does not exercise a recipient receiving a shared attachment.

The final PR revision, `73d5457`, changed documentation and the bundled privacy
wording. It passed a local rebuild with Swift warnings treated as errors and
repository checks before merging. The hosted result above belongs to the
earlier tested code revision; it is not relabeled as a run of the final merge.
The [final PR-head checks 42278329750](https://github.com/qayshp/TeachingTimer/actions/runs/42278329750)
subsequently completed successfully too, including their required result.

The separate [merged-main Watch checks 42278471568](https://github.com/qayshp/TeachingTimer/actions/runs/42278471568)
failed on the older watchOS 26.5 Series 6 smoke test with the existing
[awake-runtime rejection, #27](https://github.com/qayshp/TeachingTimer/issues/27#issuecomment-6693599194).
On the second running-recovery launch, native and SwiftUI state were active and
luminance was not reduced at 0.167 seconds; Start at 0.168 was rejected with code 3
at 0.344, and manual recovery was recorded at 0.345. Sharing had not been opened.
The failure artifact is preserved without a rerun. The independent release workflow
passed full verification of the same merged source with Xcode 27.2 (27B52) and
watchOS 27.2 (24S118), including ten launches each on SE 3 40 mm and Ultra 4 49 mm,
then began publishing. This is mixed CI evidence, not an all-green result or a
successful physical sharing test.

## Before this becomes a supported sharing route

- Receive small and realistic files from a physical Watch and validate exact
  filenames, sizes, hashes and contents through the receiving application.
- Repeat from TestFlight without using developer tools to extract the attachment.
- Validate cancellation, absent destinations, offline/deferred sending, wrist-down
  interruption and repeated preparation on supported watchOS versions.
- Decide whether the offered native route is simple enough. A server upload
  remains a fallback proposal, not an implemented or deployed service.
- Reconcile the actual intake route and retention with App Store privacy answers.

Keep [issue #26](https://github.com/qayshp/TeachingTimer/issues/26) open until these
gates are addressed. The owner-approved internal pilot can proceed after the
implementation review and CI pass; broader delivery claims still need these results.
