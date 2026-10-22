#!/bin/sh
# Deterministic model/controller checks. No simulator or Watch is changed.
set -eu
cd "$(dirname "$0")/.."
check_dir=$(mktemp -d /tmp/TeachingTimerChecks.XXXXXX)
check() {
    check_name=$1
    shift
    swiftc "$@" -o "$check_dir/$check_name"
    "$check_dir/$check_name"
}
check ClassContext TeachingTimer/ClassContext.swift Tests/ClassContextChecks.swift
check Landmarks TeachingTimer/LandmarkController.swift Tests/LandmarkChecks.swift
check RuntimeJournal TeachingTimer/LandmarkDiagnostics.swift TeachingTimer/RuntimeDiagnostics.swift Tests/RuntimeDiagnosticsChecks.swift
check RuntimeRenewal -D CONTROLLER_CHECKS TeachingTimer/LandmarkDiagnostics.swift TeachingTimer/RuntimeDiagnostics.swift TeachingTimer/RuntimeRenewalRules.swift TeachingTimer/ExtendedRuntimeController.swift Tests/RuntimeRenewalChecks.swift
check LandmarkController -D CONTROLLER_CHECKS TeachingTimer/LandmarkDiagnostics.swift TeachingTimer/LandmarkController.swift Tests/LandmarkControllerChecks.swift
check LandmarkJournal TeachingTimer/LandmarkDiagnostics.swift Tests/LandmarkDiagnosticsChecks.swift
check Layout TeachingTimer/ClockGeometry.swift TeachingTimer/TimerFaceLayout.swift Tests/TimerFaceLayoutChecks.swift
check Geometry TeachingTimer/TimerFaceLayout.swift TeachingTimer/ClockGeometry.swift Tests/ClockGeometryChecks.swift
printf 'All eight suites passed. Check binaries: %s\n' "$check_dir"
