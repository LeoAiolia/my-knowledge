# Flutter iOS 迁移 SPM 踩坑记录（product 命名 / FlutterFramework 依赖）

> 更新：2026-07-24 ｜ 标签：flutter, ios, spm, swift-package-manager, cocoapods

Flutter iOS 工程从 CocoaPods 迁移到 Swift Package Manager（SPM）时，最容易踩的两个坑：

1. **插件 `Package.swift` 里 library（product）名必须把插件名的下划线 `_` 换成连字符 `-`**，否则 SPM 集成直接失败（第 2~4 节）。
2. **新版插件声明的 `FlutterFramework` wrapper 依赖，要求 Flutter SDK ≥ 3.44**，旧工具链构建必炸（第 8 节）。

本文记录完整迁移流程、坑的根因与修复配方。

## 1. 背景

- Flutter 3.24 引入 SPM 支持，Flutter 3.44 起 SPM 成为 iOS / macOS 原生依赖的默认管理方式，CocoaPods 进入维护模式（其 registry 2026-12-02 转为只读）。
- 官方要求插件**同时保留 CocoaPods + SPM 双支持**（`podspec` 别删），直到 CocoaPods 完全退役。

## 2. 坑的现象

已有 CocoaPods 工程执行 `flutter build ios`（SPM 开关已开）时，自动迁移阶段报错：

```
An error occurred when adding Swift Package Manager integration:
  Error: Unable to get Xcode project information:
xcodebuild: error: Could not resolve package dependencies:
  product 'hxj-ble-sdk' required by package 'fluttergeneratedpluginswiftpackage'
  target 'FlutterGeneratedPluginSwiftPackage' not found in package 'hxj_ble_sdk'.
```

## 3. 根因

Flutter 工具在 `flutter pub get` 时会生成 `FlutterGeneratedPluginSwiftPackage`（位于 `ios/Flutter/ephemeral/Packages/`），把每个插件聚合成一个本地 Swift package。**引用插件 product 时，工具机械地按「插件名下划线转连字符」的规则拼 product 名**，这是硬性实现，不是建议。

官方约定出处：[Swift Package Manager for plugin authors](https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-plugin-authors)，模板注释原文：

```swift
products: [
    // If the plugin name contains "_", replace with "-" for the library name.
    .library(name: "plugin-name", targets: ["plugin_name"])
],
```

即：**library 名用连字符，target 名保持下划线原样**。

当时 `hxj_ble_sdk@0.6.1` 的写法（错误）：

```swift
.library(name: "hxj_ble_sdk", targets: ["hxj_ble_sdk"])  // product 名未转连字符
```

修复后（`0.6.2`）：

```swift
.library(name: "hxj-ble-sdk", targets: ["hxj_ble_sdk"])
```

只改 product 名一行，target、源码、目录结构都不用动。

## 4. 修复配方

### 4.1 插件侧（根治，推荐）

1. 改插件仓库 `ios/<plugin_name>/Package.swift` 的 product 名为连字符形式。
2. commit、push、打新 tag。
3. App 侧 `pubspec.yaml` 升级 `ref` 即可，无需任何 override。

### 4.2 App 侧（临时绕过，无插件仓库权限时）

vendor 一份插件到本地改完后用 `dependency_overrides` 指向：

```yaml
dependency_overrides:
  some_plugin:
    path: vendor/some_plugin
```

注意：vendor 目录会被 `flutter analyze` 扫描（插件自带 example 的报错会污染分析结果），需在 `analysis_options.yaml` 排除：

```yaml
analyzer:
  exclude:
    - vendor/**
```

上游修复后务必删掉 vendor 和 override，回归 git 依赖。

### 4.3 绝不推荐

直接改 `~/.pub-cache` 缓存——只本机有效，`flutter pub cache clean` 或换机器即失效。

## 5. 完整迁移流程（CocoaPods → SPM）

```bash
# 1. 确认开关（3.44 起默认开）
flutter config --list | grep swift-package-manager
flutter config --enable-swift-package-manager   # 未开则执行

# 2. 触发自动迁移
flutter clean && flutter pub get
flutter build ios --config-only --debug
```

迁移成功后，按 Flutter 工具的提示清理 CocoaPods 残留：

```bash
cd ios
pod deintegrate
rm -f Podfile Podfile.lock && rm -rf Pods
```

并删掉 `ios/Flutter/Debug.xcconfig`、`Release.xcconfig` 中的 Pods include 行：

```diff
-#include? "Pods/Target Support Files/Pods-Runner/Pods-Runner.debug.xcconfig"
 #include "Generated.xcconfig"
```

### 次生坑：`Runner.xcworkspace` 别急着删

`pod deintegrate` 后直觉上会想把 `Runner.xcworkspace` 一起删掉，但 **Flutter 3.35 的 SPM 迁移逻辑要求 workspace 存在**，删了会报：

```
Exception: Xcode workspace not found.
```

保留即可（deintegrate 后它只引用 `Runner.xcodeproj`）；万一误删，手动重建：

`ios/Runner.xcworkspace/contents.xcworkspacedata`：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Workspace
   version = "1.0">
   <FileRef
      location = "group:Runner.xcodeproj">
   </FileRef>
</Workspace>
```

`ios/Runner.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist`：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>IDEDidComputeMac32BitWarning</key>
	<true/>
</dict>
</plist>
```

## 6. 迁移后的日常

