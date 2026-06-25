# PaperScout Layout V2 全量升级计划

## 1. 当前决策

本项目从当前基于 `content_list + fixed-size chunk` 的旧系统，直接升级到新的 `Layout V2` 系统。

本次升级的约束如下：

- 旧系统已经停用，不再继续维护。
- 不保留兼容层，不保留旧检索链路，不保留旧前后端展示逻辑。
- 新系统一次性替换旧系统的解析、索引、检索、验证、后端接口和前端展示。
- 当前 `docs/` 下旧文档全部视为过时文档，已经清理；后续以本文件作为唯一主计划文档。

当前状态：

- 远程 demo 服务已经停止。
- 后续所有开发均以新系统为目标，不再围绕旧系统做补丁式改造。

## 1.1 当前范围冻结

为控制本次升级的执行时间与验证复杂度，本轮 Layout V2 升级的语料范围固定为：

- `ACL 2025 long papers only`

这意味着：

- 本次 MinerU 重解析对象只包含 `ACL 2025 long papers`。
- 本次 normalized 数据生成对象只包含 `ACL 2025 long papers`。
- 本次 build index 的对象只包含 `ACL 2025 long papers`。
- 本次在线检索和前后端展示默认只面向 `ACL 2025 long papers` 语料。
- `NAACL / EMNLP / ACL 其他年份 / short / demo` 暂不纳入本轮升级范围。

后续如需扩展语料，再在新系统稳定后，以增量方式加入其他会议、年份或 track。

## 2. 升级目标

新系统目标是把检索对象从“普通文本块”升级为“保留论文版面和对象结构的证据单元”，核心特征如下：

- `layout-first`
- `object-aware`
- `multi-granularity`
- `paper / section / object / chunk` 协同检索
- 最终输出面向 `paper + evidence`，而不是仅返回若干普通 chunk

新系统必须更擅长处理以下查询：

- 某个数据集是否被用于实验
- 某个 benchmark 的结果是否被报告
- 某个方法是否与某个 baseline 做了比较
- 某个结论、限制、错误分析出现在哪个 section
- 某篇论文是否在表格或图注中提供了关键证据

## 3. 为什么必须整体重构

旧系统的核心问题不是单一参数问题，而是信息建模层级不够：

- 旧系统把 scientific paper 主要当作连续文本处理。
- 表格、图片、caption、list、section 结构虽然部分存在，但没有成为一等检索对象。
- chunk 生成依赖固定长度，容易打断方法描述、实验设置和表格证据。
- 前端展示也是围绕旧的 evidence 形式设计的，不适合展示 object-aware 证据。

因此，这不是一次局部调参升级，而是一次“数据结构 + 离线处理 + 在线检索 + UI 展示”的整体替换。

## 4. 新系统的最终形态

### 4.1 解析层

PDF 解析继续使用 MinerU，但解析产物规范升级为：

每篇 paper 保留以下文件：

- `<paper_id>.md`
- `<paper_id>_content_list.json`
- `<paper_id>_middle.json`
- `images/`

不全量保留以下文件：

- `<paper_id>_model.json`
- `layout.pdf`
- `span.pdf`
- `origin.pdf`

原因：

- `md` 用于人工检查解析效果。
- `content_list.json` 轻量，便于快速抽取与兼容性检查。
- `middle.json` 是完整方案 C 的核心结构来源。
- `images/` 用于 table / figure / equation 的对象回溯和后续 UI 展示。
- `model.json` 更偏底层模型 debug，体积大，不作为常规离线产物。

### 4.2 结构层

新系统不再把论文只表示为 `Paper -> Chunks`。

新系统的内部结构统一为：

- `PaperRecord`
- `SectionRecord`
- `ObjectRecord`
- `ChunkRecord`

#### PaperRecord

用于 paper-level recall，保留：

- `paper_id`
- `title`
- `abstract`
- `venue`
- `year`
- `track`
- `authors`
- `pdf_path`
- `parser_backend`
- `section_ids`
- `object_ids`

#### SectionRecord

用于 section-level retrieval，保留：

