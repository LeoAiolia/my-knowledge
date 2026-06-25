# 服务端驱动弹框协议（Server-Driven Dialog）

> 更新：2026-06-25 ｜ 标签：protocol, api, flutter, ios, pc

一套**后端下发、客户端通用渲染**的错误弹框协议。目标：接口报错需要弹框时，文案 / 按钮 / 跳转全部由服务端下发，**改这些不用 App 发版**。App / PC 共用同一份契约。

---

## 1. 背景与借鉴

灵感来自 B 端 iOS 既有的 `YE-13001`（服务购买弹框，`iosb4reborn/.../APIManager.swift`）：服务端把弹框内容下发、客户端解析渲染。但 YE-13001 的问题是**和"购买服务"业务强耦合**、按钮动作写死、编码用"JSON 字符串套在 message 里"。

本协议把它**抽象成与业务无关的通用弹框**：

- 触发不再一码一逻辑，统一用保留错误码 `YE-DIALOG`。
- 弹框内容放在标准 `data` 字段（复用正常响应的 data，后端少改）。
- 按钮跳转用 `router.appRouter` / `router.pcRouter`，**参数直接拼在路由后面**（`yxr2b://ff/xxx?id=1`），不再单独下发 `routerParam`。App 端跳转交给 `Application.openServerDialogRouter`。

---

## 2. 触发约定

| 项 | 约定 |
|---|---|
| HTTP 状态码 | `400` |
| `errorCode` | `YE-DIALOG`（保留码，表示"本次响应是一个通用弹框"） |
| 判定 | `errorCode == "YE-DIALOG"` → 读 `data` 渲染弹框 |

> `errorCode` 是开关，`data` 是内容。不能靠"有没有 data"判断，因为正常响应也带 data。

---

## 3. 响应体结构

```jsonc
{
  "errorCode": "YE-DIALOG",
  "message": "存在多个水电表长期未充值",   // 纯文本兜底：老版本认不了 YE-DIALOG 时退回 toast
  "data": { /* 见下 */ }
}
```

`message` 必须是**能独立成句的完整文案**（降级兜底用），不要把弹框 JSON 塞进 message 字符串。

### data 字段

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `version` | int | 是 | 协议 / 样式版本，当前固定 `1`（见下方说明） |
| `title` | string | 否 | 标题 |
| `content` | string | 是 | 正文，整句下发，禁止客户端拼接（支持 `\n` 换行） |
| `align` | string | 否 | 正文对齐：`auto` / `center` / `left`，缺省 `auto`（换行数 > 2 居左，否则居中） |
| `buttons` | array | 否 | `0~2` 个，空则客户端补一个"我知道了"（仅关闭） |

**关于 `version`**：当前**暂未启用**，固定下发 `1`，客户端按本文档这一种样式渲染即可。预留它是为了**后续扩展新弹框样式**——例如要加底部弹窗、带图标 / 配图、富文本等新形态时，由后端抬高 `version`（如 `2`），客户端按 `version` 分支选择对应样式渲染；老客户端遇到不认识的高版本则按"降级规则"退化为现有样式或纯文本，从而新旧并存、互不影响。

---

## 4. buttons —— 跳转用 router

每个按钮：

```jsonc
{
  "text": "去查看",
  "style": "primary",                  // default | primary
  "router": {
    "appRouter": "yxr2b://ff/alarm_device_list_page?useMsgId=1541",
    "pcRouter":  ""
  }
}
```

| 字段 | 必填 | 说明 |
|---|---|---|
| `text` | 是 | 按钮文案 |
| `style` | 否 | `default` / `primary`，缺省 `default`（仅影响视觉，primary 为主操作蓝底） |
| `router` | 否 | 跳转配置；`null` 表示仅关闭弹框 |

`router` 对象：

| 字段 | 说明 |
|---|---|
| `appRouter` | App 路由，**参数直接拼在后面**（如 `yxr2b://ff/xxx?id=1&type=2`）；空串 = App 端无此跳转 |
| `pcRouter` | PC 路由（同理拼参数）；空串 = PC 端无此跳转 |

> 不再下发 `routerParam` / `paramName`：参数统一拼在 `appRouter` / `pcRouter` 的 `?` 后面（与消息接口 `extendInfo` 的早期 routerParam 写法相比少一个字段，后端更省事）。

### appRouter 支持的 scheme

| scheme | 含义 | 参数处理 |
|---|---|---|
| `yxr2b://ff/<router>?a=b` | Flutter 页 | 客户端拆 `?`，参数解析进 arguments |
| `yxr2b://native/<path>?a=b` | 原生页（含 `native_webview_page` 开 H5） | 同上 |
| `http(s)://...` | H5 网页 | **不拆**，整串作为网页 URL 打开（`?` 后是网页自己的参数） |
| `weapp://<appId>;<path>` | 微信小程序 | 直接启动小程序 |
| `WeECs://<corpId>;<url>` | 微信客服 | 直接打开客服 |

