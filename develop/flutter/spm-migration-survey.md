# Flutter 插件 CocoaPods → SPM 迁移调研

> **调研日期**：2026-07-21
> **调研对象**：`faraday_reborn`（Flutter module）、`aster`（Flutter app）
> **Flutter 版本**：3.35.x（均满足 SPM 要求 ≥ 3.24，需 `flutter config --enable-swift-package-manager` 手动开启）

## 判定方法

1. **第一轮（锁定版本）**：解析两个项目的 `pubspec.lock`，对全部 281 个包（含传递依赖）逐一检查锁定版本源码中 `ios/` 或 `darwin/` 目录是否存在 `Package.swift`（Flutter 插件支持 SPM 的标志）。
2. **第二轮（最新版本/主干）**：对第一轮中「仅支持 CocoaPods」的原生依赖，进一步检查 pub.dev 最新版本或私有 git 仓库主干，确认升级后是否可获得 SPM 支持。

## 总体结论

| 分类 | 数量 | 说明 |
|---|---|---|
| 纯 Dart 包 | 236 | 无 iOS 原生代码，不涉及迁移 |
| 原生插件 | 45 | 需要逐一确认 SPM 支持 |
| ├─ 锁定版本已支持 SPM | 16 | 官方/主流插件为主 |
| ├─ 升级到最新版/主干可支持 | 10 | 含 hxj_ble_sdk（内部已支持，待发版） |
| ├─ 私有库，可自行改造 | 6 | 补 `Package.swift` 即可 |
| └─ 三方库，短期难支持 | 13 | 百度系、友盟、PAG 等，继续走 Pods 混编 |

**关键结论**：

- Flutter 的 SPM 支持与 CocoaPods **混编**，未迁移的插件继续走 Pod，可渐进式推进，不阻塞。
- 官方/主流插件（camera、video_player、url_launcher、path_provider、sqflite、shared_preferences、plus 系列）**已全部支持 SPM**。
- 不少私有库是**纯 Dart 包**，无需处理：`yxr_bluetooth`（5.x 重构为纯 Dart，BLE 走 flutter_blue_plus）、`sentry`（Dart 端）、`yxr_webview` / `yxr_video_player`（federated 壳）、`g_keyboard`、`yxr_table_view`、`instant_messaging`、`yxr_service`、`yxr_nfc`、`yxr_tab_bar`、`yxr_guidance`、`faraday_cupertino`、`faraday_theme`、`faraday_icons`、`lifecycle_lite`、`pull_to_refresh_flutter3`、`flutter_calendar_carousel` 等。
- ⚠️ `faraday_reborn` 是 **Flutter module**，iOS 宿主（iosb4reborn）目前通过 Pod 集成 module 产物，module 场景下插件的 SPM 集成路径与纯 Flutter app 不同，**建议先在 aster（纯 app）上试点**。

---

## 一、已支持 SPM（锁定版本即支持，16 个）

| 依赖 | 锁定版本 | 使用项目 |
|---|---|---|
| connectivity_plus | 6.1.5 | faraday_reborn、aster |
| share_plus | 12.0.2 (F) / 10.1.4 (A) | faraday_reborn、aster |
| wakelock_plus | 1.4.0 | faraday_reborn、aster |
| app_links | 6.4.0 | aster |
| device_info_plus | 11.5.0 | aster |
| file_picker | 10.3.10 | faraday_reborn |
| network_info_plus | 7.0.0 | faraday_reborn |
| package_info_plus | 9.0.0 | aster |
| camera_avfoundation（传递） | 0.9.21+3 | faraday_reborn、aster |
| flutter_blue_plus_darwin（传递） | 7.0.3 | faraday_reborn、aster |
| path_provider_foundation（传递） | 2.4.2 | faraday_reborn、aster |
| sensors_plus（传递） | 6.1.2 | faraday_reborn、aster |
| shared_preferences_foundation（传递） | 2.5.6 | faraday_reborn、aster |
| sqflite_darwin（传递） | 2.4.2 | faraday_reborn、aster |
| url_launcher_ios（传递） | 6.3.4 | faraday_reborn、aster |
| video_player_avfoundation（传递） | 2.8.4 | faraday_reborn、aster |

> 「传递」表示该包由直接依赖（如 url_launcher、video_player、cached_network_image、sp_util、wechat_camera_picker 等）间接引入。

## 二、升级到最新版/主干即可支持 SPM（10 个）

