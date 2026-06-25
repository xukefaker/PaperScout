from __future__ import annotations

import sys
import types

from paperscout.encoders import EncoderConfig, SentenceTransformerEncoder
from paperscout.reranker import CrossEncoderReranker, RerankerConfig


def _install_fake_torch(monkeypatch, *, cuda_available: bool) -> None:
    monkeypatch.setitem(
        sys.modules,
        "torch",
        types.SimpleNamespace(cuda=types.SimpleNamespace(is_available=lambda: cuda_available)),
    )


def test_sentence_transformer_encoder_prefers_cuda_when_available(monkeypatch) -> None:
    calls: list[dict[str, object]] = []

    class _FakeSentenceTransformer:
        def __init__(self, model_name: str, **kwargs) -> None:
            calls.append({"model_name": model_name, "kwargs": kwargs})

    _install_fake_torch(monkeypatch, cuda_available=True)
    monkeypatch.setitem(
        sys.modules,
        "sentence_transformers",
        types.SimpleNamespace(SentenceTransformer=_FakeSentenceTransformer),
    )

    encoder = SentenceTransformerEncoder(EncoderConfig("test-model"))

    assert encoder.device == "cuda:0"
    assert calls == [{"model_name": "test-model", "kwargs": {"device": "cuda:0"}}]


def test_sentence_transformer_encoder_falls_back_to_cpu(monkeypatch) -> None:
    calls: list[dict[str, object]] = []

    class _FakeSentenceTransformer:
        def __init__(self, model_name: str, **kwargs) -> None:
            calls.append({"model_name": model_name, "kwargs": kwargs})

    _install_fake_torch(monkeypatch, cuda_available=False)
    monkeypatch.setitem(
        sys.modules,
        "sentence_transformers",
        types.SimpleNamespace(SentenceTransformer=_FakeSentenceTransformer),
    )

    encoder = SentenceTransformerEncoder(EncoderConfig("test-model"))

    assert encoder.device == "cpu"
    assert calls == [{"model_name": "test-model", "kwargs": {"device": "cpu"}}]


def test_cross_encoder_reranker_prefers_cuda_when_available(monkeypatch) -> None:
    calls: list[dict[str, object]] = []

    class _FakeCrossEncoder:
        def __init__(self, model_name: str, **kwargs) -> None:
            calls.append({"model_name": model_name, "kwargs": kwargs})

    _install_fake_torch(monkeypatch, cuda_available=True)
    monkeypatch.setitem(
        sys.modules,
        "sentence_transformers",
        types.SimpleNamespace(CrossEncoder=_FakeCrossEncoder),
    )

    reranker = CrossEncoderReranker(RerankerConfig("test-reranker"))

    assert reranker.device == "cuda:0"
    assert calls == [{"model_name": "test-reranker", "kwargs": {"trust_remote_code": True, "device": "cuda:0"}}]
