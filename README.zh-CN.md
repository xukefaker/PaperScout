# PaperScout

[English](README.md) | 简体中文

用你自己的 PDF 做本地论文检索。加入论文，构建 evidence-aware 索引，打开网页，然后直接提问。

## 快速开始

环境要求：uv、Node.js 20+、OpenAI 兼容 API key。PaperScout 的 Python 环境只用 uv 管理。

如果还没有 uv，先安装：

```powershell
# Windows PowerShell
winget install --id=astral-sh.uv -e
```

```bash
# macOS/Linux
curl -LsSf https://astral.sh/uv/install.sh | sh
```

然后安装并运行 PaperScout：

```bash
git clone https://github.com/xukefaker/PaperScout.git
cd PaperScout

uv python install 3.12
uv sync

uv run paperscout init

# 编辑 .env:
# OPENAI_API_KEY=sk-...
# OPENAI_MODEL=你的模型名

mkdir -p pdfs
# 把你的 PDF 放进 ./pdfs

uv run paperscout add-pdfs ./pdfs
uv run paperscout index
uv run paperscout web
```

然后打开 `http://127.0.0.1:4000`。

## 体验示例论文

暂时没有自己的 PDF？可以下载 100 篇 ACL 2025 long track 论文：

```bash
uv run paperscout demo-acl --max-papers 100
uv run paperscout index
uv run paperscout web
```

## 说明

- uv 会在项目根目录下创建 `.venv/`。
- PDF 和索引默认保存在 `data/`。
- 问题会发送到你配置的 OpenAI 兼容 API。
- 小规模论文库可以用 CPU；大量 PDF 建议用 CUDA。
- 第一次运行 `uv run paperscout web` 时，如果需要，会自动在 `apps/web` 安装前端依赖。
