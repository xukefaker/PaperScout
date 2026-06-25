from __future__ import annotations

import importlib.util
from pathlib import Path
import sys

import pytest


def _load_driver_module():
    module_path = Path(__file__).resolve().parents[1] / "internal_scripts" / "mineru_pipeline_cache_driver.py"
    spec = importlib.util.spec_from_file_location("mineru_pipeline_cache_driver", module_path)
    assert spec is not None
    assert spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def test_requested_ids_override_skip_file_for_targeted_reruns(tmp_path: Path) -> None:
    driver = _load_driver_module()
    pdf_dir = tmp_path / "pdfs"
    output_dir = tmp_path / "parsed"
    pdf_dir.mkdir()
    output_dir.mkdir()
    (pdf_dir / "paper-a.pdf").write_bytes(b"%PDF-1.4\n%fake\n")

    pending, missing = driver._iter_pending_pdfs(
        pdf_dir,
        output_dir,
        skip_ids={"paper-a"},
        requested_ids=["paper-a"],
    )

    assert missing == []
    assert [path.stem for path in pending] == ["paper-a"]


def test_load_id_file_strict_mode_rejects_missing_and_empty_files(tmp_path: Path) -> None:
    driver = _load_driver_module()
    missing_path = tmp_path / "missing_ids.txt"
    with pytest.raises(FileNotFoundError):
        driver._load_id_file(missing_path, strict=True)

    empty_path = tmp_path / "empty_ids.txt"
    empty_path.write_text("\n# comment only\n", encoding="utf-8")
    with pytest.raises(RuntimeError):
        driver._load_id_file(empty_path, strict=True)


def test_load_id_file_strict_mode_deduplicates_and_skips_comments(tmp_path: Path) -> None:
    driver = _load_driver_module()
    id_path = tmp_path / "paper_ids.txt"
    id_path.write_text("paper-a\n# ignore\npaper-b\npaper-a\n", encoding="utf-8")

    ids = driver._load_id_file(id_path, strict=True)

    assert ids == ["paper-a", "paper-b"]
