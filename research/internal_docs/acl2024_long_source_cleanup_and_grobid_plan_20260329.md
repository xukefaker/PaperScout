# ACL 2024 Long 源头清洗与 GROBID 接入计划

## 目标

本次只针对 `acl 2024 long` 落地以下三项源头修复，不修改 paper search 与 deep chat 的核心检索算法：

1. 从正式 normalized/index 语料中彻底去掉人工合成的 `Front Matter`
2. 从源头修复 `paper.title` 脏数据问题，不再依赖后续 viewer 层做补丁
3. 用 `GROBID` 替换当前基于规则的 authorship enrichment，仅负责抽取 `title/authors/affiliations`

本次范围限定为：

- corpus: `acl 2024 long`
- 不重跑 MinerU parse
- 重跑 manifest / enrichment / build

## 当前问题与根因

### 1. `Front Matter` 进入正式 section/chunk

当前 [pdf_parser.py](/home/kexu/projects/PaperSearchAgent/src/paper_search_agent/pdf_parser.py) 在“还没有进入任何正式 section，但已经读到 object block”时，会调用 `_ensure_current_section()` 创建一个人工 section：

- `section_title = "Front Matter"`
- `section_path = ["Front Matter"]`

这会导致：

- `Front Matter` 出现在 `sections.jsonl`
- 作者/机构对象进入 `objects.jsonl`
- 生成 `heading=Front Matter` 的 chunk 进入 `chunks.jsonl`
- viewer 与索引都被污染

### 2. `paper.title` 在 manifest 层已脏

以 `2025.acl-long.757` 为例：

- `data/manifests/.../papers.jsonl` 中 `title` 已是 `M as R outer...`
- `data/search_current/normalized/papers.jsonl` 继承了同样的脏值
- 但 MinerU `content_list.json` 的首个 level-1 title 是干净的：`MasRouter: Learning to Route LLMs for Multi-Agent System`

说明：

- title 污染不是 viewer 引入的
- title 污染也不是 build 阶段引入的
- title 问题源头位于 ingest / manifest 生成链路

### 3. authorship enrichment 对复杂 marker 失败

当前 [offline.py](/home/kexu/projects/PaperSearchAgent/src/paper_search_agent/offline.py) 的 enrichment 阶段会：

1. 重新 `parser.parse(paper)`
2. 调用 `extract_author_metadata(bundle.paper, bundle.objects)`
3. 将结果写入 `data/enrichment/papers/*.json`

这条链路主要依赖 front matter objects 与规则匹配。对于如下 header：

- `⋆ ♣ ♠ ♦`
- 作者与机构粘在同一文本块

会发生作者尾部与机构头部串接错误。

## 本次实施原则

- 不在 viewer 层打补丁掩盖源头问题
- 不保留 `Front Matter` 作为正式 section
- 不继续扩展基于正则和 marker 的 authorship 规则
- 不重跑 MinerU
- 先把 `acl 2024 long` 跑通，确认结果后再推广到其他 corpus

## 设计方案

### A. Parser 结构清洗：去掉 `Front Matter`

#### 目标

将标题后的作者/机构前言内容从“正式 section/object/chunk”体系中移除。

#### 改法

在 [pdf_parser.py](/home/kexu/projects/PaperSearchAgent/src/paper_search_agent/pdf_parser.py) 中：

1. 删除 `_ensure_current_section()` 自动创建 `Front Matter` 的行为
2. 对于尚未进入正式 section 的 object block：
   - 不写入 `sections`
   - 不写入 `objects`
   - 不写入 `chunks`
3. 一旦进入第一个正式 heading（通常是 `Abstract`），后续对象照常进入正式 section

#### 结果

- normalized 数据中不再存在 `Front Matter`
- viewer 不需要专门过滤它
- paper recall / chunk retrieval 不再吃到 front matter 噪声

### B. Title 源头修复：manifest 写入权威 title

#### 目标

让 `paper.title` 在 ingest 阶段就尽可能正确，后续所有模块统一受益。

#### 改法

在 [acl_anthology.py](/home/kexu/projects/PaperSearchAgent/src/paper_search_agent/acl_anthology.py) 中：