- `section_id`
- `paper_id`
- `section_title`
- `section_path`
- `page_start`
- `page_end`
- `member_object_ids`
- `section_text_summary`

当前阶段不强求完整 H1/H2/H3 树。由于 MinerU 当前输出的标题层级较浅，section tree 先按以下信息构造：

- `middle.json` 中的 `title` block
- 标题文本模式
- block 顺序
- 页码顺序

### 4.3 对象层

`ObjectRecord` 是新系统的关键。

对象类型固定为：

- `text_block`
- `list_block`
- `table_block`
- `figure_block`
- `equation_block`

每个对象至少保留：

- `object_id`
- `paper_id`
- `section_id`
- `object_type`
- `page_idx`
- `bbox`
- `section_path`
- `text`
- `caption`
- `html`
- `image_path`
- `source_fields`

规则：

- `discarded` 块永远不进索引。
- `table_block` 必须保留 `table body + caption + footnote`。
- `figure_block` 必须保留 `caption + footnote + image_path`。
- `equation_block` 先作为对象保留，不作为主要独立证据检索单元。

### 4.4 Chunk 层

Chunk 不再是原始解析的直接输出，而是基于 `ObjectRecord` 二次构造。

`ChunkRecord` 类型固定为：

- `text_chunk`
- `table_chunk`
- `figure_chunk`

每个 chunk 保留：

- `chunk_id`
- `paper_id`
- `section_id`
- `chunk_type`
- `member_object_ids`
- `text`
- `page_span`
- `section_path`

构造规则：

- `text_block` 和 `list_block` 只允许在同一 section 内按阅读顺序合并。
- 不允许跨 section 合并。
- `table_block` 单独生成 `table_chunk`，不并入普通文本。
- `figure_block` 单独生成 `figure_chunk`，不并入普通文本。
- `equation_block` 不单独生成主检索 chunk；需要时作为邻接证据挂到文本块上。

## 5. MinerU 产物如何服务新系统

### 5.1 `content_list.json` 的职责

保留它，但不再把它视为唯一输入。

用途：

- 轻量抽查解析质量
- 快速读取 `table_caption`、`table_body`、`image_caption`
- 对 `middle.json` 的对象做扁平化补充
- 出现字段缺失时辅助回填

### 5.2 `middle.json` 的职责

它是新系统解析后处理的主输入。

用途：

- 提供 page-level 结构
- 提供 `para_blocks`
- 区分 `title / text / list / table / image`
- 提供 lines / spans / block grouping
- 提供更适合构造 object 和 section 的结构信息

结论：

- 没有 `middle.json`，只能做 `C-lite`
- 要做完整方案 C，必须重新解析并保留 `middle.json`

### 5.3 `md` 的职责

`.md` 必须保留在对应 paper 的解析目录下。

用途：

- 人工检查解析效果
- 快速阅读 parser 输出
- 辅助调试标题识别、内容顺序和对象边界问题

`.md` 不作为主索引输入。

## 6. 离线处理链路改造计划

### 阶段 A：重写解析后处理层

目标：把 MinerU 产物转换为新的统一内部 schema。

需要完成：

1. 读取 `middle.json`
2. 构造 `SectionRecord`
3. 构造 `ObjectRecord`
4. 基于 object 构造 `ChunkRecord`
5. 输出新的标准化中间数据

新中间数据建议落盘到：

- `data/normalized/papers.jsonl`
- `data/normalized/sections.jsonl`
- `data/normalized/objects.jsonl`
- `data/normalized/chunks.jsonl`

不沿用旧的 chunk schema。

### 阶段 B：重写索引构建层

目标：建立多粒度索引。

必须构建的索引：

1. paper-level index
2. section-level index
3. text chunk index
4. table chunk index
5. figure chunk index

每层都要保留：

- 稀疏检索入口
- 稠密检索入口
- ID 到原始对象/section 的映射

### 阶段 C：重写检索流程

检索主链路升级为：

1. Query parser
2. paper-level candidate generation
3. section-level narrowing
4. object/chunk evidence retrieval
5. final verifier
6. result assembly

新系统中：

