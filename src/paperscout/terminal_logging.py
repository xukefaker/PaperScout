from __future__ import annotations

import logging
import os

from rich.console import Console
from rich.logging import RichHandler

_CONFIGURED = False

_NOISY_LOGGER_LEVELS = {
    "httpx": logging.WARNING,
    "httpcore": logging.WARNING,
    "urllib3": logging.WARNING,
    "sentence_transformers": logging.WARNING,
    "transformers": logging.WARNING,
    "pypdfium2": logging.WARNING,
    "mineru": logging.WARNING,
}


def configure_terminal_logging() -> None:
    global _CONFIGURED
    if _CONFIGURED:
        return

    level_name = os.getenv("PAPERSCOUT_LOG_LEVEL", "INFO").upper()
    level = getattr(logging, level_name, logging.INFO)
    console = Console(stderr=True, soft_wrap=True)
    handler = RichHandler(
        console=console,
        show_time=True,
        show_level=True,
        show_path=False,
        omit_repeated_times=False,
        rich_tracebacks=True,
        markup=True,
        log_time_format="%H:%M:%S",
    )
    handler.setFormatter(logging.Formatter("%(message)s"))

    root = logging.getLogger()
    root.handlers.clear()
    root.setLevel(level)
    root.addHandler(handler)

    for logger_name, logger_level in _NOISY_LOGGER_LEVELS.items():
        logging.getLogger(logger_name).setLevel(logger_level)

    _CONFIGURED = True
