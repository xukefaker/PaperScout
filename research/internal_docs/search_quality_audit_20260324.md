# PaperSearchAgent 检索效果审计报告（2026-03-24）

## 1. 审计目标

本次审计的目标不是继续改代码，而是如实评估当前 `PaperSearchAgent` 在真实 query 下的检索表现，尤其关注：

1. 对单目标、明确描述的科研检索 query，系统是否能稳定找对论文。
2. 对涉及正文细节、实验设置、表格内容的 query，系统是否仍然能锁定目标论文。
3. 对更宽泛、更接近真实 research workflow 的 broad query，系统返回结果是否自然、是否存在明显误召回或排序漂移。
4. 当前系统的主要短板到底是“找不到”，还是“排序不稳 / 速度太慢 / 运行不稳”。

本报告只做测试与分析，不改任何代码。

---

## 2. 测试边界

### 2.1 当前索引范围

本次测试只针对当前已建立好的索引：

- 语料范围：`ACL 2025 long`
- 论文数：`1602`
- sections：`32403`
- objects：`111985`
- chunks：`56041`
  - text chunks：`41959`
  - table chunks：`6961`
  - figure chunks：`7121`

### 2.2 当前系统配置要点

- PDF parser：`MinerU layout_v2`
- paper dense model：`allenai/specter2_base`
- chunk dense model：`BAAI/bge-m3`
- local reranker：`BAAI/bge-reranker-v2-m3`
- planner / final verifier：OpenAI 官方 API
- candidate pool size：`50`

### 2.3 测试环境

- 远程机器：`kexu@192.168.1.105`
- 运行目录：`/home/kexu/projects/PaperSearchAgent`
- 测试方式：CLI 真实运行，不 mock、不改代码

---

## 3. 测试设计

我把 query 分成三类：

1. `Targeted queries`：10 条。目标明确，通常有一篇非常核心的目标论文。
2. `Broad queries`：3 条。更接近研究者的真实入口，允许多篇论文都相关。
3. `Content-detail queries`：4 条。故意使用正文细节、数据集构造细节、benchmark split 设计、annotation 细节等，不只靠标题词面。

另外补跑了 1 条 `numeric/table-heavy` query，用来测试“表格数值级检索”是否稳健。

---

## 4. 总体结论

### 4.1 一句话结论

当前系统对“单目标、描述充分、语义锚点明显”的 query，效果已经明显可用；对“正文细节级 query”，也表现出不错的命中能力；但在更宽 query 下，排序与类别校准仍然偏松，且整体延迟较高，运行稳定性在 8GB 显存环境下还不够稳。

### 4.2 核心数字

- 总共实际运行 query：`17` 条主测试 + `1` 条额外数值压力测试
- `10/10` 条 targeted query 找到了预期论文
- 其中 `9/10` 条 targeted query 把预期论文排在 `satisfied` 第 1
- `4/4` 条 content-detail query 找到了预期论文，且全部排在 `satisfied` 第 1
- broad query 的 top 结果整体合理，但返回集合偏满，说明“宽 query 下的最终裁断仍偏宽松”
- 17 条主测试的平均耗时：`224.54s`
- 17 条主测试的中位耗时：`231.69s`
- 最快：`164.71s`
- 最慢：`257.08s`

### 4.3 我对当前系统状态的判断

如果现在的目标是：

- 做 demo 展示
- 演示“给定一批 conference papers，输入自然语言 query，返回相关论文与 evidence”

那么当前系统已经具备展示价值。

如果现在的目标是：

- 作为真正高频使用的 research tool
- 面向开放式、宽泛、多意图 query 提供稳定 top results

那么当前最需要解决的不是“完全找不到论文”，而是：

1. 宽 query 下的排序与判定边界还不够稳。
2. 延迟过高。
3. 运行稳定性对 8GB GPU 较敏感。

---

## 5. Targeted Queries 结果

下表中的“预期论文”是我根据 ACL 2025 long 语料中的已知论文内容手工指定的参考目标，用来评估系统是否至少能把核心目标找出来。