- `paper recall` 负责找候选论文
- `section retrieval` 负责确定论文中的潜在证据区域
- `object/chunk retrieval` 负责拿到真实证据对象
- `verifier` 负责最终判断是否满足用户查询

最终输出不再只是若干 chunk，而是：

- Satisfied papers
- Partial papers
- Rejected papers

并且每篇 paper 带：

- evidence chunks
- evidence objects
- section path
- rationale

## 7. 后端改造计划

后端接口不再兼容旧 schema。

需要重做：

- 查询请求的数据结构
- evidence 返回结构
- trace 数据结构
- paper 详情接口
- section / object 展示接口

新的后端返回至少支持：

- paper metadata
- matched sections
- text evidence chunks
- table evidence chunks
- figure evidence chunks
- verifier verdict
- confidence
- rationale

后端实现目标：

- 彻底切换到新 schema
- 不保留旧字段兼容代码
- trace 中记录 paper / section / object / chunk 的各级候选与筛选过程

## 8. 前端改造计划

前端同样不做兼容。

旧前端的问题：

- 主要围绕旧 chunk 展示
- 不适合展示 section/object-aware evidence
- 不适合突出 table / figure / caption 作为证据对象

新前端必须围绕新系统重新设计：

### 前端核心展示区

1. 查询区
- 原始 query
- 解析后的 query facets

2. 结果分层区
- Satisfied
- Partial
- Rejected

3. 单篇 paper 详情区
- metadata
- matched sections
- evidence objects
- verifier rationale

4. evidence 展示区
- text chunk
- table chunk
- figure chunk
- 对应页码与 section path

5. trace / inspect 区
- candidate paper 来源
- section narrowing 结果
- object retrieval 结果
- final verifier 结果

前端目标：

- 让人看懂“为什么这篇 paper 被选中”
- 让 table / figure / section 证据成为一等可视化对象
- 不再只堆若干文本块

## 9. 数据目录重整计划

当前项目后续将按新系统重整数据目录。

建议统一为：

- `data/pdfs/`
- `data/parsed/mineru/`
- `data/normalized/`
- `data/indexes/layout_v2/`
- `data/traces/`

含义：

- `data/pdfs/` 保留原始 PDF
- `data/parsed/mineru/` 存放新的 MinerU 产物
- `data/normalized/` 存放统一 schema 后的数据
- `data/indexes/layout_v2/` 存放新索引
- `data/traces/` 存放新检索链路产生的 trace

## 10. 旧结果的处理原则

由于这次是一次性升级，不再维护旧系统，因此：

- 旧服务已经停止。
- 旧前后端逻辑后续将被替换。
- 旧索引和旧解析结果不再作为目标系统的一部分。

但出于开发安全性，在“新解析链路和新索引链路尚未验证完成前”，不立即物理删除旧数据。

删除条件固定为：

1. 新 MinerU 解析链路在小样本上通过验证
2. 新 normalized schema 正常生成
3. 新索引可构建并可被检索
4. 新后端接口打通
5. 新前端可以展示新 evidence 结构
6. 至少完成一轮端到端 query 验证

满足以上条件后，统一删除：

- 旧解析结果
- 旧索引
- 旧系统相关中间文件

## 11. 实施顺序

本次升级严格按以下顺序执行。

### 第 1 步：文档与目标冻结

- 清理旧 docs
- 写入本主计划文档
- 停止旧 demo 服务
- 冻结新系统设计目标

### 第 2 步：定义新 schema

- 定义 `PaperRecord`
- 定义 `SectionRecord`
- 定义 `ObjectRecord`
- 定义 `ChunkRecord`
- 定义新的 trace schema

### 第 3 步：重写 MinerU 后处理逻辑

- 解析 `middle.json`
- 解析 `content_list.json`
- 保留 `.md`
- 构造 section / object / chunk
- 写入 `data/normalized/`

### 第 4 步：重写离线索引构建

- 构建 paper 索引
- 构建 section 索引
- 构建 text chunk 索引
- 构建 table chunk 索引
- 构建 figure chunk 索引

### 第 5 步：重写在线检索链路

