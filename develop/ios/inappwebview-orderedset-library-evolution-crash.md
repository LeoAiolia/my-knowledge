# 预编译 flutter_inappwebview_ios 加载 WebView 崩溃（Library Evolution ABI 不对称）

> 更新：2026-05-29 ｜ 标签：iOS、faraday、xcframework、Library Evolution、EXC_BAD_ACCESS、踩坑

## 一、现象

- B 端 iOS（`iosb4reborn`）集成 faraday 的**预编译** `flutter_inappwebview_iosRelease`。
- 能编译、能打包、能启动；**一进到带 InAppWebView 的页面就崩**。
- 换成**源码集成**（`pod 'flutter_inappwebview_ios', path: ...`）就正常。
- 关键迷惑点：**重新编译 + 重新上传服务器没用；连 CI 机器自己打的包也崩。**

## 二、崩溃特征

```
Thread 1: EXC_BAD_ACCESS (code=1, address=0x10)
OrderedSet.index(of:)  ->  contents[object]      ← 崩在这
OrderedSet.append(_:)
WKUserContentController.addPluginScript(_:)
InAppWebView.prepareAndAddUserScripts()
InAppWebView.prepare()
FlutterWebViewController.init(...)
```

崩在 `OrderedSet`（inappwebview 依赖的一个 Swift 泛型库）的字典访问上，地址 `0x10` 这种小偏移 = **字段偏移算错**的典型信号。

## 三、排查过程（少走弯路）

依次排除了：缺包、资源（Storyboard/隐私包）丢失、静态库资源拷不进、注册符号缺失、dyld 加载失败、**编译器版本不一致**、**两份 OrderedSet 打架**。

拆开服务器上的 xcframework 对比编译设置，才定位到真因：

| | 预编译 inappwebview | 宿主 OrderedSet（源码） |
|---|---|---|
| `-enable-library-evolution` | **开** | **没开** |
| 动态依赖 OrderedSet | 只有 1 份（无内嵌重复） | — |

> 拆包小抄：`unzip` 服务器上的 `.xcframework.zip`；`framework/Modules/*.swiftmodule/*.swiftinterface` 头部记录了**编译器版本与 module-flags**（能看到有没有 `-enable-library-evolution`）；用 Mach-O 加载命令可确认动态依赖了几份某库。

## 四、根因

> **inappwebview 是开着 Library Evolution 编的，而它依赖的 OrderedSet 没开——两者的 ABI 布局规则不对称。** inappwebview 按"弹性布局"去访问 OrderedSet 这个泛型 struct 的字段，但实际加载的 OrderedSet 是固定布局、没导出对应的弹性访问入口，于是字段偏移算错，读到非法地址崩溃。

这解释了所有现象：

- **CI 自己编也崩** → 崩的根源是这个**编译开关不对称**，跟编译器版本无关。
- **源码集成不崩** → 源码集成时两者都按普通 app pod（都不开 Library Evolution）一起编，对称一致。

## 五、修复（最小改动，只动 Podfile）

在 `iosb4reborn/Podfile` 的 `post_install` 里，让 `OrderedSet` 也开 Library Evolution：

```ruby
post_install do |installer|
    flutter_post_install(installer) if defined?(flutter_post_install)
    installer.generated_projects.each do |project|
        project.targets.each do |target|
            target.build_configurations.each do |config|
                config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = deployment_target
                # 匹配预编译 inappwebview 的 resilient ABI，否则 OrderedSet 泛型访问会崩
                if target.name == 'OrderedSet'
                    config.build_settings['BUILD_LIBRARY_FOR_DISTRIBUTION'] = 'YES'
                end
            end
        end
    end
end
```

`pod install` 后重新编译运行，崩溃消失。✅（若仍崩，先 `rm -rf ~/Library/Developer/Xcode/DerivedData/*` 清掉旧产物再装。）

## 六、通用提醒

faraday 的预编译 `xxxRelease` 框架都是开 Library Evolution 编的。**今后凡是被它们依赖、但在宿主走源码的 Swift 库**，都可能撞同样的崩溃——崩溃栈停在某个 Swift 泛型库的内部访问、`EXC_BAD_ACCESS` 小地址，就先去 `post_install` 给那个库补 `BUILD_LIBRARY_FOR_DISTRIBUTION = YES`。

> 更彻底的方案（备选）：把这类被依赖的 Swift 库也纳入 CI、用相同设置打成配套预编译框架，从源头保证 ABI 一致，省得每个工程手动兜。

## 附：`-enable-library-evolution`（Library Evolution）是什么

**一句话**：它让一个 Swift 框架的二进制接口（ABI）变"稳定"，使得**用不同 Swift 编译器版本编出来的框架，也能被安全地调用**——这是分发预编译 `.xcframework` 的前提。

**为什么需要它**：默认情况下，Swift 编译器会把依赖的类型布局当成"固定不变"来优化——比如直接把"某字段在结构体里第 16 字节"这种偏移**写死**进调用方的二进制。性能好，但脆：对方框架一改结构、或换个编译器版本重编，偏移就对不上了。这也是 Swift 框架历来对"用什么 Xcode 编的"很敏感的原因。

**开了之后**：编译器**不再写死布局**，改成运行时通过元数据去"问"对方："你这个字段到底在第几字节？" 这层间接（resilient / 弹性访问）带来两个效果：

1. ✅ **跨编译器版本兼容**：对方框架升级、或换 Xcode 重编，调用方不用重编也能正常工作。预编译 xcframework 必须靠它，否则换个 Xcode 就用不了（也是本地 Xcode 26.x/Swift 6.3 能加载 CI 用 6.2.1 编的包的原因）。
2. ⚠️ **要求双方"约定一致"**：弹性访问能成立，前提是**被依赖方也导出了对应的弹性入口**。如果调用方按弹性方式访问，而被依赖方压根没开、没导出这些入口，就会"按弹性规则算偏移、却落在固定布局上" → 偏移错位 → 崩溃。

**这次的坑正是第 2 点**：inappwebview 开了、OrderedSet 没开，一个用弹性规则、一个是固定布局，对不上。把 OrderedSet 也打开，两边都用同一套弹性规则，问题解决。

> 类比：Library Evolution 像"框架之间约定用统一标准接口对接"。inappwebview 已按标准接口伸出插头，但 OrderedSet 没装这个标准插座——硬插就短路了。让 OrderedSet 也装上同款插座，就对上了。
