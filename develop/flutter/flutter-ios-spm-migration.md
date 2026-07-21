# Flutter iOS 迁移 SPM：插件 Package.swift 的 product 命名坑

> 更新：2026-07-21 ｜ 标签：flutter, ios, spm, swift-package-manager, cocoapods

Flutter iOS 工程从 CocoaPods 迁移到 Swift Package Manager（SPM）时，最容易踩的坑：**插件 `Package.swift` 里 library（product）名必须把插件名的下划线 `_` 换成连字符 `-`**，否则 SPM 集成直接失败。本文记录完整迁移流程、坑的根因与修复配方。

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

## 参考

- [Swift Package Manager for app developers](https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-app-developers)
- [Swift Package Manager for plugin authors](https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-plugin-authors)
