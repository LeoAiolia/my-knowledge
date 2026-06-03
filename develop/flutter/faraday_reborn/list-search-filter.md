# 列表搜索框 ListSearchFilter 使用指南

faraday_reborn 项目中"列表页右上角搜索图标 → 全屏覆盖搜索框 → 按关键字 / 类型刷新列表"的通用方案。覆盖了**单 tab 模式**与**多 tab 共享搜索模式**两种用法。

## 1. 关键文件

| 文件 | 内容 |
|---|---|
| `lib/src/widgets/filter/list_search_filter.dart` | `ListSearchFilter` widget + `BuildListSearchFilterMixin`（覆盖层 UI）+ `SharedSearchTabsMixin`（多 tab 共享） |
| `lib/src/widgets/filter/search_filter_mixin.dart` | `SearchFilterMixin`（provider 端 `searchKey` / `searchKeyType` / `onSearch` / 400ms 防抖 / emoji 过滤） |

## 2. 两种模式对比

| 维度 | 单 tab / per-tab | 多 tab 共享 |
|---|---|---|
| 适用 | 只有一个列表、或多 tab 但每个 tab 独立搜索 | 多个 tab 共用同一关键字（审批列表等） |
| 切 tab 行为 | 各 tab `searchKey` 独立，切 tab 按目标 tab 关键字显隐覆盖层 | 关键字保留并同步给目标 tab provider，自动刷新；覆盖层不重建（不闪、不弹键盘） |
| 接入 mixin | `BuildListSearchFilterMixin` | 同上 + `SharedSearchTabsMixin<T, F>` |
| 参考实现 | `ContractListContainer` | `ContractApprovalList` / `LandlordContractApprovalList` / `ApprovalFlowListPage` |

---

## 3. Provider 准备（两种模式都需要）

让每个列表的 provider 挂 `SearchFilterMixin`，在 `assemble` 里把搜索字段拼到接口参数。

```dart
import 'package:g_faraday/g_faraday.dart';
import '../../../utils/base_provider.dart';
import '../../../widgets/filter/search_filter_mixin.dart';

class FooListProvider extends BaseProvider with SearchFilterMixin {
  FooListProvider() : super(initialRefresh: true);

  int _pageNum = 1;
  final _dataList = <JSON>[];
  List<JSON> get dataList => _dataList.toList(growable: false);

  @override
  Future<ProviderAssembleResult> assemble({bool loadMore = false}) async {
    if (!loadMore) _dataList.clear();
    final pageNum = loadMore ? _pageNum + 1 : _pageNum = 1;

    final parameters = <String, dynamic>{
      'pageNum': pageNum,
      'pageSize': 20,
      // ... 你的业务参数
    };
    // 搜索字段（只在有关键字时拼入）
    if (searchKey.isNotEmpty) {
      parameters['searchKey'] = searchKey;
      if (searchKeyType != null) {
        parameters['searchKeyType'] = searchKeyType;
      }
    }

    // ... 调接口、解析、return
  }
}
```

mixin 自带能力：
- `searchKey` / `searchKeyType` 字段
- `searchNotifier` / `searchKeyTypeNotifier`
- `searchGlobalKey`（per-tab 模式下覆盖层用）
- `onSearch(key, {searchKeyType, autoRefresh})`：400ms 防抖 + emoji 过滤，触发 `refreshList()`
- `refreshList()`：根据 `refreshController` 状态触发下拉刷新或 fallback `onRefresh()`

---

## 4. 模式一：单 tab / per-tab 独立搜索

### 4.1 接入步骤

1. State `with BuildListSearchFilterMixin`
2. `navigationBar` 的 `trailing` 放 `buildListSearchIcon()`
3. `CupertinoPageScaffold` 外层包 `buildSearchFilterPage(...)`
4. 多 tab 情况下在 `onPageChanged` 调 `onListTabChanged(currentProvider)`（按目标 tab 的 `searchKey` 自动显隐覆盖层）

### 4.2 最小示例（单列表）

```dart
class _FooListState extends State<FooList> with BuildListSearchFilterMixin {
  final _provider = FooListProvider();

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return buildSearchFilterPage<FooListProvider>(
      context,
      provider: _provider,
      searchTypeMap: const {
        0: '综合',
        1: '地址',
        2: '编号',
      },
      typePlaceholderMap: const {
        1: '地址(小区、楼栋、门牌号)',
      },
      child: CupertinoPageScaffold(
        navigationBar: navigationBar(
          'Foo 列表',
          trailing: buildListSearchIcon(),
        ),
        child: ChangeNotifierProvider<FooListProvider>.value(
          value: _provider,
          builder: (context, _) => RefreshablePageScaffold<FooListProvider>(
            sliversBuilder: (context, provider) => provider.dataList
                .map((e) => SliverToBoxAdapter(child: FooItem(item: e)))
                .toList(growable: false),
          ),
        ),
      ),
    );
  }
}
```

