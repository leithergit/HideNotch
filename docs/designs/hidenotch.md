# HideNotch 设计文档

- 日期：2026-09-27
- 状态：已评审（设计阶段），待写实施计划
- 目标系统：macOS 27.0（26A428），MacBook（M4，带刘海内屏）

## 1. 目标

把带刘海屏幕的菜单栏背景涂成纯黑，使刘海与菜单栏融为一体。

**约束**

- 不降低分辨率，保留刘海两侧的菜单栏空间。
- 不修改桌面壁纸（TopNotch 1.3.2 的壁纸方案在 macOS 26+ 的透明菜单栏下已失效；TopNotch 闭源，无代码可参考）。
- 菜单栏文字、图标保持可读，菜单点击行为不受影响。

**成功标准**

1. 带刘海内屏的顶部菜单栏区域为纯黑，与刘海连成一体。
2. 菜单项可正常点击；普通窗口标题栏不被遮挡。
3. 全屏应用中不显示黑条。
4. 分辨率变化、睡眠唤醒、切换桌面空间后黑条位置仍正确。
5. 可从菜单栏图标开关黑条；可设置开机自启。

**v1 范围外**：外接（无刘海）屏幕涂黑、圆角下沿、偏好设置窗口。

## 2. 可行性验证（Spike，2026-09-27）

一次性原型（未保留）在目标机器上验证：

- 屏幕参数：逻辑分辨率 1800×1169；`frame.maxY - visibleFrame.maxY = 39`；`safeAreaInsets.top = 38`。
- 在菜单栏区域放置无边框纯黑窗口，层级 `NSWindow.Level.mainMenu - 1`：刘海融合 ✓、菜单可点击 ✓、浅色模式下菜单栏文字仍可读 ✓。
- **陷阱**：AppKit 默认通过 `constrainFrameRect(_:to:)` 把窗口挪到菜单栏下方，导致黑条压住应用窗口标题栏。覆盖该方法原样返回 frame 后位置正确（`requested == actual == (0, 1130, 1800, 39)`）。

## 3. 工程形态

- Swift Package Manager，无 `.xcodeproj`。最低 macOS 26，Swift 6 语言模式。
- Targets：
  - `HideNotchCore`（library）：全部逻辑，可测试。
  - `HideNotch`（executable）：`main.swift` 薄入口，仅创建 `NSApplication` 与 `AppDelegate`。
  - `HideNotchTests`：Swift Testing 单元测试。
- `scripts/build-app.sh`：`swift build -c release` → 组装 `HideNotch.app`（`Info.plist` 含 `LSUIElement=YES`、`CFBundleIdentifier=com.leether.HideNotch`）→ ad-hoc `codesign` → 复制到 `~/Applications`。

## 4. 组件

### 4.1 `BarGeometry`（纯函数）

```swift
struct ScreenMetrics: Equatable {
    var frame: CGRect
    var visibleFrame: CGRect
    var safeAreaTop: CGFloat
}
enum BarGeometry {
    /// 无刘海（safeAreaTop <= 0）返回 nil。
    static func barRect(for m: ScreenMetrics) -> CGRect?
}
```

- 高度 `h = max(frame.maxY - visibleFrame.maxY, safeAreaTop)`。
- 返回 `CGRect(x: frame.minX, y: frame.maxY - h, width: frame.width, height: h)`。
- 取最大值是为了覆盖“自动隐藏菜单栏”（此时菜单栏高度为 0，但刘海高度仍在）。

### 4.2 `BarWindow`（`NSWindow` 子类）

- `override func constrainFrameRect(_:to:) -> NSRect` 原样返回（见 §2 陷阱）。
- `styleMask = .borderless`，`backgroundColor = .black`，`isOpaque = true`，`hasShadow = false`。
- `ignoresMouseEvents = true`（点击穿透到菜单栏）。
- `level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue - 1)`。
- `collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]`；**不含** `.fullScreenAuxiliary`，因此不出现在全屏空间。
- `isReleasedWhenClosed = false`。

### 4.3 `OverlayController`