- 新 query parser
- 新 candidate generation
- 新 section narrowing
- 新 evidence retrieval
- 新 verifier
- 新 result assembly

### 第 6 步：重写后端

- 替换旧接口实现
- 替换旧 response schema
- 替换旧 trace 输出

### 第 7 步：重写前端

- 围绕 `paper + section + object + chunk + rationale` 重做界面
- 去掉旧展示逻辑
- 支持 table / figure evidence 展示

### 第 8 步：小样本验证

样本规模：

- 先从 ACL 2025 long papers 中抽取少量样本
- 覆盖含 table / figure / complex experiment 的论文

验证内容：

- 解析产物完整性
- section 构造稳定性
- object 构造稳定性
- evidence 展示正确性
- query 结果合理性

### 第 9 步：ACL 2025 long 全量重解析

验证通过后：

- 删除旧解析目录中的旧产物
- 用新的 MinerU 导出配置对 ACL 2025 long 全量重新解析
- 保留 `.md + content_list + middle + images`

### 第 10 步：ACL 2025 long 全量重建索引

- 清理旧 index
- 构建 `layout_v2` 新索引
- 完成 ACL 2025 long 范围内的全量 trace 校验

### 第 11 步：新系统上线

- 新后端上线
- 新前端上线
- 重新启动 demo 服务
- 进行最终人工验收

## 12. 验收标准

新系统上线前必须满足：

1. 对复杂 paper search query，返回的不是零散 chunk，而是完整的证据对象集合。
2. 表格和图注中的关键信息可以作为 evidence 返回。
3. 检索结果能清楚说明：命中的 section、命中的对象、命中的 chunk。
4. verifier 的判断建立在 evidence objects 上，而不是仅依赖 paper title/abstract。
5. 前端能清楚展示为什么某篇 paper 属于 Satisfied / Partial / Rejected。
6. `.md` 文档在解析目录中可随时用于人工检查。

## 13. 本计划执行时的硬约束

- 不做旧系统兼容层。
- 不保留旧索引逻辑。
- 不保留旧前端展示逻辑。
- 不搞补丁式迁移。
- 不把 `content_list` 继续当作唯一主数据源。
- `.md` 必须保留在每篇 paper 对应的 MinerU 解析目录中。
- `middle.json` 必须成为新系统离线结构化处理的主输入之一。

## 14. 下一步

本文件写完后，下一步进入正式实施阶段，但顺序固定为：

1. 先定义新 schema 与新离线数据流
2. 再改 MinerU 导出与解析后处理
3. 再改索引
4. 再改检索
5. 再改后端
6. 最后改前端与重新上线

在本计划未被推翻前，所有实现工作都必须围绕 `Layout V2` 目标系统推进。

## 15. 当前进度（2026-03-23）

### 已完成的大模块：离线结构化链路

已完成内容：

- `PaperRecord / SectionRecord / ObjectRecord / ChunkRecord` 新 schema 已落地。
- 存储层已切为 `raw -> normalized -> layout_v2 index`。
- `ACLAnthologyIngestor` 已改为写入 `raw papers`。
- `pdf_parser.py` 已重写为 `MinerU Layout V2 parser`：
  - 主输入改为 `middle.json`
  - `content_list.json` 作为补充
  - `.md` 作为强制保留产物
  - 解析时从源头移除 `References`
  - 产出 `sections / objects / chunks`
- `indexer.py` 已重写：
  - 写入 `data/normalized/{papers,sections,objects,chunks}.jsonl`
  - 构建 `paper / section / chunk / text_chunk / table_chunk / figure_chunk` 多粒度索引
- `scripts/mineru_pipeline_cache_driver.py` 已改为保留：
  - `.md`
  - `_content_list.json`
  - `_middle.json`
- `search.py` 已完成 Layout V2 首版重写：
  - paper-level candidate generation
  - section narrowing
  - narrowed-section evidence assembly
  - final verifier
  - trace 中保留 section narrowing 摘要
- 单元测试已更新并在远端通过。

### 已完成验证

- 远端 `pytest tests/test_pipeline.py -q`：
  - 当前为 `13 passed`