| 依赖 | 使用项目 | 锁定版本 | 最新版本 | 说明 |
|---|---|---|---|---|
| hxj_ble_sdk | faraday_reborn、aster | 0.5.7 ❌ | 主干 `b301795`（2026-07-21）✅ | 内部已支持 SPM，发个新 tag 更新 ref 即可 |
| fluwx | aster | 5.5.1 ❌ | **6.0.2** ✅ | 大版本升级，注意 breaking changes |
| photo_manager | aster | 3.7.1 ❌ | **3.10.0** ✅ | |
| qr_code_scanner_plus | aster | 2.0.10+1 ❌ | **2.2.0** ✅ | |
| flutter_fgbg | faraday_reborn | 0.7.1 ❌ | **0.8.0** ✅ | |
| pdf_image_renderer | faraday_reborn | 1.0.1 ❌ | **2.0.0** ✅ | 大版本升级 |
| permission_handler（apple 实现包） | aster | 9.4.6 ❌ | **9.4.10** ✅ | permission_handler 升最新即可 |
| flutter_secure_storage | aster | 9.2.4 ❌ | **10.3.1** ✅ | v10 改为 federated 架构，darwin 实现包 0.4.0 已支持 SPM；大版本升级注意 breaking |
| nfc_manager | faraday_reborn | fork 4.1.2 ❌ | 上游 **4.2.1** ✅ | 内部 fork（YuxiaorMobileTeam/flutter-nfc-manager）未同步上游 SPM 支持，建议切回上游或 rebase |
| ffmpeg_kit_flutter → **ffmpeg_kit_flutter_new** | faraday_reborn | 6.0.3 ❌ | **4.5.1** ✅ | 官方 ffmpeg-kit 已停更退役，社区续作支持 SPM，建议借迁移换包 |

## 三、最新版/主干仍不支持 SPM —— 私有库（可自行改造，6 个）

| 依赖 | 使用项目 | 主干 commit | 说明 |
|---|---|---|---|
| g_faraday | faraday_reborn | `f6f73d5` ❌ | 混合栈框架核心，改造优先级最高 |
| flutter_ttlock_plugin | faraday_reborn、aster | `610c83b` ❌ | 通通锁 |
| a_union_pay | aster | `bad3666` ❌ | 银联支付 |
| open_app_settings | aster | `8244ab3` ❌ | |
| yxr_ge_plugin | aster | `987904d` ❌ | |
| yxr_baidu_map | faraday_reborn | `cb2a8d3` ❌ | 封装百度地图，底层受百度 SDK 制约（见第四节） |

## 四、最新版仍不支持 SPM —— 三方库（继续走 CocoaPods 混编，13 个）

| 依赖 | 使用项目 | 最新版本 | 说明 |
|---|---|---|---|
| flutter_baidu_mapapi_base | faraday_reborn | 4.0.1+1 ❌ | 百度地图，官方维护 |
| flutter_baidu_mapapi_map | faraday_reborn | 4.0.1+1 ❌ | 同上 |
| flutter_baidu_mapapi_search | faraday_reborn | 4.0.1+1 ❌ | 同上 |
| flutter_baidu_mapapi_utils | faraday_reborn | 4.0.1+1 ❌ | 同上 |
| flutter_bmflocation | faraday_reborn | 3.8.4+1 ❌ | 百度定位 |
| umeng_common_sdk | faraday_reborn、aster | 1.3.0 ❌ | 友盟 |
| flutter_inappwebview_ios | faraday_reborn、aster | 1.1.2 ❌ | 社区高 star 插件，上游有 SPM 相关 issue，可持续关注 |
| flutter_keyboard_visibility | faraday_reborn、aster | 6.0.0 ❌ | 已停更，建议换替代方案 |
| app_installer | aster | 1.3.1 ❌ | |
| contacts_service_plus | faraday_reborn | 0.0.3 ❌ | |
| external_app_launcher | aster | 4.0.3 ❌ | |
| variable_app_icon | aster | 0.0.3 ❌ | |
| pag_darwin（传递，来自 pag_flutter） | faraday_reborn | 0.0.1 ❌ | 腾讯 PAG 动画库 |

---

## 迁移建议（优先级排序）

