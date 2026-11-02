#!/bin/sh
# SPDX-License-Identifier: MPL-2.0
# The default remains an unsigned, offline rehearsal for CI.
# --signed permits provisioning and a local internal-only export, never upload.
set -eu
cd "$(dirname "$0")/.."
exec python3 scripts/prepare-testflight.py "$@"
