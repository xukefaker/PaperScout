from __future__ import annotations


def torch_cuda_report() -> dict[str, str | bool]:
    try:
        import torch
    except Exception as exc:
        return {
            "torch_imported": False,
            "torch_version": "not installed",
            "torch_cuda_version": "",
            "cuda_available": False,
            "gpu_name": "",
            "error": repr(exc),
        }

    cuda_module = getattr(torch, "cuda", None)
    cuda_version = str(getattr(getattr(torch, "version", None), "cuda", "") or "")
    cuda_available = bool(cuda_module and cuda_module.is_available())
    gpu_name = ""
    if cuda_available:
        try:
            gpu_name = str(cuda_module.get_device_name(0))
        except Exception:
            gpu_name = "CUDA device 0"
    return {
        "torch_imported": True,
        "torch_version": str(getattr(torch, "__version__", "unknown")),
        "torch_cuda_version": cuda_version,
        "cuda_available": cuda_available,
        "gpu_name": gpu_name,
        "error": "",
    }


def require_cuda_ready(device: str | None, *, purpose: str) -> None:
    requested = (device or "").strip().lower()
    if not requested.startswith("cuda"):
        return

    report = torch_cuda_report()
    if not report["torch_imported"]:
        raise RuntimeError(
            f"{purpose} is configured to use CUDA, but PyTorch could not be imported.\n"
            "Set PAPERSCOUT_DEVICE=cpu in .env, or install a CUDA-enabled PyTorch build."
        )
    if not report["torch_cuda_version"] or not report["cuda_available"]:
        raise RuntimeError(
            f"{purpose} is configured to use CUDA, but this PyTorch install cannot use CUDA.\n"
            f"Detected: torch={report['torch_version']} torch_cuda={report['torch_cuda_version'] or 'none'} "
            f"cuda_available={report['cuda_available']}.\n"
            "Your NVIDIA GPU can be fine while the Python environment still has a CPU-only PyTorch build.\n"
            "For now, set PAPERSCOUT_DEVICE=cpu in .env and rerun. To use the GPU, install a CUDA-enabled "
            "PyTorch build for your NVIDIA driver, then verify with:\n"
            "uv run python -c \"import torch; print(torch.__version__, torch.version.cuda, torch.cuda.is_available())\""
        )
