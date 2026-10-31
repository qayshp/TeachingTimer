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