1. event page 仍负责发现 paper list、authors、abstract、pdf_url
2. 对每篇 paper 再抓一次对应 paper page，抽取权威 title
3. 将 paper page title 写入 manifest/raw paper record
4. 保留 event listing title 作为调试字段，写入 metadata，便于审计

#### 权威 title 选择顺序

固定主路径：

1. paper page `citation_title` / 明确 metadata title
2. paper page正文标题节点

不采用 viewer 层修复，也不采用模糊猜测作为主路径。

#### 质量校验

在 build_prepare / enrichment 阶段，读取对应 PDF 的 MinerU `content_list.json`：

- 提取第一个 `text_level=1` 标题
- 与 manifest title 做 surface normalization 后比对
- 若明显不一致，记录 anomaly 日志并优先信任 manifest 权威 title

这里的 MinerU title 只用于校验和审计，不作为新的主来源。

### C. Authorship enrichment 替换：接入 GROBID

#### 目标

用专门的 scholarly PDF header extractor 替换当前规则抽取，只抽：

- title
- authors
- affiliations

#### 技术路线

在 Ubuntu 远端本机部署一个本地 GROBID service。

当前机器没有：

- `docker`
- `java`

因此最短路径是：

1. 安装 OpenJDK 17/21
2. 下载并启动本地 GROBID service
3. 在 offline enrichment 阶段通过 HTTP 调用 `processHeaderDocument`

官方接口：

- `POST /api/processHeaderDocument`

官方资料：

- GROBID service docs: <https://grobid.readthedocs.io/en/latest/Grobid-service/>
- GROBID intro/performance: <https://grobid.readthedocs.io/en/update-documentation/Introduction/>

#### 接入位置

在 [offline.py](/home/kexu/projects/PaperSearchAgent/src/paper_search_agent/offline.py) 的 `OfflineEnrichmentRunner.run()` 中：

当前：

1. `parser.parse(paper)`
2. `extract_author_metadata(bundle.paper, bundle.objects)`

修改为：

1. 直接读取 `paper.local_pdf_path`
2. 调用 GROBID header API
3. 解析返回的 TEI XML
4. 写入现有 enrichment cache：
   - `affiliations`
   - `authors_structured`
5. references 仍然继续从 MinerU markdown 提取，暂不改

#### 数据模型

不新增新的业务 schema，仅在 `metadata` 中保留 GROBID 审计字段，例如：

- `authorship_backend = "grobid_header"`
- `authorship_title`
- `authorship_status`

正式输出仍然沿用：

- `PaperEnrichmentRecord`
- `authors_structured`
- `affiliations`

### D. Viewer 与在线服务的预期变化

因为本次修的是源头数据，viewer 不需要新增复杂兼容逻辑。

修复完成后，右侧 manuscript 预期自然变成：

1. 顶部显示结构化作者 + 机构 header
2. 正文第一个 section 从 `Abstract` 开始
3. 不再显示 `Front Matter`
4. 不再因为脏 `paper.title` 导致标题 section 泄露

## 需要修改的模块

### 1. ingest

- [acl_anthology.py](/home/kexu/projects/PaperSearchAgent/src/paper_search_agent/acl_anthology.py)

### 2. parser / build_prepare

- [pdf_parser.py](/home/kexu/projects/PaperSearchAgent/src/paper_search_agent/pdf_parser.py)

### 3. enrichment

- [offline.py](/home/kexu/projects/PaperSearchAgent/src/paper_search_agent/offline.py)
- 新增 `grobid_client` 模块
- 可能新增 `tei parsing` 辅助模块

### 4. config

- [config.toml](/home/kexu/projects/PaperSearchAgent/config.toml)
- [config.py](/home/kexu/projects/PaperSearchAgent/src/paper_search_agent/config.py)

新增 GROBID 配置项，例如：

- `grobid.enabled`
- `grobid.base_url`
- `grobid.timeout_seconds`

## acl 2024 long 执行步骤

### Step 1. 改代码

完成以下三项：

1. manifest 写入权威 title
2. parser 不再生成 `Front Matter`
3. enrichment 改为 GROBID header extraction