- 额外做了一次真实 MinerU smoke check：
  - 使用真实样本 `2025.acl-long.1`
  - 新 parser 能从真实 `middle.json + md + content_list` 中构造出：
    - sections
    - objects
    - text/table/figure chunks
- 独立 code review 已执行，并已修复首轮关键问题：
  - `track` 过滤范围错误
  - section/chunk `char_start/char_end` 元数据缺失或偏移
  - parser backend 配置未真正生效
  - MinerU driver 对缺失 `paper_id` 的 skip 语义错误
  - table/figure supplement 绑定从纯 FIFO 改为优先按 bbox 匹配

### 当前结论

- 第 2 步：定义新 schema，已完成。
- 第 3 步：重写 MinerU 后处理逻辑，已完成首版。
- 第 4 步：重写离线索引构建，已完成首版。
- 第 5 步：重写在线检索链路，已完成首版。
- 第 8 步：小样本验证，已完成离线链路和搜索链路级验证。

### 2026-03-23 代码审查收敛

针对第 5 步在线检索链路，已额外完成两轮独立 code review，并修复以下 correctness 问题：

- 修复 zero-signal candidate 被伪造 section / 伪造 evidence 的问题。
- 修复 verifier 看不到 bucket 语义，仅收到裸 `bucket_id -> chunks` 的问题。
- 修复 planner 未拒绝空 bucket query、重复 bucket/aspect id、负 aspect weight 的问题。
- 修复 `content_list` supplement 会被空 table / figure block 提前误消费的问题。
- 修复 literal entity / exact phrase 使用 substring 匹配导致短 acronym 误命中的问题。
- 修复 section narrowing 未纳入 bucket-specific query 的问题。
- 修复 dense retrieval 先过滤 `<= 0` cosine similarity 导致 dense 分支退化的问题。
- 修复单 section / 单 chunk 场景下归一化全归零，进而把真实证据清空的问题。

配套新增并通过的测试覆盖包括：

- zero-signal 不应伪造 section / evidence
- verifier payload 保留 bucket 语义
- planner 拒绝空 bucket query / duplicate ids / negative aspect weight
- parser 不应误消费 table supplement
- acronym token-boundary 匹配

当前远端测试状态：

- `pytest tests/test_pipeline.py -q`
- 结果：`18 passed`

### 2026-03-23 真实语料执行状态

本轮正式执行对象已经固定并实际开始运行：

- 语料范围：`ACL 2025 long papers only`
- 远端旧 `data/` 已清空，避免继续混用旧的 2022-2025 全量缓存。
- 已重新执行 `ingest-acl --venue acl --year 2025 --track long`
- 当前 ingestion 结果：
  - `fetched_papers = 1602`
  - `saved_papers = 1602`
  - `downloaded_pdfs = 1602`
  - `skipped_existing_pdfs = 0`
- 已验证远端官方 OpenAI API 解析到模型：
  - `gpt-5.4-mini`
- 已启动新的 MinerU 后台解析任务：
  - 日志：`logs/acl2025_long_mineru_layout_v2_20260323.log`
  - 目标输出目录：`data/parsed/mineru/`
  - 已观测到早期落盘：
    - `BATCH_OK idx=1/308`
    - `processed = 4`
    - `failed = 0`
    - `cached_estimate = 4`

当前这一步尚未完成，后续流程为：

1. 等待 MinerU 完成 `ACL 2025 long` 全量解析。
2. 执行新的 `build-index`，生成 `normalized + layout_v2 indexes`。
3. 在真实语料上做 query 验证与 trace 检查。

### 下一模块

下一步进入第 6 步和第 9 步之间的收敛工作。

目标：

- 继续把后端 response 和 trace schema 显式切到新的 `paper / section / object / chunk` 结构。
- 用新的 MinerU 导出配置对 `ACL 2025 long` 开始正式重解析。
- 在真实语料上做第一轮 query 验证与 trace 检查。

## 16. 当前完成度审计（2026-03-24）

本节用于记录迁移到原生 Ubuntu 环境后的最新真实状态，覆盖第 15 节中较早的阶段性记录。

