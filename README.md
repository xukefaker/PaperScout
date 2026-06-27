# PaperScout

![Python](https://img.shields.io/badge/python-3.11%20%7C%203.12-blue)
![uv](https://img.shields.io/badge/env-uv-4B32C3)
![Platforms](https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20Windows-lightgrey)

Local paper search for your PDF library.

Drop PDFs into a folder, build an evidence-aware local index, then ask questions from the web UI.

- Bring your own PDFs.
- Parse paper text, sections, figures, and tables.
- Search and ask with cited evidence.

## Quick Start

Requirements: `uv`, Node.js 20+, and an OpenAI-compatible API key.

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
git clone https://github.com/xukefaker/PaperScout.git
cd PaperScout
./scripts/install.sh
```

Edit `.env`:

```env
OPENAI_API_KEY=sk-...
OPENAI_BASE_URL=https://api.openai.com/v1
OPENAI_MODEL=gpt-4o-mini
PAPERSCOUT_DEVICE=auto
```

Try a small ACL demo:

```bash
./paperscout demo-acl --max-papers 20
./paperscout index
./paperscout web
```

Open `http://127.0.0.1:4000`.

<details>
<summary>Windows PowerShell</summary>

Install `uv`, clone the repo, then run the installer:

```powershell
winget install --id=astral-sh.uv -e
git clone https://github.com/xukefaker/PaperScout.git
cd PaperScout
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1
```

Edit `.env`:

```powershell
notepad .env
```

Run the demo:

```powershell
.\paperscout.cmd demo-acl --max-papers 20
.\paperscout.cmd index
.\paperscout.cmd web
```

Open `http://127.0.0.1:4000`.

</details>

## Use Your PDFs

```bash
mkdir -p pdfs
# Put PDFs in ./pdfs

./paperscout add-pdfs ./pdfs
./paperscout index
./paperscout web
```

During indexing, press `q` to cancel. PaperScout removes staged files from that run and keeps the previous working index.

## Configuration

The installer creates `.venv/`, installs PaperScout with an automatically selected PyTorch backend, creates `.env`, and runs the doctor check.

The only required setting is:

```env
OPENAI_API_KEY=sk-...
```

Useful defaults:

```env
OPENAI_BASE_URL=https://api.openai.com/v1
OPENAI_MODEL=gpt-4o-mini
PAPERSCOUT_DATA_DIR=./data
PAPERSCOUT_DEVICE=auto
```

`PAPERSCOUT_DEVICE=auto` prefers CUDA or Apple MPS when PyTorch can use it. If no accelerator is available, PaperScout warns and continues on CPU.

## Troubleshooting

```bash
./paperscout doctor
```

- `CUDA available=False`: your Python environment cannot use CUDA. CPU still works, but indexing is slower.
- `demo-acl` PDF download timeout: ACL Anthology is unreachable from your network. Retry later, use a VPN/proxy, or skip the demo and run `./paperscout add-pdfs ./pdfs` with your own PDFs.
- PowerShell blocks scripts: use the installer command shown in the Windows section; its bypass applies only to that command.
- First `web` run is slow: frontend dependencies are installed under `apps/web/node_modules/`.
