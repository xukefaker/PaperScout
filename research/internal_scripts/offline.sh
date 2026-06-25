#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

SUBCOMMAND="${1:-run}"
if [[ $# -gt 0 ]]; then
  shift
fi

case "$SUBCOMMAND" in
  run)
    exec .venv/bin/paperscout offline-run "$@"
    ;;
  enrich)
    exec .venv/bin/paperscout offline-enrich "$@"
    ;;
  pause)
    exec .venv/bin/paperscout offline-pause "$@"
    ;;
  status)
    exec .venv/bin/paperscout offline-status "$@"
    ;;
  *)
    echo "Usage: ./offline.sh {run|enrich|pause|status} [args...]" >&2
    exit 1
    ;;
esac