- 加 / 升级 Flutter 依赖：**`flutter pub get` 一步到位**，SPM 聚合包自动重新生成，Xcode 构建时自动解析，没有 `pod install` 这类手动步骤。
- 新插件必须支持 SPM（有 `Package.swift` 且 product 名符合连字符约定），否则要么换插件、要么照第 4 节修、要么退回 CocoaPods 混合模式。
- 包缓存玄学问题：`flutter clean && flutter pub get`，或 Xcode `File → Packages → Reset Package Caches`。

## 7. 排查 checklist

| 现象 | 检查项 |
|---|---|
| `product 'xxx-yyy' not found in package 'xxx_yyy'` | 插件 `Package.swift` 的 product 名是否转连字符 |
| `Xcode workspace not found` | `ios/Runner.xcworkspace` 是否被误删 |
| 构建仍走 pod install | 工程 CocoaPods 残留未清理（Podfile / xcconfig include） |
| 新增依赖后构建失败 | 新插件是否支持 SPM |
| `the package at '.../Packages/.packages/FlutterFramework' cannot be accessed` | 插件声明了 `FlutterFramework` 依赖但 Flutter SDK < 3.44（见第 8 节） |

## 8. 坑二：新版插件的 `FlutterFramework` 依赖 × 旧工具链（Flutter < 3.44 构建必炸）

> 2026-07-24 实录：aster 项目（`.fvmrc` 锁 Flutter 3.35.7）一次依赖升级后 iOS 构建挂掉。

### 8.1 现象

`flutter run` / `flutter build ios` 在 xcodebuild 阶段报：

```
Error: Unable to get Xcode project information:
xcodebuild: error: Could not resolve package dependencies:
  the package at '<project>/ios/Flutter/ephemeral/Packages/.packages/FlutterFramework' cannot be accessed
  (.../ios/Flutter/ephemeral/Packages/.packages/FlutterFramework doesn't exist in file system)
```

### 8.2 根因

新版插件（本次命中：`photo_manager 3.10.0`、`qr_code_scanner_plus 2.1.2`）的 `Package.swift` 按官方新规范声明了对 Flutter 引擎 wrapper 包的依赖：

```swift
dependencies: [
  .package(name: "FlutterFramework", path: "../FlutterFramework")
],
// target 里：
.product(name: "FlutterFramework", package: "FlutterFramework")
```

这个 `FlutterFramework` 本地包（把 `Flutter.xcframework` 包装成 SPM binary target）**由 Flutter 工具链在 `pub get` / 构建时自动生成到 `ios/Flutter/ephemeral/Packages/.packages/FlutterFramework`**。自动生成逻辑位于 `flutter_tools/lib/src/macos/swift_package_manager.dart` 的 `createFlutterFrameworkSwiftPackage`。

实测各版本 SDK 源码（grep 验证）：

| Flutter 版本 | 有 `createFlutterFrameworkSwiftPackage` |
|---|---|
| 3.35.7 / 3.38.10 / 3.41.9 | ❌ 无 |
| 3.44.7 | ✅ 有 |

即该能力是 **3.44 周期引入**的（与「3.44 起 SPM 成为默认」同步）。旧工具链会把支持 SPM 的插件软链进 `.packages/`，但不会生成 wrapper 包，SPM 依赖解析阶段直接失败。

版本兼容矩阵：

| 插件 Package.swift | 工具链 < 3.44 | 工具链 ≥ 3.44 |
|---|---|---|
| 无 `FlutterFramework` 依赖（旧插件） | ✅ | ✅ |
| 有 `FlutterFramework` 依赖（新插件） | ❌ 本坑 | ✅ |

### 8.3 为什么 `pub get` 不拦

`photo_manager 3.10.0` 的 pubspec 只声明 `flutter: ">=2.2.0"`，版本求解器看不到工具链层的不兼容，要等 xcodebuild 做 SPM 依赖解析时才爆——**报错点离根因很远**，容易被误导去清缓存、重装 Pod。

### 8.4 修复方案

| 方案 | 做法 | 适用 |
|---|---|---|
| A 止血（推荐） | 命中插件降回不含该依赖的旧版本（如 `photo_manager: ^3.6.4`、`qr_code_scanner_plus: ^2.0.10+1`），再 `flutter clean && flutter pub get` | 留在旧 SDK、要立刻能跑 |
| B 治本 | 升级 Flutter SDK ≥ 3.44（改 `.fvmrc`；CI、私有库、废弃 API 需全面回归） | 团队统一决策后 |
| C 临时 hack | 手写 `ios/Flutter/ephemeral/Packages/.packages/FlutterFramework/Package.swift`（binaryTarget 指向 SDK 内 `Flutter.xcframework`） | 仅救急：`flutter clean` 即失效，不进 git，团队协作不可持续 |

### 8.5 排查命令（可复用）

```bash
# 1. 工程侧有没有直接引用（一般没有，用于排除）
grep -rn "FlutterFramework" ios/

# 2. 找出哪些插件声明了 FlutterFramework 依赖
for p in ios/Flutter/ephemeral/Packages/.packages/*/; do
  f="$p/Package.swift"
  [ -f "$f" ] && grep -q "FlutterFramework" "$f" && echo "$p"
done

# 3. 确认当前 SDK 工具链是否具备自动生成能力
grep -rn "createFlutterFrameworkSwiftPackage" \
  ~/fvm/versions/<sdk版本>/packages/flutter_tools/lib/src/macos/
```

> 教训：**升级插件前，先看新版本的 `Package.swift` 有没有 `FlutterFramework` 依赖**；有就必须配套 Flutter ≥ 3.44，否则锁回旧版。

## 参考

- [Swift Package Manager for app developers](https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-app-developers)
- [Swift Package Manager for plugin authors](https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-plugin-authors)
