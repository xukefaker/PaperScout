# PaperScout

English | [简体中文](README.zh-CN.md)

Local paper search from your own PDFs. Add papers, build an evidence-aware index, open the web UI, and ask questions.

## Quick Start

Requirements: uv, Node.js 20+, and an OpenAI-compatible API key. PaperScout uses uv for Python environment management.

Install uv if needed:

```powershell
# Windows PowerShell
winget install --id=astral-sh.uv -e
```

```bash
# macOS/Linux
curl -LsSf https://astral.sh/uv/install.sh | sh
```

Then install and run PaperScout:

```bash
git clone https://github.com/xukefaker/PaperScout.git
cd PaperScout

uv python install 3.12
uv sync

uv run paperscout init

# edit .env:
# OPENAI_API_KEY=sk-...
# OPENAI_BASE_URL=https://api.openai.com/v1
# OPENAI_MODEL=gpt-4o-mini
# PAPERSCOUT_DEVICE=cpu

uv run paperscout doctor

mkdir -p pdfs
# put your PDFs in ./pdfs

uv run paperscout add-pdfs ./pdfs
uv run paperscout index
uv run paperscout web
```

Open `http://127.0.0.1:4000`.

Keep `PAPERSCOUT_DEVICE=cpu` unless `uv run paperscout doctor` shows `CUDA available=True`.
An NVIDIA GPU is not enough by itself: the project `.venv` must also have a CUDA-enabled PyTorch build.

## Try Demo Papers

No PDFs yet? Download 100 ACL 2025 long papers:

```bash
uv run paperscout demo-acl --max-papers 100
uv run paperscout index
uv run paperscout web
```

## Notes

- uv creates the Python environment in `.venv/` under the project root.
- PDFs and indexes stay under `data/` by default.
- Questions are sent to your configured OpenAI-compatible API.
- CPU works for small collections. Use CUDA only after `paperscout doctor` confirms PyTorch can see it.
- The first `uv run paperscout web` run installs frontend dependencies in `apps/web` if needed.