### Step 2. 安装并拉起 GROBID

在远端 Ubuntu 上：

1. 安装 JDK
2. 启动本地 GROBID service
3. 用一篇 `acl 2024 long` PDF 做 header smoke test

### Step 3. 仅重建 acl 2024 long

固定 corpus：

- `acl/2024/long`

执行：

1. manifest refresh
2. offline enrichment rebuild
3. build index rebuild
4. 合并到 `search_current`

### Step 4. 验证

至少验证以下内容：

1. normalized 中不存在 `Front Matter`
2. `chunks.jsonl` 中不存在 `heading=Front Matter`
3. 抽样检查 5 篇 paper 的 `paper.title` 与 PDF 标题是否一致
4. 抽样检查 5 篇复杂 authorship 论文的机构是否正确
5. demo 页面右侧 manuscript 是否从 `Abstract` 开始

## 为什么先做 acl 2024 long

- 论文数量更少，重建更快
- 足够验证结构修复是否正确
- 一旦流程跑通，再推广到 `acl 2025 long` 风险最低

## 不做的事情

本次明确不做：

- 不重跑 MinerU parse
- 不改搜索算法
- 不改 deep chat 检索逻辑
- 不改 references 抽取方案
- 不保留 viewer 层专门的兼容补丁

## 预期产出

完成后应得到：

1. `acl 2024 long` 的干净 manifest
2. 去除 `Front Matter` 的 normalized/index
3. 基于 GROBID 的 authorship enrichment cache
4. 可直接在 demo 中验证的 cleaner paper detail 页面

## 当前完成度审计

更新时间：

- `2026-03-29 18:05 UTC`

状态概览：

- `done` manifest 标题源修复代码已落地，并已对 `acl 2024 long` 重跑 manifest refresh
- `done` parser 已移除人工合成的 `Front Matter`，抽查 `build_prepare` bundle 已确认 `sections/chunks` 中不再出现该 section
- `done` GROBID `0.8.2` 已在远端本机拉起，当前通过 `http://127.0.0.1:8070/api/version` 可正常访问
- `done` GROBID client 已修复为显式请求 XML；此前默认返回 BibTeX 的接入问题已解决
- `done` `acl 2024 long` enrichment rebuild 已完成：`processed=864 failed=1`
- `in_progress` `acl 2024 long` build/index rebuild 正在进行中，当前已进入 `build_encode`
- `in_progress` `search_current` 需要等待本轮 build finalize 完成后自动刷新
- `not_done` demo 页面级联验证尚未做，因为当前为保证离线编码显存，已暂时停掉 demo 前后端

当前已验证事实：

- `2024.acl-long.1` 的 `build_prepare` bundle 首个正式 section 为 `Abstract`
- `2024.acl-long.1` 与 `2024.acl-long.171` 的 bundle 中 `Front Matter` section 数量均为 `0`
- manifest 现已写入审计字段：
  - `paper_url`
  - `title_source = "paper_page_meta"`
  - `listing_title`

当前暴露的问题：

- `2024.acl-long.95`
  - GROBID `processHeaderDocument` 返回了空的 `analytic/author`
  - 当前被严格记为 enrichment failure，没有走规则回退
- `2024.acl-long.171`
  - GROBID 标题把 warning 文本一并吞入 header title
  - 当前系统仍以 manifest 的 ACL paper page title 为正式 title，因此不会污染 `paper.title`
  - 但其 affiliations 结构化结果仍然存在串联脏值，说明 GROBID header 对复杂多机构 header 不是完全可靠

本轮实施中的额外工程结论：

- `grobid 0.8.2` 在当前远端环境不能直接用 `Java 21 + Gradle 7.2` 启动
- 最短可用路径是：
  - 安装 `openjdk-17-jdk-headless`
  - 用 `JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64` 启动 GROBID
- 离线 build 与在线 demo 不能同时稳定共用当前 8GB 显存
  - 本次一次真实 OOM 原因是 `PaperSearchAgent` 后端服务占用约 `3.1 GiB` GPU 显存
  - 为继续 build，已临时停止 demo 前后端
