# PaperSearchAgent

PaperSearchAgent is a local paper search workbench. Put PDFs into a folder, build an evidence-aware index, then ask questions from the web UI.

PaperSearchAgent 是一个本地论文检索工作台：把 PDF 放进文件夹，构建带证据块的索引，然后在网页里提问和检索相关论文。

## Quick Start

Requirements:

- Python 3.11 or 3.12
- Node.js >= 20.9.0
- An OpenAI-compatible API key for question answering

```bash
git clone https://github.com/xukefaker/PaperSearchAgent.git
cd PaperSearchAgent

python -m venv .venv
source .venv/bin/activate
python -m pip install -U pip
python -m pip install -e .

paper-search-agent init
```

Edit `.env` and set at least:

```bash
OPENAI_API_KEY=sk-...
OPENAI_MODEL=your-model-name
```

Add your PDFs and build the local index:

```bash
paper-search-agent add-pdfs ./pdfs
paper-search-agent index
paper-search-agent web
```

Open `http://127.0.0.1:4000`.

`paper-search-agent web` starts the FastAPI backend on port `4001` and the Next.js frontend on port `4000`. It runs `npm install` inside `apps/web` the first time if `node_modules` is missing.

## 中文快速开始

环境要求：

- Python 3.11 或 3.12
- Node.js >= 20.9.0
- 用于问答的 OpenAI 兼容 API key

```bash
git clone https://github.com/xukefaker/PaperSearchAgent.git
cd PaperSearchAgent

python -m venv .venv
source .venv/bin/activate
python -m pip install -U pip
python -m pip install -e .

paper-search-agent init
```

编辑 `.env`，至少填入：

```bash
OPENAI_API_KEY=sk-...
OPENAI_MODEL=你的模型名
```

导入 PDF、构建索引、启动网页：

```bash
paper-search-agent add-pdfs ./pdfs
paper-search-agent index
paper-search-agent web
```

然后打开 `http://127.0.0.1:4000`。

## Commands

- `paper-search-agent init`: create `.env` from `.env.example` and initialize local data folders.
- `paper-search-agent add-pdfs ./pdfs`: register PDFs under the personal library corpus.
- `paper-search-agent index`: run MinerU parsing, build dense/sparse indexes, and publish `data/search_current`.
- `paper-search-agent index --skip-parse`: reuse existing MinerU artifacts and rebuild indexes only.
- `paper-search-agent web`: start backend and frontend.
- `paper-search-agent search --query "..."`: run a CLI search against the current online index.

## 常用命令

- `paper-search-agent init`：从 `.env.example` 创建 `.env`，并初始化本地数据目录。
- `paper-search-agent add-pdfs ./pdfs`：把 PDF 注册进个人论文库。
- `paper-search-agent index`：运行 MinerU 解析，构建向量/关键词索引，并发布 `data/search_current`。
- `paper-search-agent index --skip-parse`：复用已有 MinerU 解析结果，只重建索引。
- `paper-search-agent web`：启动后端和前端。
- `paper-search-agent search --query "..."`：在命令行里检索当前在线索引。

## Configuration

Runtime data is written to `data/` by default and is ignored by git. You can change it with:

```bash
PAPER_SEARCH_AGENT_DATA_DIR=/path/to/data
```

The default config uses CPU-compatible device settings. If you have a CUDA GPU, set these in `config.toml` or `.env`:

```toml
[mineru]
device = "cuda:0"

[indexing]
dense_device = "cuda:0"

[reranker]
device = "cuda:0"
```

## 配置说明

运行数据默认写入 `data/`，并且不会提交到 git。可以用下面的环境变量修改数据目录：

```bash
PAPER_SEARCH_AGENT_DATA_DIR=/path/to/data
```

发布版默认使用 CPU 兼容配置。如果本机有 CUDA GPU，可以在 `config.toml` 或 `.env` 中设置：

```toml
[mineru]
device = "cuda:0"

[indexing]
dense_device = "cuda:0"

[reranker]
device = "cuda:0"
```

## Repository Layout

- `src/paper_search_agent/`: Python package, indexing, retrieval, API, and CLI.
- `apps/web/`: Next.js web interface.
- `data/`: local runtime data, indexes, parsed PDF artifacts, and traces. This directory is gitignored.
- `research/`: archived benchmark scripts, reproduction notes, UoL/internal scripts, and research-only materials.

## 仓库结构

- `src/paper_search_agent/`：Python 包，包含索引、检索、API 和 CLI。
- `apps/web/`：Next.js 网页工作台。
- `data/`：本地运行数据、索引、PDF 解析结果和 traces。该目录已被 git 忽略。
- `research/`：归档的 benchmark、论文复现实验、UoL/internal 脚本和研究材料。

## Troubleshooting

- If `paper-search-agent index` finishes with `0 indexed papers`, check `data/parsed/mineru_failures.jsonl` and the PDF files.
- If the web UI starts but search fails, confirm `data/search_current/manifest.json` exists and `.env` contains a valid API key/model.
- If `npm` is missing, install Node.js >= 20.9.0 and rerun `paper-search-agent web`.

## 常见问题

- 如果 `paper-search-agent index` 显示 `0 indexed papers`，检查 `data/parsed/mineru_failures.jsonl` 和 PDF 文件本身。
- 如果网页能打开但检索失败，确认 `data/search_current/manifest.json` 存在，并且 `.env` 里有可用的 API key/model。
- 如果缺少 `npm`，安装 Node.js >= 20.9.0 后重新运行 `paper-search-agent web`。