### 16.1 总结论

当前可以确认：

- Layout V2 的核心算法改造已经基本落地到代码层。
- ACL 2025 long 的 MinerU 解析产物已经全量存在，共 `1602/1602` 篇。
- 新的 Ubuntu 运行环境已经恢复，CLI 和 GPU 可正常使用。
- 当前仍未完成的关键阻塞项是：`layout_v2` 全量索引尚未构建完成，因此端到端 search 还不能视为最终验收通过。

因此，本项目当前状态应判断为：

- `算法与数据结构升级：done（实现完成）`
- `全量索引构建与端到端验收：in_progress`

### 16.2 逐项审计

#### 第 1 步：文档与目标冻结

- 状态：`done`
- 说明：主计划文档已存在，当前开发目标仍然围绕 Layout V2 推进；旧系统已不再作为目标系统继续维护。

#### 第 2 步：定义新 schema

- 状态：`done`
- 说明：`PaperRecord / SectionRecord / ObjectRecord / ChunkRecord / SearchTrace` 已在代码中定义并被新链路使用。

#### 第 3 步：重写 MinerU 后处理逻辑

- 状态：`done`
- 说明：`pdf_parser.py` 已切到 `mineru_layout_v2` 路线，主输入为 `middle.json`，辅以 `content_list.json`，保留 `.md`，并在解析阶段从源头截断 `References`。解析输出已经是 `paper / section / object / chunk` 四层结构。

#### 第 4 步：重写离线索引构建

- 状态：`in_progress`
- 说明：`indexer.py` 的多粒度索引构建逻辑已实现，但当前 Ubuntu 环境下的全量 `build-index` 仍在执行，`data/indexes/layout_v2/index_state.json` 尚未生成，因此这一步不能判定为完成。

#### 第 5 步：重写在线检索链路

- 状态：`done`
- 说明：新的 query parser、candidate generation、section narrowing、evidence assembly、final verifier、result assembly 已在 `search.py` 中实现完成。当前剩余问题不是检索链路缺失，而是它依赖的新索引尚未构建完毕。

#### 第 6 步：重写后端

- 状态：`in_progress`
- 说明：后端代码目录已经存在，且围绕新 schema 组织；但在当前 Ubuntu 恢复环境中，尚未完成基于新索引的全链路重新验证，因此暂不标记为完成。

#### 第 7 步：重写前端

- 状态：`not_done`
- 说明：此前存在 demo 前端实现，但按本计划要求，前端需要围绕 `paper + section + object + chunk + rationale` 做最终验收级重构。目前不能认定这一项已完成。

#### 第 8 步：小样本验证

- 状态：`in_progress`
- 说明：此前做过样本级验证，且 parser / schema / search 单测都已覆盖；但迁移到原生 Ubuntu 后，仍需在当前环境中基于新索引重新完成一次小样本端到端验证。

#### 第 9 步：ACL 2025 long 全量重解析

- 状态：`done`
- 说明：当前 `data/parsed/mineru/` 下已有 `1602/1602` 个 paper 目录，对应 `ACL 2025 long` 全量语料，说明全量 MinerU 解析产物已经在磁盘上。

#### 第 10 步：ACL 2025 long 全量重建索引

- 状态：`in_progress`
- 说明：当前正在远端执行 `paperscout build-index`。日志显示 paper 级结构抽取已完成，正在执行 dense encoding。只有当 `index_state.json` 成功写入并且 search 可正常运行后，这一步才算完成。

#### 第 11 步：新系统上线

- 状态：`not_done`
- 说明：当前不具备上线条件，因为全量索引尚未完成，且前端与最终人工验收未完成。

### 16.3 当前阻塞项

当前唯一主阻塞项是第 10 步的全量索引构建。

具体表现为：

- `paper / section / chunk` 的结构化数据已经能够产出。
- 当前索引构建在 `BAAI/bge-m3` 的 section dense encoding 阶段耗时较长。
- 之前在 8GB 显存环境下曾触发 OOM，现已将 `dense_batch_size` 与 `reranker.batch_size` 调整到更小配置，并重新执行全量 build。
- 在 `index_state.json` 写出之前，search 不能视为正式恢复。