| ID | Query 类型 | 预期论文 | 结果 | 备注 |
|---|---|---|---|---|
| `q1_gaia_results` | benchmark + results | `2025.acl-long.1383` | 命中，`satisfied #1` | 很稳 |
| `q2_gpqa_gaia_agentic` | method + multi-dataset | `2025.acl-long.1383` | 命中，`satisfied #1` | 很稳 |
| `q3_chinese_factuality_benchmark` | benchmark introduction | `2025.acl-long.941` | 命中，`satisfied #2` | 存在排序漂移 |
| `q4_mmlu_cf_contamination` | contamination benchmark | `2025.acl-long.656` | 命中，`satisfied #1` | 很稳 |
| `q5_abgen_meta_eval` | scientific workflow benchmark | `2025.acl-long.611` | 命中，`satisfied #1` | 很稳 |
| `q6_ecomscriptbench` | task benchmark | `2025.acl-long.1` | 命中，`satisfied #1` | 很稳 |
| `q7_memerag` | multilingual RAG benchmark | `2025.acl-long.1101` | 命中，`satisfied #1` | 很稳 |
| `q8_ref_long` | long-context benchmark | `2025.acl-long.1162` | 命中，`satisfied #1` | 很稳 |
| `q9_legal_agent_bench` | legal-domain agent benchmark | `2025.acl-long.116` | 命中，`satisfied #1` | 很稳 |
| `q10_coir` | IR benchmark | `2025.acl-long.1072` | 命中，`satisfied #1` | 很稳 |

### 5.1 这一组测试说明了什么

这组结果说明：

- 当前系统对“目标论文语义特征比较集中”的 query，已经具备较强的锁定能力。
- 不只是 benchmark 名称 query 有效；像 `ablation study design + meta-evaluation benchmark`、`legal domain + 17 corpora + tools` 这种组合描述也能命中。
- 当前的 `candidate generation + evidence assembly + final verifier` 主链条，在这种单目标 query 上是工作的。

### 5.2 唯一明显的排序漂移案例：`q3_chinese_factuality_benchmark`

该 query 的预期目标是：

- `2025.acl-long.941` `Chinese SimpleQA`

但系统把下面这篇排在了它前面：

- `2025.acl-long.732` `Chinese SafetyQA`

这不属于“完全答错”，更像是：

- query 本身写的是 `Chinese benchmark` + `factuality` + `LLM`
- `Chinese SafetyQA` 在语义上与该 query 也高度接近
- verifier 因为看到它也满足“中文 / benchmark / short-form factuality / LLM evaluation”这类条件，因此把它也判成了 `satisfied`

这说明当前系统的一个真实现象：

- 它在召回和最终裁断上已经有不错的语义能力
- 但当两个候选论文在主题上高度相似、且 query 没有把区分条件说得足够细时，排序会出现语义邻近项抢前的问题

也就是说，这里不是“找不到”，而是“区分不够尖锐”。

---

## 6. Content-Detail Queries 结果

这组测试更重要，因为它更接近你此前强调的需求：query 可能涉及论文内部很细的内容，而不是只有标题和元数据。

| ID | 细节类型 | 预期论文 | 结果 | 备注 |
|---|---|---|---|---|
| `c1_closed_test_public_val` | benchmark split 设计 | `2025.acl-long.656` | 命中，`satisfied #1` | 很稳 |
| `c2_17_corpora_37_tools` | 具体 corpora / tools 数量 | `2025.acl-long.116` | 命中，`satisfied #1` | 很稳 |
| `c3_miracl_native_languages` | native-language MIRACL + expert annotations | `2025.acl-long.1101` | 命中，`satisfied #1` | 很稳 |
| `c4_605k_scripts_2_4m_products` | 数据规模细节 | `2025.acl-long.1` | 命中，`satisfied #1` | 很稳 |

### 6.1 这一组测试的意义

这组测试说明，当前系统并不只是“标题匹配器”。

至少在这 4 条 query 上，它已经能利用：

- benchmark split 设计细节
- 数据规模数字
- annotation 流程描述
- 任务构造细节

去锁定目标论文。

这对于系统的定位很关键，因为它说明：

- MinerU 解析后的 section / chunk / object 索引确实在发挥作用
- evidence assembly 不是完全空转
- final verifier 确实在读 evidence chunks，而不只是看 paper title / abstract

当然，也要注意，这几条细节有些本身也在 abstract 中出现，所以这不等于“任何正文隐藏细节都一定能稳找”。但至少可以明确地说：

- 当前系统已经超过了“只靠标题/摘要做语义搜索”的水平

---

## 7. Broad Queries 结果

Broad query 更接近真实科研使用时的入口，因为用户并不总是知道论文名，也不总是只找单篇论文。

### 7.1 Query: agent benchmark / realistic environments

Query：

> Find ACL 2025 papers that introduce new benchmarks or datasets for evaluating LLM agents in realistic environments.

Top satisfied 包括：

- `INVESTORBENCH`
- `LegalAgentBench`
- `AgentGym`
- `TripCraft`
- `NewsInterview`
- `GuideBench`

我的判断：

- 结果整体是合理的
- 但相关性强弱并不完全一致
- 其中有些论文明显更像“agent benchmark 核心命中”，有些更像“相关 playground / dataset / realistic task”