```swift
protocol ScreenProviding { func currentScreens() -> [ScreenMetrics] }  // 生产实现包装 NSScreen.screens
protocol BarWindowHosting: AnyObject { var frame: CGRect { get }; func show(at: CGRect); func hide() }
@MainActor final class OverlayController {
    init(screens: ScreenProviding, makeWindow: @escaping () -> BarWindowHosting)
    var isEnabled: Bool { get set }   // 开启 → refresh()；关闭 → 隐藏并释放所有窗口
    func refresh()                    // 按当前屏幕重建：多则隐藏移除，少则创建，已有则调整位置
}
```

- 每块带刘海的屏幕一个窗口（按 `BarGeometry` 返回非 nil 的屏幕依序对应）。
- 由 `AppDelegate` 订阅以下通知并调用 `refresh()`：
  - `NSApplication.didChangeScreenParametersNotification`
  - `NSWorkspace.didWakeNotification`
  - `NSWorkspace.activeSpaceDidChangeNotification`

### 4.4 `Preferences`

- 包装 `UserDefaults`（可注入，测试用独立 suite）。
- `overlayEnabled: Bool`，默认 `true`。

### 4.5 `LoginItemService`

```swift
protocol LoginItemControlling { var isEnabled: Bool { get }; func setEnabled(_ on: Bool) throws }
```

- 生产实现基于 `SMAppService.mainApp`：`isEnabled` 读取 `status == .enabled`；`setEnabled` 调用 `register()` / `unregister()`。
- 状态以系统为准，不另存 UserDefaults。

### 4.6 `StatusItemController`

- `NSStatusItem`，图标使用 SF Symbol（如 `rectangle.topthird.inset.filled`）。
- 菜单：
  - 「黑色菜单栏」（✓ 反映 `Preferences.overlayEnabled`）→ 切换并驱动 `OverlayController.isEnabled`。
  - 「开机自启」（✓ 反映 `LoginItemControlling.isEnabled`）→ `setEnabled`；抛错时菜单项标题附加“（失败）”，并记录 `os_log`。
  - 分隔线，「退出」。
- 菜单每次打开前（`menuWillOpen`）刷新勾选状态。

## 5. 数据流

```
启动 → Preferences 读取 → OverlayController.isEnabled = pref → refresh()
                        → StatusItemController 挂载
屏幕参数变化 / 唤醒 / 切换空间 → OverlayController.refresh()
菜单切换「黑色菜单栏」 → Preferences 写入 → OverlayController.isEnabled
菜单切换「开机自启」   → LoginItemService.setEnabled
```

## 6. 边界情况与风险

| 情况 | 处理 |
|---|---|
| 自动隐藏菜单栏 | 黑条按刘海高度显示（§4.1），符合“与刘海融合”目标 |
| 全屏应用 | 依赖不加入全屏空间，人工验收确认 |
| 无刘海屏幕 / 外接屏 | 不创建窗口 |
| 插拔显示器、改分辨率 | 屏幕参数通知 → `refresh()` |
| 亮色壁纸下菜单栏文字颜色 | 当前壁纸已验证正常；列入验收清单，出问题再加兜底，v1 不预先实现 |
| ad-hoc 签名下 `SMAppService` | 可能需要在系统设置中批准；失败时菜单显式提示，不静默 |

## 7. 测试

**单元测试（TDD，Swift Testing）**

- `BarGeometry`：有刘海、无刘海（nil）、自动隐藏菜单栏（高度取刘海）、非原点屏幕（多屏坐标）。
- `BarWindow`：`constrainFrameRect` 原样返回；level、collectionBehavior（不含 `.fullScreenAuxiliary`）、`ignoresMouseEvents`、背景色。
- `OverlayController`（假 `ScreenProviding` + 假 `BarWindowHosting`）：开启时按刘海屏数量创建；屏幕减少时移除；frame 变化时调整；关闭时全部隐藏。
- `Preferences`：默认值为 true；写入后可读回。
- `StatusItemController` 的菜单动作逻辑通过假 `LoginItemControlling` 测试：成功切换、抛错时标题提示。

**人工验收清单**

1. 刘海与菜单栏融为纯黑
2. 菜单项可点击
3. 窗口标题栏未被遮挡
4. 全屏应用中不显示黑条
5. 切换桌面空间、打开调度中心后正常
6. 睡眠唤醒后正常
7. 系统设置中更改分辨率后位置正确
8. 菜单开关黑条生效，重启 app 后保持
9. 开机自启：勾选后注销重新登录，app 自动运行
10. 换一张亮色壁纸，菜单栏文字仍可读
