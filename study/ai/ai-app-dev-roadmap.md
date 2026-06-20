# AI 应用层开发学习路线图

> 更新：2026-06-20 ｜ 标签：ai, roadmap, flutter, ios, career

基于 10 年 iOS 开发经验（3 年 OC + 2 年 Swift + 5 年 Flutter），向 **AI 应用层开发** 转型的系统路线图。

---

## 核心定位

> **不做模型研究员，做能把 AI 落地的移动端工程师。**

角色定义：用大模型 API / on-device 推理 / RAG 等技术，构建有智能能力的移动应用。你的移动端工程功底是**护城河**，AI 是**放大器**。

---

## 总览

| 阶段 | 主题 | 时间 | 核心输出 |
|------|------|------|----------|
| P0 | AI 基础认知 | 1 周 | 理解 LLM 工作原理、Token/Context/Embedding 等核心概念 |
| P1 | API 集成入门 | 2 周 | Flutter App 接入 DeepSeek API，实现 streaming chat |
| P2 | 工具调用与 Agent | 3 周 | Function Calling → 多步 Agent → MCP 集成 |
| P3 | RAG 与知识检索 | 3 周 | 本地向量检索 + 云端 LLM 的混合应用 |
| P4 | 端侧推理 | 4 周 | Core ML / llama.cpp 移动端部署 |
| P5 | 全栈 AI 产品 | 持续 | 完整 AI 产品从设计到上架 |

---

## P0：AI 基础认知（1 周）

### 目标

理解大语言模型的核心概念，能看懂 AI 技术文章，能和其他 AI 工程师正常对话。

### 学习内容

| 主题 | 要点 | 参考资源 |
|------|------|----------|
| LLM 工作原理 | Autoregressive、Token、Embedding、Attention（只需概念层面，不推导数学） | 3Blue1Brown 可视化视频 |
| 核心概念 | Context Window、Temperature、Top-P、System Prompt vs User Prompt | DeepSeek / OpenAI 官方文档 |
| 模型谱系 | DeepSeek / Claude / GPT / Gemini / 开源模型（Llama、Qwen）的能力差异与适用场景 | 各厂商模型卡 |
| Token 经济 | 输入/输出 Token 如何计算、缓存命中、成本估算 | DeepSeek 官方定价页 |
| Prompt 基础 | 系统提示词设计、少样本示例、思维链 | DeepSeek Prompt 指南 + Anthropic Prompt Engineering Guide |

### 实践

