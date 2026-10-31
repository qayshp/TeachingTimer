# TeachingTimer working instructions

## Simulator runtime policy

- Create or boot Simulators only when needed for the current task. Do not
  repopulate the deleted device matrix merely to restore historical test IDs.
- Before creating or choosing a test device, query the selected Xcode and its
  available runtimes. Use the newest available compatible iOS and watchOS runtime
  for each platform; inspect the build and supported device types when multiple
  runtimes share a version. A device-specific runtime is not a general replacement.
- Resolve device identifiers live. Do not reuse historical UUIDs or pin new
  devices to old runtime versions from scripts, notes, screenshots or prior runs.
- If the newest required runtime is unavailable or incompatible, report that
  condition before falling back to an older one. Historical comparisons on an
  older OS require an explicit test purpose. Preserve original OS/build labels
  on existing evidence.
- Prefer the current selected Xcode's SDKs for new builds. Do not change physical
  devices or install developer platforms merely to satisfy a Simulator check.