### 4.3 多 tab per-tab 模式

参考 `ContractListContainer`：每个 tab 自己一个 `SearchFilterMixin` provider，关键字独立。`onPageChanged` 里：

```dart
onPageChanged: (index) {
  setState(() => _pageIndex = index);
  onListTabChanged(_providers[_pageIndex]);
},
```

`onListTabChanged` 内部按目标 provider 的 `searchKey` 是否非空决定要不要显示搜索覆盖层。

---

## 5. 模式二：多 tab 共享搜索（推荐用于审批类列表）

### 5.1 接入步骤

1. State `with BuildListSearchFilterMixin, SharedSearchTabsMixin<MyPage, MyProvider>`（顺序：`BuildListSearchFilterMixin` 在前）
2. `@override List<MyProvider> get tabProviders => _providers;`
3. tab view 的 `onPageChanged` / `onTabChanged: handleTabChanged`
4. `buildSearchFilterPage(provider: activeProvider, ...)`
5. 路由指定初始 tab 的页面：`@override int get initialTabIndex => _initialIndex;`

不需要传 `shareSearchKey` 之类的 flag —— with 了 `SharedSearchTabsMixin` 就自动获得共享行为。

### 5.2 最小示例

```dart
class _MyListState extends State<MyList>
    with
        BuildListSearchFilterMixin,
        SharedSearchTabsMixin<MyList, MyListProvider> {
  late final List<MyListProvider> _providers;

  @override
  List<MyListProvider> get tabProviders => _providers;

  @override
  void initState() {
    super.initState();
    _providers = TabType.values
        .map((t) => MyListProvider(t))
        .toList(growable: false);
  }

  @override
  void dispose() {
    for (final p in _providers) {
      p.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return buildSearchFilterPage<MyListProvider>(
      context,
      provider: activeProvider,            // mixin 提供
      searchTypeMap: const {0: '综合', 1: '地址', 3: '编号'},
      typePlaceholderMap: const {1: '地址(小区、楼栋、门牌号)'},
      child: CupertinoPageScaffold(
        navigationBar: navigationBar(
          '我的列表',
          trailing: buildListSearchIcon(),
        ),
        child: FaradayTabBarView(
          showIndicator: true,
          itemCount: _providers.length,
          itemBuilder: (context, index) =>
              ChangeNotifierProvider<MyListProvider>.value(
            value: _providers[index],
            builder: (context, _) => _buildList(context),
          ),
          titleBuilder: (index) => _providers[index].title,
          onPageChanged: handleTabChanged,  // mixin 提供
        ),
      ),
    );
  }
}
```

### 5.3 路由指定初始 tab

`ApprovalFlowListPage` 通过路由参数选中默认 tab：

```dart
class _State extends State<ApprovalFlowListPage>
    with
        BuildListSearchFilterMixin,
        SharedSearchTabsMixin<ApprovalFlowListPage, ApprovalFlowListProvider> {

  late final int _initialIndex;

  @override
  int get initialTabIndex => _initialIndex;

  @override
  void initState() {
    super.initState();
    final idx = _tabTypes.indexOf(widget.type);
    _initialIndex = idx < 0 ? 0 : idx;
    // ... 初始化 _providers / _providersList
  }
}
```

### 5.4 Provider 用 map 存储时的适配

`SharedSearchTabsMixin.tabProviders` 要求 list。如果业务用 map（如 `ApprovalFlowListPage` 按 type 存储 provider 便于 `_filterBarKeys` 等按 key 查找），在 initState 顺手展开成 list 即可：

```dart
late final Map<TabType, MyProvider> _providers;
late final List<MyProvider> _providersList;

@override
List<MyProvider> get tabProviders => _providersList;

@override
void initState() {
  super.initState();
  _providers = {for (final t in _tabTypes) t: MyProvider(t)};
  _providersList = [for (final t in _tabTypes) _providers[t]!];
}
```

### 5.5 切 tab 时要做额外事

`handleTabChanged` 只做"同步关键字 + 刷新目标 tab"。如果需要附加动作（比如切 `FilterBarKey`），包一层 lambda：

```dart
onPageChanged: (i) {
  handleTabChanged(i);
  doExtraStuff();
},
```

---

## 6. 工作原理（共享模式）