- [ ] 分别在 DeepSeek Chat、Claude.ai、ChatGPT 里完成同一个复杂任务，对比效果
- [ ] 算一笔账：一个 100 轮对话的客服 App 大概花多少钱（对比 DeepSeek vs Claude 成本）
- [ ] 阅读 [DeepSeek API 文档](https://platform.deepseek.com/api-docs/) 了解模型能力和调用方式

### 输出

- 一篇个人笔记：`llm-core-concepts.md`（用自己的话总结核心概念）

---

## P1：API 集成入门（2 周）

### 目标

在 Flutter App 里跑通 DeepSeek API 的 streaming chat。

### 为什么选 DeepSeek 作为主力 API

| 优势 | 说明 |
|------|------|
| OpenAI 兼容格式 | 市面教程/工具/SDK 几乎零成本适配 |
| 国内直连 | 无需翻墙，开发调试体验顺畅 |
| 中文能力顶级 | 中文场景回复质量优于多数海外模型 |
| 价格极低 | 约 ¥1/百万 Token，学习期随意调用不心疼 |
| 支持完整 | Chat / Streaming / Function Calling / JSON Mode 均已支持 |

### 学习内容

| 主题 | 要点 |
|------|------|
| HTTP 调用 | REST API 基础、SSE（Server-Sent Events）协议解析 |
| Streaming | Dart `Stream` + `http` 包接收逐 Token 输出 |
| UI 渲染 | 打字机效果、Markdown 渲染（消息气泡） |
| 错误处理 | 429 Rate Limit、网络超时重试、Token 超限截断 |
| 敏感信息 | API Key 安全存储（Keychain / 环境变量 / 后端中转） |

### 技术选型

```
后端方案 A：客户端直连 DeepSeek API（快速原型用）
后端方案 B：自建中转服务（生产环境推荐，保护 API Key + 可做审计/限流）
```

> P1 阶段用方案 A 快速跑通；P5 切方案 B。

### 核心代码形态

```dart
// DeepSeek API 兼容 OpenAI 格式，streaming chat 调用示例
final client = http.Client();
final request = http.Request(
  'POST',
  Uri.parse('https://api.deepseek.com/v1/chat/completions'),
);
request.headers['Authorization'] = 'Bearer $apiKey';
request.headers['Content-Type'] = 'application/json';
request.body = jsonEncode({
  'model': 'deepseek-chat',           // DeepSeek-V3，性价比主力
  // 'model': 'deepseek-reasoner',    // DeepSeek-R1，复杂推理场景
  'max_tokens': 4096,
  'stream': true,
  'messages': [
    {'role': 'system', 'content': '你是一个有帮助的助手。'},
    {'role': 'user', 'content': '你好，介绍一下你自己。'},
  ],
});

final response = await client.send(request);
await for (final chunk in response.stream.transform(utf8.decoder)) {
  // SSE 格式：data: {"choices":[{"delta":{"content":"你好"}}]}\n\n
  for (final line in chunk.split('\n')) {
    if (line.startsWith('data: ') && !line.startsWith('data: [DONE]')) {
      final json = jsonDecode(line.substring(6));
      final content = json['choices']?[0]?['delta']?['content'];
      if (content != null) {
        // 追加到消息文本 → 更新 UI
      }
    }
  }
}
```

### DeepSeek 模型选择速查

| 模型 | 适用场景 | 特点 |
|------|----------|------|
| `deepseek-chat`（V3） | 日常对话、内容生成、工具调用 | 速度快、成本最低、P1-P3 主力 |
| `deepseek-reasoner`（R1） | 复杂推理、数学、代码分析 | 自带 CoT 思维链，慢但深度高 |

### 实践项目：AI Chat Demo

一个简易聊天 App，功能清单：
- [ ] 多会话管理（创建/删除/切换对话）
- [ ] Streaming 打字机效果
- [ ] Markdown 消息渲染
- [ ] 错误与重试处理
- [ ] System Prompt 可配置
- [ ] 模型切换开关（deepseek-chat / deepseek-reasoner）

### 输出

- 一个可运行的 Flutter AI Chat Demo（上传到个人 GitHub）

---

## P2：工具调用与 Agent（3 周）

### 目标

让 AI 不只是聊天，而是能**执行操作**——查数据、调接口、操作 UI。

### 学习内容

| 主题 | 要点 |
|------|------|
| Function Calling | Tool Definition（JSON Schema）、tool_choice、Multi-tool 编排 |
| Tool 执行循环 | LLM 选 Tool → 执行 → 结果回传 → LLM 继续 的完整循环 |
| 结构化输出 | JSON Mode / Structured Output，确保返回可解析的 JSON |
| ReAct Agent | Thought → Action → Observation 循环的工程实现 |
| MCP 协议 | Model Context Protocol 原理，客户端/服务端开发 |
| 上下文管理 | 长对话中的 Tool Result 裁剪、Summary 压缩 |

### 关键概念

```
用户发送消息
  → DeepSeek 判断是否需要调用 Tool（返回 finish_reason: "tool_calls"）
    → App 执行 Tool（读数据库 / 调 API / 操作设备）
      → 结果回传给 DeepSeek（role: "tool" 消息）
        → DeepSeek 继续推理，决定：继续调 Tool / 生成最终回答
```

> **DeepSeek Function Calling 与 OpenAI 完全兼容**，`tools` 参数用 JSON Schema 定义，返回 `tool_calls` 数组。可直接参考 OpenAI 的 Function Calling 文档来学习，模式完全一致。

### 实践项目：智能日记 App

- [ ] 聊天界面中可调用 Tool：
  - `save_diary` — 保存日记
  - `search_diary` — 关键词搜索历史日记
  - `get_weather` — 获取当前天气（结合日记上下文）
  - `analyze_mood` — 分析近期情绪趋势
- [ ] 多 Tool 串联：用户说「帮我记一下今天的事，查查上周同一天写了什么，对比一下心情」
- [ ] 结构化输出：用 `response_format: {"type": "json_object"}` 让 DeepSeek 返回固定 Schema 的 JSON

### 输出

- 可运行的 AI 日记 App（GitHub）
- 一篇笔记：`function-calling-patterns.md`（总结 Tool 编排模式）

---

## P3：RAG 与知识检索（3 周）

### 目标

构建「带记忆 / 带知识库」的 AI 应用——让 LLM 能基于私有文档回答问题。

### 学习内容

| 主题 | 要点 |
|------|------|
| Embedding | 文本转向量的概念、常用模型选择（见下方说明） |
| 向量数据库 | 选型对比：SQLite + 向量扩展（sqlite-vec） vs Pinecone vs Qdrant |
| 文档处理 | PDF/HTML/Markdown 解析、Text Chunking 策略（固定长度 / 语义分块） |
| 检索策略 | 语义检索 / 关键词混合检索（BM25 + Vector）、Re-rank |
| RAG Pipeline | Ingest（分割→向量化→存储）→ Retrieve（查询→检索→重排）→ Augment（组装 Prompt）→ Generate |
| 高级 RAG | Query Rewrite、HyDE、Self-RAG、多轮对话中的上下文拼接 |

### Embedding 模型选择

> **注意：DeepSeek 目前不提供 Embedding API**，需要选其他方案。

| 方案 | 模型 | 说明 |
|------|------|------|
| 云端（推荐入门） | OpenAI `text-embedding-3-small` | 便宜（$0.02/1M Token）、效果好；需翻墙或用代理 |
| 云端（国内） | 阿里通义 `text-embedding-v3` | 国内直连、中文效果好、有免费额度 |
| 本地（进阶） | all-MiniLM-L6-v2 → Core ML | 完全离线、隐私保护、P4 阶段做 |

> P3 阶段先用通义 Embedding（国内直连最省心）；P4 阶段再切入本地 Embedding。

### 移动端特别考量

- **本地向量库**：sqlite-vec（Flutter 可用 `sqflite` 桥接）、ObjectBox
- **Embedding 计算**：本地小模型（all-MiniLM-L6-v2 转 Core ML）或云端 API
- **存储**：向量数据放在本地，保护用户隐私

### 实践项目：个人知识库助手

基于本仓库 `my-knowledge`：
- [ ] 解析仓库中所有 Markdown 文件
- [ ] 分块 → 向量化 → 存入本地向量库
- [ ] 对话时先检索相关片段 → 组装上下文 → 送给 LLM 回答
- [ ] 支持「我上次记录的 CupertinoTextField 修复方案是什么？」

### 输出

- 本地知识库助手 App
- 一篇笔记：`rag-on-mobile.md`

---

## P4：端侧推理（4 周）

### 目标

在 iOS / Android 设备上本地运行小模型，实现离线 AI 能力。

### 学习内容

| 主题 | 要点 |
|------|------|
| 模型格式 | GGUF（llama.cpp）、Core ML（`.mlmodelc`）、TensorFlow Lite |
| Core ML | 模型转换（PyTorch → Core ML via coremltools）、性能调优（ANE / GPU / CPU） |
| llama.cpp | 移动端编译、量化级别（Q4_K_M vs Q8_0）、Metal/CoreML backend |
| Apple Intelligence | App Intents、Writing Tools、Image Playground 集成 |
| 混合策略 | 小任务本地 / 复杂任务云端（模型路由） |
| 性能优化 | 内存占用、首 Token 延迟、解码速度、电池消耗 |

### 端侧可跑模型（2026 年参考）

| 模型 | 参数量 | 量化后大小 | iOS 实测速度 |
|------|--------|-----------|-------------|
| Llama 3.2 3B | 3B | ~2 GB (Q4_K_M) | 15-25 tok/s (iPhone 15 Pro) |
| Phi-4-mini | 3.8B | ~2.5 GB | ~20 tok/s |
| Qwen 2.5 1.5B | 1.5B | ~1 GB | 30-40 tok/s |
| Gemma 3 1B | 1B | ~700 MB | 40+ tok/s |

### 实践项目：离线翻译 / 润色 App

- [ ] 集成 llama.cpp 到 Flutter（通过 FFI / Method Channel）
- [ ] 用 Qwen 2.5 1.5B 实现离线文本润色
- [ ] 实现混合策略：短句本地翻、长文云端翻
- [ ] 性能监控：首 Token 延迟、内存峰值

### 输出

- 离线 AI 翻译 App Demo
- 一篇笔记：`on-device-inference-ios.md`

---

## P5：全栈 AI 产品（持续）

### 目标

从 Demo 走向产品——架构、性能、安全、上架。

### 学习内容

| 主题 | 要点 |
|------|------|
| 后端中转服务 | 自建 API Gateway（Node.js/Python/Go）、限流、鉴权、审计日志 |
| SSE/WebSocket | 长连接管理、断线重连、心跳 |
| 多模型路由 | 按任务类型 / 成本 / 延迟选模型（deepseek-chat 日常 / deepseek-reasoner 复杂推理 / 本地小模型离线） |
| Prompt 管理 | Prompt 版本控制、A/B 测试、线上热更新 |
| 可观测性 | Token 用量追踪、错误率、P99 延迟、用户反馈闭环 |
| 安全合规 | API Key 保护、用户数据脱敏、App Store 审核注意点 |
| 包体积 | 端侧模型按需下载（On-Demand Resources） |

### 实践项目：把你的 Demo 升级为产品

- [ ] 加后端中转服务
- [ ] 加入崩溃收集和用量统计
- [ ] 编写隐私政策和用户协议
- [ ] 上架 TestFlight / Google Play Beta
- [ ] 收集 10 个真实用户反馈并迭代

---

## 里程碑时间线

```
          P0          P1          P2           P3           P4          P5
         基础认知     API集成     Agent        RAG          端侧推理     全栈产品
Week:     1          2-3         5-7          8-10         11-14       15+
          │          │           │            │            │           │
          ▼          ▼           ▼            ▼            ▼           ▼
        概念笔记    Chat App   日记App      知识库助手    离线翻译     产品化
```

---

## 关键资源清单

### 官方文档（精读）

- [DeepSeek API 文档](https://platform.deepseek.com/api-docs/) — 主力 API，Chat/Streaming/Function Calling/JSON Mode
- [OpenAI API Docs](https://platform.openai.com/docs) — Function Calling 部分写得最好，DeepSeek 完全兼容，可直接参考
- [Anthropic Claude API Docs](https://docs.anthropic.com/en/api) — 作为对比参考，Prompt Engineering 指南质量高
- [Apple Machine Learning](https://developer.apple.com/machine-learning/) — Core ML / Create ML
- [llama.cpp](https://github.com/ggerganov/llama.cpp) — 端侧推理基石

### 课程

- [DeepLearning.AI — ChatGPT Prompt Engineering for Developers](https://www.deeplearning.ai/short-courses/chatgpt-prompt-engineering-for-developers/)（免费短课，1 小时）
- [DeepLearning.AI — Building Systems with the ChatGPT API](https://www.deeplearning.ai/short-courses/building-systems-with-chatgpt/)（免费短课，1 小时）
- [DeepLearning.AI — LangChain for LLM Application Development](https://www.deeplearning.ai/short-courses/langchain-for-llm-application-development/)（了解 LangChain 思想，但不建议在移动端用）

### 必读论文（概念层面）

- [Attention Is All You Need](https://arxiv.org/abs/1706.03762) — Transformer 源头
- [Retrieval-Augmented Generation for Knowledge-Intensive NLP Tasks](https://arxiv.org/abs/2005.11401) — RAG 起源

---

## DeepSeek 注意事项

### 当前能力边界（2026-06）

| 能力 | 支持情况 | 说明 |
|------|----------|------|
| Chat / Streaming | ✅ 完全支持 | 兼容 OpenAI 格式 |
| Function Calling | ✅ 完全支持 | `tools` + `tool_choice`，与 OpenAI 一致 |
| JSON Mode | ✅ 完全支持 | `response_format: {"type": "json_object"}` |
| 64K Context | ✅ 支持 | deepseek-chat 默认 64K |
| Vision（图片理解） | ❌ 不支持 | 纯文本模型，需图片场景用 GPT-4o / Claude |
| Embedding | ❌ 不提供 | P3 阶段用通义/OpenAI Embedding 替代 |
| Fine-tuning | ❌ 不提供 | 应用层开发一般不需要 |

### 关键注意点

1. **R1 的思维链不可见**：`deepseek-reasoner` 默认不返回 CoT 内容（出于安全策略），你只能拿到最终回答。如果需要调试推理过程，考虑用开源模型本地跑。
2. **Prompt 注入敏感**：DeepSeek 对 System Prompt 注入的抵抗力弱于 Claude，生产环境需要加输入清洗 + 输出过滤。
3. **服务稳定性**：高峰期偶有延迟波动，生产环境务必加重试机制和降级方案（切换到备用模型）。
4. **数据隐私**：API 数据默认经过 DeepSeek 服务器，涉密/涉敏场景考虑纯端侧方案（P4）。

---

## 不建议投入的方向

| 方向 | 原因 |
|------|------|
| Python 深度学习框架（PyTorch/JAX） | 你是做应用层，不需要训练模型 |
| LangChain / LlamaIndex（移动端） | 太重，不适合移动端；手写几十行 Dart 更可控 |
| CUDA / GPU 集群 | 不在应用层范围内 |
| 提示词工程师（纯 Prompt 岗位） | 不可持续，真正值钱的是工程落地能力 |
| Web 全栈 AI（Next.js + Vercel AI SDK） | 除非你有兴趣扩张到 Web；否则聚焦移动端 |

---

## 学习原则

1. **项目驱动** — 每个阶段必须有可运行的 App 输出，不纯看文档
2. **先跑通再优化** — 第一个版本可以很丑，但必须能跑
3. **Dart 优先** — 尽可能在 Flutter 生态内解决问题，少写 Python/Node
4. **记录沉淀** — 每完成一个阶段在 `study/ai/` 下写一篇笔记
5. **商业思维** — 始终问自己「这个能力能解决什么用户问题？有人愿意付费吗？」