这说明当前系统在宽 query 下：

- 能把大方向找对
- 但不会自动强力收紧到非常纯的子集

### 7.2 Query: reliable / contamination-resilient evaluation

Query：

> Find ACL 2025 papers about reliable or contamination-resilient evaluation of large language models.

Top satisfied 包括：

- `Establishing Trustworthy LLM Evaluation via Shortcut Neuron Analysis`
- `MMLU-CF`
- `CoreEval`
- `AntiLeakBench`
- `TripleFact`
- `Data Laundering`

我的判断：

- 这是目前 broad query 里效果最好的一组之一
- 排出来的论文基本都在“可靠评测 / contamination / benchmark leakage / evaluation robustness”这一语义簇里
- 说明 query parser + candidate generation + verifier 的整体语义对齐，在这个主题上是比较成功的

### 7.3 Query: RAG or IR benchmarks

Query：

> Find ACL 2025 papers that build evaluation benchmarks for retrieval-augmented generation or information retrieval.

Top satisfied 包括：

- `REAL-MM-RAG`
- `AIR-Bench`
- `MEMERAG`
- `HoH`
- `RAGEval`
- `CoIR`

我的判断：

- 结果整体仍然自然
- 但主题边界比较宽：RAG benchmark、retrieval benchmark、RAG evaluation framework、IR benchmark 全部被放在一起
- 这对“探索式搜索”是优点，对“精确过滤”则意味着用户仍需读结果列表

### 7.4 Broad query 的真实短板

在这三条 broad query 上，系统没有明显崩坏，但有两个问题非常明显：

1. `satisfied / partial / rejected` 三个桶都比较“满”
   - 例如每条 broad query 都返回了 `8 satisfied / 8 partial / 8 rejected`
   - 这说明当前 top-k 分桶更像“每桶都截断展示”，而不是一个非常尖锐的全局相关性排序

2. broad query 的最终判定边界偏宽
   - 对于真实 researcher 来说，结果虽然看起来方向正确，但还不够“替你做完筛选”
   - 用户仍然需要读标题和 rationale 再做二次判断

所以 broad query 的真实评价是：

- `方向对`，但 `收口还不够狠`

---

## 8. 额外压力测试：表格数值级 query

额外 query：

> Find ACL 2025 papers that report GAIA Level 3 accuracy around 45.46 and an average score around 66.13.

### 8.1 结果

这条 query 没有正常完成，而是直接报错退出。

报错核心信息：

- `OutOfMemoryError: CUDA out of memory`
- GPU 总显存：约 `8.15 GB`
- 当时可用显存：约 `304 MB`
- 同时还有一个无关项目进程在占用约 `1092 MB` 显存：
  - `/home/kexu/projects/road-sign-cli-demo/.pixi/envs/default/bin/python`

### 8.2 这说明什么

这不是“答案错了”，而是“运行稳健性不足”。

我对这个失败的解释是：

1. 当前系统在默认 GPU 路径上，对 8GB 显存比较敏感。
2. 当 query 触发较重的 dense / reranker 路径时，显存余量不够就会直接 OOM。
3. 这类失败和检索逻辑本身不是同一个问题，但对真实可用性影响很大。

因此，这条测试的结论不是“系统不会找表格数字”，而是：

- 当前运行配置下，`表格数值级 query + 8GB GPU + 其他项目占显存` 的组合，存在真实的稳定性风险

---

## 9. 为什么当前效果总体还不错

### 9.1 单目标 query 的语义锚点比较清晰

现在表现最好的，都是这类 query：

- 主题集中
- 约束明确
- benchmark / task / setup 语义很尖锐
- query 中出现了能区分目标论文的关键信号

例如：

- `GAIA + report results`
- `ablation study design + meta-evaluation benchmark`
- `long-context referencing capability`
- `code information retrieval benchmark`

在这种场景下，当前系统的 paper recall 与 verifier 组合已经足够强。

### 9.2 当前 evidence 路径确实有用

从 content-detail query 的结果看，系统不是只在做：

- title semantic match
- abstract semantic match

它已经能利用：

- benchmark split 设计
- corpora / tools 数量
- native-language dataset construction
- 数据规模细节

这说明现在的 `chunk-level evidence retrieval -> final verifier` 路径是有实际贡献的。

### 9.3 verifier 对“误召回候选”的抑制是有效的

例如 GAIA query 中，候选池里会混入：

- `AbGen`
- 一些带有 benchmark / evaluation / results 词面的其他论文

但 final verifier 最终能把它们压到 `rejected`。

这说明当前系统的主要问题已经不是“完全没有裁断能力”，而是：

