# Local artifacts and evidence

`work/` is ignored and private. Public guides describe findings; original
journals, sysdiagnoses, signed builds and raw UI captures do not belong in Git.
No memory store, device container or user-wide Xcode cache is managed here.

| Location under work/ | Meaning | Handling |
| --- | --- | --- |
| `support/YYYY-MM-DD-topic/` | Incident and test evidence: original copies, failed attempts, manifests, notes and derived analysis. | Preserve original bytes and exact failure records. Label later summaries; do not overwrite an earlier capture. |
| `checkpoints/` | Signed teaching fallback and its metadata. | Preserve until the maintainer chooses to retire it. A Git tag alone does not retain a signed installable app. |
| `device-builds/` | Prepared historical device artifacts. | Preserve signing/source provenance; do not treat them as currently installed. |
| `maintenance/YYYY-MM-DD/` | Private inventory, consistency review and cleanup/test results. | New folder per pass; catalog is an observation, not proof of archive validity. |
| `history/` | Loose early screenshots/build logs grouped with a relocation manifest. | Compatibility links preserve old paths; never substitute historical images for current screenshots. |
| `DerivedData*`, generated builds and probe outputs | Rebuildable products/caches, sometimes nested in evidence folders. | Inventory before reclaiming. Do not delete signed checkpoints or diagnostic archives based on age. |

## Inventory without modifying evidence

```sh
python3 scripts/catalog-local-artifacts.py --root work \
  --output work/maintenance/NEW-DATE/catalog
```

The output directory must be new and within ignored `work/`. The script creates a
private Markdown index and JSON inventory with sizes, file counts and artifact
locations. It does not contact devices, read journal contents, validate archives,
follow symbolic links, move or delete inputs. Output can expose personal names
and paths; do not publish it. Use archive validation records and original
operation manifests to establish collection/installation outcomes.

A generated index cannot detect every contradiction in prose. For incident
summaries, retain the original operation result and add a final reconciliation
that points to subsequent successful retries or validated archives. Failed and
partial attempts remain evidence rather than being silently relabeled success.

The historical chat working directory may no longer exist. The canonical source
checkout is `/Users/qayshp/github-clones/TeachingTimer`; use it explicitly when
running tools. Paths in private historical records remain provenance.

## November 5, 2026 cleanup

A metadata inventory preceded removal of 146 compiler-cache/intermediate
directories (32,634 generated files, about 2.10 GiB allocated). Only enumerated
`ModuleCache.noindex` and `Build/Intermediates.noindex` directories were removed;
each path was checked for symlinks and excluded from active worktrees,
checkpoints and historical device-build trees. These files regenerate on build.

Signed products, archives, build logs, raw journals, sysdiagnoses, Apple feedback
attachments and manifests were retained. The private inventory, explicit removal
plan and successful result live under `work/maintenance/2026-11-05-review/` in
the canonical checkout. This was a local cleanup, not deletion from devices or
from Git history.

## November 14, 2026 diagnostic consolidation

The successful/failing volume comparison was completed before removing redundant
local evidence. A non-following inventory and an explicit, hash-bound plan
preceded a dry run and independent review. The executed plan removed **56
enumerated targets containing 7,581 files and 6,670,898,206 apparent bytes**
(about **6.21 GiB**):

| Removed payload | Targets | Preservation proof |
| --- | --- | --- |
| Expanded older system-log archives | 11 | Every file matches its retained, fully validated compressed archive. |
| Incomplete sysdiagnose downloads | 4 | Each is an exact byte prefix of a retained complete capture. Failed-operation receipts remain. |
| Redundant outer tar containers | 2 | Retained child archives plus private reconstruction recipes reproduce every original byte and SHA-256, including wrapper metadata. |
| Duplicate compressed capture | 1 | A byte-identical canonical archive remains. |
| Nested journal-copy payloads | 38 | A byte-identical original remains; stage-specific snapshots and copy-operation receipts are preserved. |

This byte total describes removed file contents, not a guaranteed increase in
APFS free space. No unique journal or raw capture was selected simply because it
was old. The November 13 evening failure and November 14 successful comparison,
other unique open-issue evidence, Apple feedback attachments and signed teaching
checkpoints remain intact. No device contents or Git history were changed.

The private plan, hashes, file identities, reconstruction helper and before/after
receipts live under `work/support-2026-11-14-known-good/cleanup/` in the active
experimental worktree. The deletion helper defaults to dry-run; restoration
requires a new output directory. Historical records may still name removed
redundant paths; the preservation mapping identifies their retained source.
