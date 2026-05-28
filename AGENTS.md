# my-knowledge

个人知识库。沉淀可复用的技术知识、踩坑记录、配置与最佳实践。

> 本文件是面向 AI 代理的指引，规范与 `README.md` 的「仓库规范」一节**保持一致**；任一处改动，两者必须同步更新。

## 触发场景

用户表达"记一下 / 帮我记录 / 保存 / 存到知识库"等意图时，把内容整理为 `.md` 写入本仓库，并遵守以下规范。

## 仓库规范

### 1. 命名

- 文件名、目录名**一律英文**，kebab-case（小写 + 连字符），如 `state-management.md`、`dio-interceptor.md`。
- 统一 `.md` 格式；正文**中文为主**，标识符（变量 / 函数 / 类名）用英文。
- 同一主题内容追加到已有文件，不重复创建。

### 2. 目录结构

- **开发相关 → `develop/`**，按平台 / 主题分子目录：
  - `develop/flutter/` — Dart / Flutter
  - `develop/ios/` — Swift / iOS
  - `develop/android/` — Kotlin / Android
  - 其他开发主题（如 `develop/tools/` 工具链）按需新增。
- **非开发相关 → 根目录子文件夹**（随手记、生活技能、文档整理等），如 `notes/`、`life/`、`docs/`；用到再建、不预建。
- 空目录用 `.gitkeep` 占位，保证能提交到远端。
- 图片等资源放在所属主题目录下的 `assets/` 子目录（kebab-case），如 `develop/flutter/assets/provider-flow.png`。
- 以单层主题目录为主，避免过深嵌套。

### 3. 文件模板

- 首行 H1 标题；可选的更新日期 / 标签行；正文（代码块用对应语言高亮）。

### 4. 提交

- 每次记录 / 修改后**自动 `git commit`**，信息格式 `docs(<topic>): <简述>`（`<topic>` 取所属主题目录名）。
- 提交到 `main`；**不主动 `git push`**，由用户决定。

### 5. 索引

- 新增 / 删除文件时，同步更新 `README.md` 的「目录」清单（索引以 `README.md` 为准）。
