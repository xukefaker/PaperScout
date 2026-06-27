from __future__ import annotations

import sys
from pathlib import Path

import pytest

from paperscout.mineru_pipeline import BatchItem, _run_batch
from paperscout.models import PaperRecord


def _batch_item(pdf_path: Path) -> BatchItem:
    return BatchItem(
        paper=PaperRecord(
            paper_id="paper-1",
            title="Paper 1",
            venue="test",
            year=2026,
            track="demo",
            url=pdf_path.as_uri(),
            pdf_url=pdf_path.as_uri(),
            local_pdf_path=str(pdf_path),
        ),
        pdf_path=pdf_path,
        pages=1,
    )


def test_run_batch_quiet_output_hides_noisy_parser_output(tmp_path: Path, monkeypatch, capsys) -> None:
    pdf_path = tmp_path / "paper.pdf"
    pdf_path.write_bytes(b"%PDF-1.4\n")
    monkeypatch.setattr("paperscout.mineru_pipeline.read_fn", lambda path: b"pdf")

    def _fake_parse(**kwargs) -> None:
        print("noisy stdout")
        print("noisy stderr", file=sys.stderr)

    monkeypatch.setattr("paperscout.mineru_pipeline.do_parse", _fake_parse)

    _run_batch(
        [_batch_item(pdf_path)],
        output_dir=tmp_path / "out",
        lang="en",
        parse_method="txt",
        backend="pipeline",
        formula=False,
        table=True,
        quiet_output=True,
    )

    captured = capsys.readouterr()
    assert "noisy" not in captured.out
    assert "noisy" not in captured.err


def test_run_batch_quiet_output_exposes_text_stream_attributes(tmp_path: Path, monkeypatch) -> None:
    pdf_path = tmp_path / "paper.pdf"
    pdf_path.write_bytes(b"%PDF-1.4\n")
    monkeypatch.setattr("paperscout.mineru_pipeline.read_fn", lambda path: b"pdf")

    def _fake_parse(**kwargs) -> None:
        assert sys.stdout.encoding
        assert sys.stderr.encoding
        assert not sys.stdout.isatty()

    monkeypatch.setattr("paperscout.mineru_pipeline.do_parse", _fake_parse)

    _run_batch(
        [_batch_item(pdf_path)],
        output_dir=tmp_path / "out",
        lang="en",
        parse_method="txt",
        backend="pipeline",
        formula=False,
        table=True,
        quiet_output=True,
    )


def test_run_batch_quiet_output_keeps_failure_tail(tmp_path: Path, monkeypatch) -> None:
    pdf_path = tmp_path / "paper.pdf"
    pdf_path.write_bytes(b"%PDF-1.4\n")
    monkeypatch.setattr("paperscout.mineru_pipeline.read_fn", lambda path: b"pdf")

    def _fake_parse(**kwargs) -> None:
        print("parser tail")
        raise ValueError("boom")

    monkeypatch.setattr("paperscout.mineru_pipeline.do_parse", _fake_parse)

    with pytest.raises(RuntimeError, match="MinerU output tail"):
        _run_batch(
            [_batch_item(pdf_path)],
            output_dir=tmp_path / "out",
            lang="en",
            parse_method="txt",
            backend="pipeline",
            formula=False,
            table=True,
            quiet_output=True,
        )
