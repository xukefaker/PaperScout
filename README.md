# PaperScout

English | [简体中文](README.zh-CN.md)

Local paper search for your PDF library. Drop in PDFs, build an evidence-aware index, open the web UI, and ask questions.

## Quick Start

Requirements: uv, Node.js 20+, and an OpenAI-compatible API key.

Install uv if needed:

```powershell
winget install --id=astral-sh.uv -e
```

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

Install PaperScout:

```bash
git clone https://github.com/xukefaker/PaperScout.git
cd PaperScout
```

Windows PowerShell:

```powershell
.\scripts\install.ps1
```

macOS/Linux:

```bash
./scripts/install.sh
```

The installer creates `.venv/`, installs PyTorch with uv's automatic backend selection, creates `.env`, and runs `paperscout doctor`.

Edit `.env`:

```env
OPENAI_API_KEY=sk-...
OPENAI_BASE_URL=https://api.openai.com/v1
OPENAI_MODEL=gpt-4o-mini
PAPERSCOUT_DEVICE=auto
```

## Use Your PDFs

```bash
mkdir -p pdfs
# put PDFs in ./pdfs

uv run --no-sync paperscout add-pdfs ./pdfs
uv run --no-sync paperscout index
uv run --no-sync paperscout web
```

Open `http://127.0.0.1:4000`.

During `paperscout index`, press `q` to cancel. PaperScout removes staged files from that run and keeps the previous working index.

## Try Demo Papers

```bash
uv run --no-sync paperscout demo-acl --max-papers 20
uv run --no-sync paperscout index
uv run --no-sync paperscout web
```

## Runtime Notes

- `PAPERSCOUT_DEVICE=auto` prefers CUDA or Apple MPS when PyTorch can use it.
- If no accelerator is available, PaperScout warns and continues on CPU.
- PDFs and indexes stay under `data/`.
- The first `paperscout web` run installs frontend dependencies in `apps/web` if needed.
