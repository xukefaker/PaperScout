#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

printf '%s\n' "This legacy entrypoint has been removed. Use ./offline.sh run --mode rebuild instead." >&2
exit 1
