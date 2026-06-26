# PaperScout

[English](README.md) | 简体中文

用你自己的 PDF 做本地论文检索。把 PDF 放进文件夹，构建 evidence-aware 索引，打开网页，然后直接提问。

## 快速开始

需要：uv、Node.js 20+、一个 OpenAI 兼容 API key。

还没有 uv 的话先安装：

```powershell
winget install --id=astral-sh.uv -e
```

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

安装 PaperScout：

```bash
git clone https://github.com/xukefaker/PaperScout.git
cd PaperScout
```

Windows PowerShell：

```powershell
.\scripts\install.ps1
```

macOS/Linux：

```bash
./scripts/install.sh
```

安装脚本会创建 `.venv/`，用 uv 自动选择 PyTorch 后端，创建 `.env`，并运行 `paperscout doctor`。

编辑 `.env`：

```env
OPENAI_API_KEY=sk-...
OPENAI_BASE_URL=https://api.openai.com/v1
OPENAI_MODEL=gpt-4o-mini
PAPERSCOUT_DEVICE=auto
```

## 使用你的 PDF

```bash
mkdir -p pdfs
# 把 PDF 放进 ./pdfs

uv run --no-sync paperscout add-pdfs ./pdfs
uv run --no-sync paperscout index
uv run --no-sync paperscout web
```

打开 `http://127.0.0.1:4000`。

运行 `paperscout index` 时，可以按 `q` 取消。PaperScout 会删除本次运行的临时文件，并保留上一次可用索引。

## 体验示例论文

```bash
uv run --no-sync paperscout demo-acl --max-papers 20
uv run --no-sync paperscout index
uv run --no-sync paperscout web
```

## 运行说明

- `PAPERSCOUT_DEVICE=auto` 会优先使用 PyTorch 可用的 CUDA 或 Apple MPS。
- 如果没有可用加速后端，PaperScout 会提示并继续用 CPU 跑，只是会慢。
- PDF、解析结果和索引默认都在 `data/`。
- 第一次运行 `paperscout web` 时，如果需要，会自动在 `apps/web` 安装前端依赖。
