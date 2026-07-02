# my-knowledge

个人知识库。沉淀可复用的技术知识、踩坑记录、配置与最佳实践。

---

## 仓库规范

> 本节是本仓库的事实源。后续对本仓库的任何新增 / 修改都必须遵守以下规则。

### 1. 命名

- 文件名、目录名**一律英文**，使用 **kebab-case**（小写 + 连字符），例：
  - `state-management.md`
  - `dio-interceptor.md`
- 统一使用 `.md` 格式。
- 正文语言：**中文为主**；变量 / 函数 / 类名等标识符用英文。

### 2. 目录结构

**开发相关 → `develop/`**

所有与开发有关的知识统一放在 `develop/` 下，按平台 / 主题分子目录：

| 目录 | 主题 |
|---|---|
| `develop/flutter/` | Dart / Flutter |
| `develop/ios/` | Swift / iOS |
| `develop/android/` | Kotlin / Android |

其他开发主题（如 `develop/tools/` 工具链）按需新增。

**自学相关 → `study/`**

自学内容（编程语言、计算机基础、外语等）统一放在 `study/` 下，按主题分子目录，用到再建。

**工作相关 → `work/`**

工作相关内容按公司 / 项目分子目录：

| 目录 | 主题 |
|---|---|
| `work/yxr/` | 寓小二（当前公司） |

**非开发相关 → 根目录子文件夹**

随手记、生活技能、文档整理等与开发无关的内容，在根目录新建对应文件夹（如 `notes/`、`life/`、`docs/`）。**目前不预建，用到再建。**

**空目录与图片**

- 空目录用 `.gitkeep` 占位，保证能提交到远端。
- 图片等资源放在所属主题目录下的 `assets/` 子目录，文件名同样 kebab-case。
  例：`develop/flutter/assets/provider-flow.png`
- **以单层主题目录为主**，避免过深嵌套。

### 3. 文件模板

每个知识文件建议遵循：

```markdown
# 标题

> 更新：YYYY-MM-DD ｜ 标签：flutter, state

正文……（中文为主，代码块用对应语言高亮）
```

- 首行 H1 标题。
- 可选的更新日期 / 标签行，便于检索。

### 4. 提交规范

- **每次记录 / 修改后自动 `git commit`**（无需用户手动提交）。
- 提交信息格式：`docs(<topic>): <简述>`
  - `<topic>` 取所属顶层目录名，例：`docs(flutter): 新增 Provider 状态管理笔记`
- 提交到 `main` 分支。
- **是否 `git push` 由用户决定**，不主动推送。

### 5. 索引维护

- 新增 / 删除文件时，同步更新下方「目录」清单。

---

## 目录

### develop / flutter

- [cupertino-textfield-content-misalign](develop/flutter/cupertino-textfield-content-misalign.md) — CupertinoTextField 文字 / placeholder 偏上不居中（`_BaselineAlignedStack` 行为 + 修复配方）
- **faraday_reborn**
  - [list-search-filter](develop/flutter/faraday_reborn/list-search-filter.md) — 列表搜索框（per-tab 模式 + 多 tab 共享模式）

### develop / ios

- [ios-dev-tools](develop/ios/ios-dev-tools.md) — iOS 开发工具（UDID 查询等）
- [inappwebview-orderedset-library-evolution-crash](develop/ios/inappwebview-orderedset-library-evolution-crash.md) — 预编译 flutter_inappwebview_ios 加载 WebView 崩溃（Library Evolution ABI 不对称）

### develop / protocol

- [server-driven-dialog](develop/protocol/server-driven-dialog.md) — 服务端驱动弹框协议（`YE-DIALOG` + `data`，按钮跳转用 `appRouter`（参数拼 `?` 后）走 `openServerDialogRouter`，App/PC 共用，改弹框不发版）

### study / ai

- [ai-app-dev-roadmap](study/ai/ai-app-dev-roadmap.md) — AI 应用层开发学习路线图（基于 iOS/Flutter 背景，6 阶段进阶）

### work / yxr

- [projects-overview](work/yxr/projects-overview.md) — 寓小二主要负责的 APP 项目总览（B 端 / C 端 / CRM，项目名 + 类型 + 仓库地址）
- [cc-docker-intro](work/yxr/cc-docker-intro.md) — 自定义 AI 开发 Docker 环境（tun2socks 透明代理 + Redis 配置同步 + Claude Code/Codex 容器化）
