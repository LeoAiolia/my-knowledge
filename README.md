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

### develop / ios

- [ios-dev-tools](develop/ios/ios-dev-tools.md) — iOS 开发工具（UDID 查询等）