### 16.4 当前结论

如果从“是否已经完成初步算法改进”来判断，答案是：`是`。

如果从“是否已经完成 Layout V2 升级计划并可正式验收”来判断，答案是：`否`。

当前准确表述应为：

- 新的 Layout V2 检索算法已经实现。
- 当前正在进行新的全量索引构建。
- 索引完成后，还需要再做一次端到端 search 验证，才能把本轮升级判定为完成。

## 17. 2026-03-27 当前完成度审计

本节覆盖的是这一次已经落地的统一离线系统重构，而不是上面较早阶段的旧构建方式。

### 17.1 本轮目标

本轮已经明确收敛为一套单一路径的离线系统：

- `corpus = venue + year + track`
- 严格顺序固定为：`manifest -> PDF 检查/补下载 -> MinerU parse -> build-index`
- 单一正式入口固定为项目根目录的 `./offline.sh`
- 运行模式固定为：`resume` 或 `rebuild`
- 暂停方式固定为：
  - 前台运行输入 `q + 回车`
  - 任意 shell 执行 `./offline.sh pause`

### 17.2 逐项状态

#### A. Per-corpus 路径与状态管理

- 状态：`done`
- 说明：`Settings` 已切到 per-corpus 路径，正式数据路径为：
  - `data/manifests/<venue>/<year>/<track>/papers.jsonl`
  - `data/corpora/<venue>/<year>/<track>/release/current -> snapshots/<snapshot_id>`（原子切换的当前正式版本指针）
  - `data/corpora/<venue>/<year>/<track>/release/current/normalized/`
  - `data/corpora/<venue>/<year>/<track>/release/current/indexes/layout/`
  - `data/corpora/<venue>/<year>/<track>/release/current/indexes/deep_chat/`
  - `data/state/active_corpus.json`
  - `data/state/active_job.json`
  - `data/state/last_job.json`

#### B. 统一 offline runner

- 状态：`done`
- 说明：`offline-run / offline-pause / offline-status` 已通过 `paperscout` CLI 暴露，项目根目录的 `offline.sh` 已作为唯一正式离线入口。

#### C. Resume / rebuild 语义

- 状态：`done`
- 说明：当前实现已经支持：
  - `resume`：复用已有 manifest、parse 产物、bundle 和已完成 shard
  - `rebuild`：清理当前 corpus 的 parse/build 工作产物后重做
- 补充：`rebuild` 现在不会在新快照成功前删除 live 的 `normalized/` 和 `indexes/`。

#### D. Pause 机制

- 状态：`done`
- 说明：活动作业通过全局锁和状态文件管理，`pause` 命令已在远端实跑验证可用，能让运行中的离线作业在安全边界退出。

#### E. Build 可恢复结构

- 状态：`done`
- 说明：build 现在已经是 `bundle -> shard encode -> finalize` 结构，bundle/shard 会在 `work/build/` 下落盘，可在中断后继续。

#### F. 设备与吞吐修正

- 状态：`done`
- 说明：
  - dense encoder 与 reranker 的默认 device 已改为“显式配置优先，否则自动选择可用 CUDA，再否则 CPU”
  - 编码器包装层已改为更大的 outer batch，减少海量小 `model.encode()` 调用带来的 Python 开销
  - 当前 `config.toml` 已显式写明 `dense_device = "cuda:0"` 与 `reranker.device = "cuda:0"`

#### G. 最严重正确性问题修复

- 状态：`done`
- 说明：已修复以下问题：
  - `rebuild` 不再提前清空 live 版本
  - `resume` 的 completed 判定现在同时校验 `release_signature`，不再只看 parse success fingerprint
  - `finalize` 改为“先写完整 snapshot，再原子切换 `release/current` 指针”，不再分两次切 `normalized` 和 `indexes`
  - build fingerprint 已提升到包含 PDF 与 metadata 级签名
  - `job_state.json` 每次 run 都会重新初始化，不再沿用旧 `job_id / started_at / mode`
  - `offline-status` 在无活动作业时会读取 `last_job.json` 指向的状态，而不是误读当前 online corpus
  - FastAPI 已改成按 `active_corpus.json` 感知当前 corpus 的服务管理器，不需要靠重启进程才能切到新 corpus
  - CLI 与 FastAPI app 已固定解析项目根目录，不再依赖当前 shell 的 `cwd`

