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
    exec .venv/bin/paper-search-agent offline-run "$@"
    ;;
  enrich)
    exec .venv/bin/paper-search-agent offline-enrich "$@"
    ;;
  pause)
    exec .venv/bin/paper-search-agent offline-pause "$@"
    ;;
  status)
    exec .venv/bin/paper-search-agent offline-status "$@"
    ;;
  *)
    echo "Usage: ./offline.sh {run|enrich|pause|status} [args...]" >&2
    exit 1
    ;;
esac