> **关键规则：只有 `yxr2b://` 开头的才拆 `?` 解析参数；打开网页（`http(s)://`）整串传入不拆。**

### 按钮规则（强制）

- **按权限下发**：无权限的按钮**后端不下发**，客户端不做权限判断。
- **仅关闭按钮**：`router` 直接为 `null` → 点击只关闭弹框。
- 跳转按钮：各端取自己的 `*Router`，为空 = 该端无此跳转。

---

## 5. 完整示例

```jsonc
{
  "errorCode": "YE-DIALOG",
  "message": "存在多个水电表长期未充值",
  "data": {
    "version": 1,
    "title": "水电表长期未充值提醒",
    "content": "截止2025-09-09，存在5个电表，3个冷水表，1个热水表，长时间未充值。",
    "align": "left",
    "buttons": [
      {
        "text": "取消",
        "style": "default",
        "router": null
      },
      {
        "text": "去查看",
        "style": "primary",
        "router": {
          "appRouter": "yxr2b://ff/alarm_device_list_page?useMsgId=1541",
          "pcRouter":  ""
        }
      }
    ]
  }
}
```

---

## 6. 客户端处理要点

- 命中 `errorCode == "YE-DIALOG"` → 解析 `data` 渲染弹框。
- 按钮点击：`router == null` / 本端 `*Router` 为空 → 仅关闭；否则把本端 `*Router` 交给 `Application.openServerDialogRouter`（App）/ PC 路由跳转。
- `openServerDialogRouter` 按 scheme 分发：`weapp://` → 小程序、`WeECs://` → 客服、`yxr2b://...?a=b` → 拆 `?` 解析参数后走 `openRouter`、其余（`http(s)://`）整串走 `openRouter`。
- 本端 `*Router` 为空 → 该端无此跳转（按钮置灰 / 隐藏，或仅关闭）。

### 降级规则（"敢不发版"的底线）

| 情况 | 行为 |
|---|---|
| `version` 高于客户端支持 | 退化为 标题 + 内容 + 单个"我知道了" |
| `data` 解析失败 | 退回 `message` 普通 toast |
| `buttons` 为空 | 自动补一个"我知道了"（仅关闭） |
| `appRouter` scheme 未注册 | 不跳转、不崩（沿用 `openRouter` 现有兜底 toast） |

> 原则：服务端可大胆下发新字段 / 新路由，老版本只会"少一点能力"，绝不崩、绝不白屏。升级协议（加新字段）必须同步抬高 `version`。

---

## 7. 后端落地清单

- 业务码设为 `YE-DIALOG`，同时返回可独立成句的 `message`。
- 弹框结构放进标准 `data` 字段；`data.content` 必填、整句。
- 按钮按权限过滤后再下发；仅关闭按钮 `router` 给 `null`。
- 参数直接拼在 `appRouter` / `pcRouter` 的 `?` 后面，**不要再用 routerParam**。
- App / PC 各下发对应 `*Router`，某端不支持则给空串。

---

## 8. 实现落地（faraday + 原生）

链路（大多数请求经原生代理）：

```
原生发请求 → 错误时回传 {code:500, data:{code, message, reqId, extra:<服务端 data 字符串>}}
  → faraday _handleResponse → BusinessError(errorCode:'YE-DIALOG', dialogRaw:extra)
  → Net.request 命中 errorCode → ServerDialog.show(dialogRaw) 弹框 → 返回 Result.error('')
    （吞掉错误，业务侧 await 正常返回、UI.hideLoading 照常执行）
```

落点：

| 端 | 文件 | 改动 |
|---|---|---|
| iOS | `iosb4reborn/.../Faraday/Net.swift` | error 分支透传响应体 `data`（`extra` 字段，JSON 字符串）。通用透传，原生不识别业务码 |
| Android | `androidtob/.../FaradayNet.kt` + `NetError.kt` | 同上，`NetError` 加 `data` 字段、`failed()` 透传 `extra` |
| faraday | `lib/src/utils/net.dart` | `BusinessError` 加 `dialogRaw`；解析填充；`Net.request` 识别 `YE-DIALOG` → 弹框 |
| faraday | `lib/src/utils/server_dialog.dart` | `ServerDialog`：解析协议体、`showYxrAlert` 渲染、降级、对齐 |
| faraday | `lib/src/utils/application.dart` | 新增 `openServerDialogRouter`（拆 `?`、按 scheme 分发；`openRouter` 不变） |

要点：

- **原生只做透传**（把响应体 `data` 原样带回），弹框的解析 / 渲染 / 跳转全在 faraday，一份 Dart 覆盖 iOS + Android。
- 弹框靠 `Faraday.topContext` 全局弹出；栈顶为原生页时无 context，则不弹（交原生兜底）。
- 跳转**不污染** `Application.openRouter`，单独走 `openServerDialogRouter`。