#### H. 历史遗留离线脚本

- 状态：`done`
- 说明：旧的 `run_build_index.sh`、`run_full_rebuild_pipeline.sh`、`run_mineru_pipeline_cache_driver.sh`、`mineru_pipeline_cache_driver.py`、`rebuild_status.py` 已全部收口为 fail-fast 提示，不再保留第二套业务逻辑。

#### I. 最小回归测试

- 状态：`done`
- 说明：已补并通过远端测试：
  - `tests/test_runtime_device_selection.py`
  - `tests/test_offline_pipeline.py`
  - `tests/test_api_runtime_reload.py`
  - `tests/test_deep_chat_api.py`
  - `tests/test_search_pipeline.py`
- 当前本轮相关测试通过数：`43 passed`

#### J. ACL 2025 long 全量离线构建

- 状态：`in_progress`
- 说明：当前远端已在修复后的统一 offline runner 上重新 `resume` `ACL 2025 long`。此前 section 编码已跑到 `18464/32403`，本轮是基于现有 bundle/shard 继续，而不是从头重建。完成标志是：
  - per-corpus `normalized/` 与 `indexes/` 成功 finalize
  - `active_corpus.json` 写入
  - search 与 deep chat 基于新路径完成端到端验证

## 18. 2026-03-27 下午增量修复说明

### 18.1 本轮为什么暂停并改代码

在统一 offline build 跑到 `section` dense encoding 中段后，独立代码审查发现还有 5 个高优先级问题没有真正收口：

- completed 判定只看 parse success 集合，忽略 manifest / failure 集合变化
- finalize 仍然是两次目录切换，不是单次原子发布
- API 进程不会感知 `active_corpus` 切换
- `job_state.json` 会继承旧 run 的身份字段
- `offline-status` 在没有活动作业时会读错 corpus 的状态

这些问题都不属于“优化项”，而是会影响统一离线系统语义闭环的正确性问题，因此本轮先暂停 build，再修正逻辑，然后用 `resume` 接着跑。

### 18.2 本轮已经完成的实现

- 正式发布路径改为 `release/snapshots/<snapshot_id>/...` + `release/current` symlink
- `resume` 的 skip 条件新增 `release_signature`
- `last_job.json` 已纳入全局状态管理
- `offline-status` 现在在暂停态/非活动态仍能显示正确的最近作业状态
- FastAPI 改为 `AppServiceManager`，缓存键从“仅 corpus”提升为“corpus + current release 指针”
- 同一 corpus 发布新 release 后，API 会重新绑定新的 `store / engine / deep_chat`，不再把 `/health` 与内存 runtime 分裂成两个版本
- 搜索 job 查询改为先在当前 manager 外，再跨已缓存 runtime 查找已有 `job_id`，避免 active corpus 切换后旧 job 直接失联
- 已新增并通过 API runtime reload 测试

### 18.3 当前状态

- 代码与测试：`done`
- 统一离线全量 build：`in_progress`
- 下一步：等待 `ACL 2025 long` build 完成，然后做 search / deep chat 端到端验收

### 18.4 当前测试状态

截至这次增量修复完成后，远端已通过的相关测试为：

- `tests/test_offline_pipeline.py`
- `tests/test_api_runtime_reload.py`
- `tests/test_runtime_device_selection.py`
- `tests/test_deep_chat_api.py`
- `tests/test_search_pipeline.py`

合计：`45 passed`

### 17.3 当前结论

截至 2026-03-27，本项目的“统一离线系统重构”已经完成了实现与关键正确性修正。

当前唯一还未收尾的主任务是：

- 等待 `ACL 2025 long` 的全量 per-corpus build 跑完
- 然后做一次 search / deep chat 的正式端到端验收