1. **升级三方依赖**（第二节 10 个）：成本低，收益直接；注意 fluwx 5→6、flutter_secure_storage 9→10、pdf_image_renderer 1→2 三个大版本升级的 breaking changes。
2. **改造私有库**（第三节 6 个）：补 `ios/<package>/Package.swift`，工作量可控；`g_faraday` 作为混合栈核心优先验证。
3. **三方硬骨头**（第四节 13 个）：继续走 CocoaPods 混编；其中 `flutter_keyboard_visibility` 已停更建议替换，`ffmpeg_kit_flutter` 建议换 `ffmpeg_kit_flutter_new`。
4. **试点顺序**：先在 aster（纯 Flutter app）开启 SPM 验证，再评估 faraday_reborn（Flutter module + 宿主 Pod 集成）的迁移路径。

## 附：纯 Dart 包说明

两个项目共 236 个纯 Dart 包（无 `ios/`/`darwin/` 原生代码），不出现在 Pod 依赖中，**无需任何处理**。其中容易误判的私有库：

| 包 | 纯 Dart 的原因 |
|---|---|
| yxr_bluetooth | 5.x 重构为纯 Dart，BLE 能力来自 flutter_blue_plus |
| sentry | 仅 Dart 端（非 sentry_flutter） |
| yxr_webview | federated 壳，原生在 flutter_inappwebview_ios |
| yxr_video_player | federated 壳，原生在 video_player_avfoundation / video_player_android |
| g_keyboard / yxr_table_view / yxr_guidance / yxr_tab_bar / instant_messaging / yxr_service / yxr_nfc | 纯 UI / Dart 逻辑封装，无 plugin platforms 声明 |
| faraday_cupertino / faraday_theme / faraday_icons | 纯 UI 组件/主题/字体 |
| lifecycle_lite / pull_to_refresh_flutter3 / flutter_calendar_carousel | 纯 Dart |

---

## 五、升级依赖对本地 Flutter 版本的要求（第三轮调研）

> 当前环境：**Flutter 3.35.7 / Dart 3.9.2**（两项目均通过 fvm 锁定 3.35.7）。
> 对第二节「升级即可支持 SPM」的 10 个依赖，逐一核对其目标版本的 `environment` 约束。

### ✅ 无需升级 Flutter，当前 3.35.7 直接可用（7 个）

| 依赖 | 目标版本 | SDK 要求 | 说明 |
|---|---|---|---|
| hxj_ble_sdk | 主干发新 tag | Dart ^3.9.2 | 正好匹配当前环境 |
| photo_manager | 3.10.0 | Dart ≥2.13 | 无压力 |
| flutter_fgbg | 0.8.0 | Dart ^3.8.0 | 无压力 |
| permission_handler | 12.0.3（apple impl 9.4.10） | Dart ^3.5.0 / Flutter ≥3.24 | 无压力 |
| flutter_secure_storage | 10.3.1 | Dart ≥3.3 / Flutter ≥3.19 | 无压力 |
| ffmpeg_kit_flutter_new | 4.5.1 | Dart ≥3.1 / Flutter ≥3.0 | 无压力 |
| qr_code_scanner_plus | **2.1.2**（⚠️ 不要升 2.2.0） | Dart ≥3.5 / Flutter ≥3.24 | SPM 从 2.1.0 开始支持；2.2.0 拔高到 Flutter ≥3.44 |

### ⚠️ 必须升级本地 Flutter（3 个）

| 依赖 | 目标版本 | 要求 | 说明 |
|---|---|---|---|
| fluwx | 6.0.2 | **Flutter ≥3.41 / Dart ^3.11.0** | SPM 只在 6.x 才有，无中间版本可选 |
| pdf_image_renderer | 2.0.0 | **Flutter ≥3.41 / Dart ^3.11.0** | SPM 只在 2.0.0 才有，无中间版本可选 |
| nfc_manager | 4.2.0+ | **Dart ^3.11.4**（约 Flutter ≥3.41） | 4.1.x 全系无 SPM，内部 fork 也未同步 |

### 结论

- **只升「零门槛」的 7 个**：原生插件 SPM 覆盖率从 16/45 提升到 23/45，**Flutter 保持 3.35.7 不动**。
- **fluwx、pdf_image_renderer、nfc_manager 这 3 个**把 SPM 支持与新版 SDK 约束绑定，想拿到 SPM 必须把项目 Flutter 升到 **≥3.41**（qr_code_scanner_plus 可用 2.1.2 规避）。
- 升 Flutter 是项目级决策（需全量回归）。建议**第一阶段先升 7 个零门槛依赖 + 改造私有库**，fluwx / pdf_image_renderer / nfc_manager 暂留 CocoaPods 混编，等下次统一升 Flutter 时再跟进。
