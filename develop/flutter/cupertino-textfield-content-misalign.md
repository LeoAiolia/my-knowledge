# CupertinoTextField 文字 / placeholder 偏上不居中

> 更新：2026-06-10 ｜ 标签：flutter, cupertino, text-field

`CupertinoTextField` 同时设了 `placeholder` 和某个 prefix/suffix（含 `clearButtonMode != never`）时，输入文字或 placeholder 在框内看起来**偏上、不居中**。本文记录根因（Flutter 3.35.7 SDK 行为）与修复配方。

## 1. 现象

```dart
CupertinoTextField(
  clearButtonMode: OverlayVisibilityMode.editing,
  placeholder: '搜索…',
  // 未设 style / textAlignVertical / cursorHeight
)
```

效果：placeholder 与输入文字的视觉中心在框的偏上位置，与左右相邻元素对不齐。**无外层高度约束也会出现**——不是被父级拉伸导致的。

## 2. 根因（Flutter 3.35.7 源码）

参考路径：`packages/flutter/lib/src/cupertino/text_field.dart`

### 2.1 触发条件

`_hasDecoration = true` 时，CupertinoTextField 内部不再是简单的「Padding + EditableText」，而是包成 `Row + Expanded + _BaselineAlignedStack`：

```
Row(crossAxisAlignment: center)
 ├─ prefix? (可选)
 ├─ Expanded( _BaselineAlignedStack )
 │     ├─ placeholder：SizedBox + Padding(7) + Text(普通行高 ≈ fontSize × 1.2)
 │     └─ editableText：Padding(7) + EditableText(带 strut, 行高 ≈ fontSize × 1.4)
 └─ suffix / clearButton?
```

`_hasDecoration` 在以下任一情况为 true：`placeholder != null` / `clearButtonMode != never` / `prefix != null` / `suffix != null`。

### 2.2 `_BaselineAlignedStack.performLayout` 的对齐逻辑

```dart
final double placeholderY =
    editableTextBaselineValue - placeholderBaselineValue;
final double offsetYAdjustment = math.max(0, placeholderY);
editableTextParentData.offset  = Offset(0, offsetYAdjustment);
placeholderParentData?.offset  = Offset(0, placeholderY + offsetYAdjustment);
```

它把两个子 box 按 **alphabetic baseline** 对齐——通过给 `editableText` / `placeholder` 加 y 偏移让两个 baseline 在同一水平线。

### 2.3 偏上的几种触发组合

| 配置 | 触发 |
|---|---|
| `placeholder` 用 `placeholderStyle` 字号 ≠ 主题默认（=EditableText 字号） | 两个 Text 行高不同 → Stack 给 placeholder 加非零 y 偏移 → placeholder 视觉偏上 |
| `cursorHeight` 显著大于字号（如 `cursorHeight: 22` 配字号 14） | cursor 撑高 EditableText 渲染 box，与 placeholder 高度不一致 → 同上 |
| `EditableText` 默认 strut 行高（≈ fontSize × 1.4）和普通 `Text`（≈ fontSize × 1.2）天然不同 | 即使字号相同也有 1–3 px 偏移；多数情况下视觉可接受，叠加上面两条会放大 |

### 2.4 `textAlignVertical` 不是元凶

源码 `_textAlignVertical` getter：

```dart
TextAlignVertical get _textAlignVertical {
  if (widget.textAlignVertical != null) return widget.textAlignVertical!;
  return _hasDecoration ? TextAlignVertical.center : TextAlignVertical.top;
}
```

`_hasDecoration = true` 时默认就是 `center`，不显式设也是居中——但**居中的是 EditableText 在它自己 box 内的位置**，**不**改变 `_BaselineAlignedStack` 引入的额外 y 偏移。所以光设 `textAlignVertical: center` 不解决问题。

## 3. 修复配方

> 来源：faraday_reborn 项目 `lib/src/features/search_house/pages/search_house_page.dart`，commit `0812d31e2`（2026-02-09）

```diff
  CupertinoTextField(
    // …
    clearButtonMode: OverlayVisibilityMode.editing,
+   textAlignVertical: TextAlignVertical.center,
+   style: context.grey9(15),
    placeholder: '搜索…',
-   cursorHeight: 22,
-   placeholderStyle: context.hint16,
+   cursorHeight: 16,
  )
```

三处改动各自的作用：

| 改动 | 作用 |
|---|---|
| 去掉独立的 `placeholderStyle` 自定字号，只保留 `style` | 让 `placeholderStyle` 通过 `style.merge(placeholderStyle)` 继承同字号，placeholder 与 EditableText 行高一致，`placeholderY = 0` |
| `cursorHeight` 调到与字号匹配（字号 15 → cursor 16） | 防止 cursor 反向把 EditableText box 撑大 |
| 显式 `textAlignVertical: TextAlignVertical.center` | 明确意图、防御源码默认行为变化 |

## 4. 排查 checklist

遇到 `CupertinoTextField` 文字 / placeholder 偏上时，按顺序排查：

- [ ] 是否同时设了 `placeholderStyle` 和 `style`，两者**字号是否一致**？不一致 → 删掉 `placeholderStyle` 字号字段，让它继承 `style`
- [ ] `cursorHeight` 是否远大于字号？拉到 `fontSize ± 1` 范围内
- [ ] `style` 是否显式指定？没有则用 `context.grey9(N)` 等显式给出（同时满足项目「TextStyle 必须显式 color」规范）
- [ ] 显式补 `textAlignVertical: TextAlignVertical.center`
- [ ] 仍偏上 → 用 `padding: EdgeInsets.fromLTRB(7, top, 7, bottom)` 上下不对称微调（兜底方案）

## 5. 兜底方案：固定容器高度

如果外层有设计稿规定的固定高度（如搜索栏 32/36），强制约束并配合 `padding` 收缩：

```dart
Container(
  height: 32,
  decoration: /* … */,
  child: CupertinoTextField(
    padding: const EdgeInsets.symmetric(horizontal: 7),
    textAlignVertical: TextAlignVertical.center,
    style: context.grey9(15),
    cursorHeight: 16,
    // …
  ),
)
```

这种写法跨字体 / 设备最稳定，缺点是要同步把外层 `Row` 的 `crossAxisAlignment` 改成 `stretch` 让 TextField 撑满高度。