### 6.1 切 tab 不重建覆盖层

`SharedSearchTabsMixin` lazy 维护一个 `_sharedSearchKey: GlobalKey`，override 父 mixin 的 `sharedSearchKey` getter。`buildSearchFilterPage` 内部：

```dart
key: sharedSearchKey ?? provider.searchGlobalKey,
```

共享模式下所有 tab 的 `ListSearchFilter` widget 用同一个稳定 GlobalKey → Flutter Element 复用、State 复用 → `CupertinoTextField` 不重新 init → **不闪、不重新 autofocus、焦点 / 文本 / 光标位置都保留**。

### 6.2 切 tab 时关键字同步

`handleTabChanged(int?)`：

```dart
void handleTabChanged(int? index) {
  if (index == null || index == _currentTabIndex || !mounted) return;
  final previous = activeProvider;
  setState(() => _currentTabIndex = index);
  final target = activeProvider;
  if (target.searchKey != previous.searchKey ||
      target.searchKeyType != previous.searchKeyType) {
    // autoRefresh: false 直接写入 notifier，避开 400ms 防抖；再手动 refresh。
    target.onSearch(previous.searchKey,
        searchKeyType: previous.searchKeyType, autoRefresh: false);
    target.refreshList();
  }
}
```

约定："上一个 active provider 的 searchKey" 即全局共享关键字；切 tab 时同步给目标 provider 并触发刷新。

`int?` 签名同时兼容：
- `FaradayTabBarView.onPageChanged`（`ValueChanged<int>`）
- `YxrTabbarView.onTabChanged`（`Function(int?)`）

### 6.3 ApprovalFlowListPage 为什么要 KeepAliveWrapper

`YxrTabbarView` 内部用 `ExtendedTabBarView`，离屏 tab 默认会卸载。当 tab 内部有自己的 State（如 `ApprovalFlowTabPage` 内部维护"仅看未读" / FilterBar selected），需要 `KeepAliveWrapper` 包一层避免每次切回来重建丢状态。

我们的 contract approval 页面 tab 内只有 list（数据来自外部 provider，重建无副作用），用 `FaradayTabBarView` 也不需要 KeepAlive。

---

## 7. `buildSearchFilterPage` 参数速查

```dart
Widget buildSearchFilterPage<F extends SearchFilterMixin>(
  BuildContext context, {
  required Widget child,
  required Map<int, String>? searchTypeMap,    // null = 不显示覆盖层；空 map = 不显示类型 pill
  required F? provider,                        // 当前 active provider
  String? placeholder,                          // 整体 placeholder 兜底（searchTypeMap 为空时尤为有用）
  Map<int, String>? typePlaceholderMap,        // 按 type 给不同 placeholder
  bool showBackButton = true,                  // 覆盖层左上角是否显示返回按钮
})
```

### `searchTypeMap` 约定

| 含义 | value 约定 |
|---|---|
| 综合 | 0 |
| 地址 | 1 |
| 房源编号 | 2 |
| 合同编号 | 3 |
| 租客信息 | 5 |
| 业主信息 | 6 |

各页可按业务取舍。注意业主信息是 **6**（与租客信息 5 区分），传给后端的 `searchKeyType` 也用 6。

### placeholder 计算优先级

1. 显式传的 `placeholder` 字符串
2. `searchTypeMap` 为空 → "搜索: 关键词"
3. `typePlaceholderMap` 命中当前 `searchKeyType` → "搜索: <显式文案>"
4. 当前是综合（type=0 或 null）→ 把 `searchTypeMap` 除 0 外的 label 拼 `/`
5. `searchTypeMap[searchKeyType]` 命中 → "搜索: <label>"
6. 兜底 "搜索: 关键词"

---

## 8. 注意事项

- **`SearchFilterMixin.dispose()` 漏 dispose `searchKeyTypeNotifier`** —— mixin 自身遗留，所有使用者通病；不影响功能，但严格意义上 leak 一个 ValueNotifier。等有空时统一修。
- **emoji 自动过滤**：用户输入 emoji 时 `onSearch` 内部直接 toast 提示并不刷新。
- **业主审批 `_dataList.clear()` 时序**：曾有 `LandlordContractApprovalListProvider` 把 `_dataList.clear()` 写在请求后导致失败时残留旧数据的 bug，已修正为入口处 clear。其他 provider 都用入口处 clear 这个习惯。

## 9. 待办 / TODO

- `SearchFilterMixin.searchKeyTypeNotifier` 的 dispose 补齐
- ContractListContainer 的 per-tab 模式可考虑迁移到共享模式（产品需求未明确时不动）
