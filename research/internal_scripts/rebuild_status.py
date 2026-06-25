#!/usr/bin/env python3
from __future__ import annotations

import sys


def main() -> None:
    sys.stderr.write("This legacy entrypoint has been removed. Use ./offline.sh status instead.\n")
    raise SystemExit(1)


if __name__ == "__main__":
    main()
