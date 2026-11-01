#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if pgrep -x PortPocket >/dev/null; then printf 'Quit Port Pocket before updating.\n' >&2; exit 1; fi
bash "$ROOT/scripts/build.sh"
mkdir -p "$HOME/Applications"
ditto "$ROOT/build/Port Pocket.app" "$HOME/Applications/Port Pocket.app"
open "$HOME/Applications/Port Pocket.app"