- recall 比较宽
- verifier 能兜住一部分误召回
- 但宽 query 下还不够收敛

---

## 10. 为什么有些地方效果会不好

### 10.1 宽 query 下，语义相近论文会一起被判成相关

这在 `Chinese SimpleQA` / `Chinese SafetyQA` 上已经表现出来了。

原因是：

- query 只描述了一个较宽的语义簇
- 多篇论文都能满足这个语义簇的主要条件
- verifier 又倾向于“只要满足主要条件就给 satisfied”

于是就会出现：

- 结果并非错得离谱
- 但排序不一定符合用户心中的“唯一最优论文”

### 10.2 当前 candidate generation 仍然是“宽召回优先”

这会带来一个现象：

- 最终正确论文通常能进候选池
- 但候选池里也会有不少主题邻近但不真正满足 query 的论文

如果 verifier 足够强，这没问题；
但如果 query 很宽、候选很多、相似论文很多，verifier 就会更容易出现边界松动。

### 10.3 Broad query 的 final verdict 还不够“尖锐”

从 broad query 的结果看：

- top results 大方向对
- 但 `satisfied` 桶容易装得很满

这意味着系统当前更像：

- 一个不错的 `semantic scholarly explorer`

而不是：

- 一个已经把 broad query 精筛到非常干净 top list 的最终产品

### 10.4 延迟很高

平均一条 query 约 `224s`，这在 demo 可接受边缘，但在真实高频使用里明显偏慢。

延迟高的主要直觉来源是：

- candidate pool 比较宽
- final verifier 要逐候选调用 LLM
- 整个链条仍然偏重

### 10.5 运行稳健性还不够强

数值 query 的 OOM 说明：

- 在 8GB GPU 环境中，系统对显存非常敏感
- 即使检索逻辑本身没问题，工程运行层也会把用户体验直接打断

---

## 11. 我对当前版本的诚实评价

### 11.1 已经具备的能力

当前版本已经能比较稳定地完成：

- 找 benchmark paper
- 找某类 evaluation paper
- 找包含特定实验设置 / benchmark split / 数据规模细节的论文
- 对单目标 query 返回论文 + evidence

如果你现在要做 demo，这部分已经足够拿来展示。

### 11.2 还不该夸大的地方

我不建议把当前版本表述成：

- “已经能稳定解决开放式 scholarly retrieval”
- “宽 query 下已经能自动完成最终筛选”
- “对任意正文细节都能稳检索”

更准确的表述应该是：

- 对明确 query 和单目标 query，当前系统效果已经相当不错
- 对宽 query，方向通常正确，但结果仍需人工二次判断
- 对极细粒度 / 数值级 query，当前运行稳健性还不足够可靠

---

## 12. 推荐结论

如果现在要给当前系统一个阶段性结论，我会写成：

> 当前 PaperSearchAgent 已经在 ACL 2025 long 这一封闭语料上展示出较强的目标论文锁定能力，尤其在 benchmark-oriented、evaluation-oriented 以及正文细节驱动的自然语言 query 上，能够稳定返回相关论文与 supporting evidence。其主要短板已从“检索不到”转移到“宽 query 下排序与判定边界不够尖锐”“整体推理延迟较高”“8GB GPU 下工程稳健性不足”。

这个结论是偏积极的，但不夸大。

---

## 13. 附：主要 trace_id

### 13.1 Targeted queries

- `q1_gaia_results`: `c8f15361949745ef`
- `q2_gpqa_gaia_agentic`: `bc957e8036174bde`
- `q3_chinese_factuality_benchmark`: `5955e4b99e2f44cc`
- `q4_mmlu_cf_contamination`: `e9495f1569614fb1`
- `q5_abgen_meta_eval`: `323f020492eb4c7e`
- `q6_ecomscriptbench`: `1d70c44b49a34cc8`
- `q7_memerag`: `b1654f6c1e464f4c`
- `q8_ref_long`: `6d43cee6745941f8`
- `q9_legal_agent_bench`: `8c130e45feeb464d`
- `q10_coir`: `619a6998fd6e4fc6`

### 13.2 Broad queries

- `b1_agent_benchmarks`: `427313e0915e4ae5`
- `b2_reliable_eval`: `d20a5e48db7b4d2a`
- `b3_rag_or_ir_benchmarks`: `9cf399b89bbc48d7`

### 13.3 Content-detail queries

- `c1_closed_test_public_val`: `7dcf0a1caff445f7`
- `c2_17_corpora_37_tools`: `52c1be996d434501`
- `c3_miracl_native_languages`: `21182840ddcb4330`
- `c4_605k_scripts_2_4m_products`: `2a0a0dd5b3d84050`

