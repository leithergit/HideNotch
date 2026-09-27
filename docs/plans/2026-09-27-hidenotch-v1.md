# HideNotch v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 一个常驻菜单栏的 macOS 小工具，在带刘海屏幕的菜单栏区域下方铺一层纯黑窗口，使刘海与菜单栏融为一体，可开关、可开机自启。

**Architecture:** SwiftPM 包：`HideNotchCore` 库承载全部逻辑（纯函数几何计算、`NSWindow` 子类、按屏幕管理窗口的控制器、偏好、开机自启、菜单栏图标），`HideNotch` 可执行目标只做启动。系统依赖（屏幕列表、窗口、登录项）通过协议注入，以便用假对象做单元测试。`scripts/build-app.sh` 打包成 ad-hoc 签名的 `.app`。

**Tech Stack:** Swift 6.4（Swift 6 语言模式）、AppKit、ServiceManagement（`SMAppService`）、Swift Testing、SwiftPM（tools 6.2）、Xcode 27 工具链。

**Spec:** `docs/designs/hidenotch.md`

## Global Constraints

- 最低系统：macOS 26（`platforms: [.macOS(.v26)]`），`// swift-tools-version: 6.2`。
- 无第三方依赖；只用 Apple 公开 API。
- Bundle ID：`com.leether.HideNotch`；`LSUIElement=YES`（不在 Dock 显示）。
- 黑条窗口层级：`NSWindow.Level.mainMenu.rawValue - 1`；`collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]`，不含 `.fullScreenAuxiliary`。
- 黑条高度：`max(frame.maxY - visibleFrame.maxY, safeAreaInsets.top)`；`safeAreaInsets.top <= 0` 的屏幕不处理。
- 菜单文案：「黑色菜单栏」「开机自启」「退出」；开机自启出错时标题为「开机自启（失败）」。
- `overlayEnabled` 偏好默认 `true`。
- 不直接提交到 `main`；在 `feature/hidenotch-v1` 分支上小步提交，提交信息末尾附：
  `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`

## Review Focus

1. **Dock 在底部或左侧** 会改变 `visibleFrame` 的原点和宽度 —— 黑条高度只能取决于顶部差值，不能被 Dock 影响。→ Task 1 `dockDoesNotAffectBar`。
2. **关闭状态下屏幕变化**（插拔、唤醒、切换空间都会触发 `refresh()`）—— 关闭时 `refresh()` 不得创建任何窗口。→ Task 3 `refreshWhileDisabledCreatesNothing`。
3. **反复 refresh / 反复开关**（每次切换空间都会 refresh）—— 窗口数量不能增长、不能泄漏。→ Task 3 `repeatedRefreshIsIdempotent`、`reEnableReusesSlots`。
4. **开机自启注册失败**（ad-hoc 签名常见）—— 菜单要显示失败，勾选状态如实反映系统状态；下次成功后提示消失。→ Task 5 `loginItemFailureIsShown`、`loginItemSuccessClearsFailure`。
5. **启动时偏好为关闭** —— 启动后不应出现黑条；菜单勾选为关。→ Task 3 `newControllerIsDisabled` + Task 5 `menuReflectsDisabledPreference`。

---

## File Structure

| 文件 | 职责 |
|---|---|
| `Package.swift` | 包定义：`HideNotchCore`、`HideNotch`、`HideNotchTests` |
| `Sources/HideNotchCore/BarGeometry.swift` | `ScreenMetrics` + 黑条矩形纯计算 |
| `Sources/HideNotchCore/BarWindow.swift` | `BarWindowHosting` 协议 + `BarWindow`（NSWindow 子类） |
| `Sources/HideNotchCore/OverlayController.swift` | `ScreenProviding` 协议、`SystemScreens`、`OverlayController` |
| `Sources/HideNotchCore/Preferences.swift` | UserDefaults 包装 |
| `Sources/HideNotchCore/LoginItem.swift` | `LoginItemControlling` 协议 + `SystemLoginItem`（SMAppService） |
| `Sources/HideNotchCore/StatusItemController.swift` | 菜单栏图标与菜单逻辑 |
| `Sources/HideNotchCore/AppDelegate.swift` | 组装各组件、订阅系统通知 |
| `Sources/HideNotch/main.swift` | 启动入口 |
| `Resources/Info.plist` | app bundle 元数据 |
| `scripts/build-app.sh` | 构建、组装 `.app`、ad-hoc 签名、安装到 `~/Applications` |
| `Tests/HideNotchTests/*.swift` | 各组件单元测试与共享假对象 |

---

### Task 1: 包脚手架 + BarGeometry

**Files:**
- Create: `Package.swift`
- Create: `Sources/HideNotchCore/BarGeometry.swift`
- Create: `Sources/HideNotch/main.swift`（临时占位，Task 6 替换）
- Test: `Tests/HideNotchTests/BarGeometryTests.swift`

**Interfaces:**
- Consumes: 无
- Produces:
  - `public struct ScreenMetrics: Equatable, Sendable { var frame: CGRect; var visibleFrame: CGRect; var safeAreaTop: CGFloat; init(frame:visibleFrame:safeAreaTop:) }`
  - `public enum BarGeometry { static func barRect(for: ScreenMetrics) -> CGRect? }`

- [ ] **Step 1: 创建 Package.swift 与占位入口**

`Package.swift`：

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "HideNotch",
    platforms: [.macOS(.v26)],
    targets: [
        .target(name: "HideNotchCore"),
        .executableTarget(name: "HideNotch", dependencies: ["HideNotchCore"]),
        .testTarget(name: "HideNotchTests", dependencies: ["HideNotchCore"]),
    ]
)
```

`Sources/HideNotch/main.swift`：

```swift
import HideNotchCore
```

- [ ] **Step 2: 写失败测试**

`Tests/HideNotchTests/BarGeometryTests.swift`：

```swift
import CoreGraphics
import Testing
@testable import HideNotchCore

struct BarGeometryTests {
    // 实测值：1800x1169，菜单栏 39pt，刘海 38pt
    @Test func notchedScreenCoversMenuBar() {
        let m = ScreenMetrics(
            frame: CGRect(x: 0, y: 0, width: 1800, height: 1169),
            visibleFrame: CGRect(x: 0, y: 0, width: 1800, height: 1130),
            safeAreaTop: 38)
        #expect(BarGeometry.barRect(for: m) == CGRect(x: 0, y: 1130, width: 1800, height: 39))
    }

    @Test func screenWithoutNotchHasNoBar() {
        let m = ScreenMetrics(
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: 0, width: 1920, height: 1055),
            safeAreaTop: 0)
        #expect(BarGeometry.barRect(for: m) == nil)
    }

    @Test func autoHiddenMenuBarUsesNotchHeight() {
        let m = ScreenMetrics(
            frame: CGRect(x: 0, y: 0, width: 1800, height: 1169),
            visibleFrame: CGRect(x: 0, y: 0, width: 1800, height: 1169),
            safeAreaTop: 38)
        #expect(BarGeometry.barRect(for: m) == CGRect(x: 0, y: 1131, width: 1800, height: 38))
    }

    @Test func dockDoesNotAffectBar() {
        // Dock 在底部（原点上移）且在左侧（宽度变窄）
        let m = ScreenMetrics(
            frame: CGRect(x: 0, y: 0, width: 1800, height: 1169),
            visibleFrame: CGRect(x: 70, y: 80, width: 1730, height: 1050),
            safeAreaTop: 38)
        #expect(BarGeometry.barRect(for: m) == CGRect(x: 0, y: 1130, width: 1800, height: 39))
    }

    @Test func offsetScreenKeepsGlobalCoordinates() {
        let m = ScreenMetrics(
            frame: CGRect(x: 1920, y: -200, width: 1512, height: 982),
            visibleFrame: CGRect(x: 1920, y: -200, width: 1512, height: 945),
            safeAreaTop: 32)
        #expect(BarGeometry.barRect(for: m) == CGRect(x: 1920, y: 745, width: 1512, height: 37))
    }
}
```

- [ ] **Step 3: 运行，确认失败**

Run: `swift test --filter BarGeometryTests`
Expected: 编译失败，`cannot find 'ScreenMetrics' in scope`。

- [ ] **Step 4: 最小实现**

`Sources/HideNotchCore/BarGeometry.swift`：

```swift
import CoreGraphics

public struct ScreenMetrics: Equatable, Sendable {
    public var frame: CGRect
    public var visibleFrame: CGRect
    public var safeAreaTop: CGFloat

    public init(frame: CGRect, visibleFrame: CGRect, safeAreaTop: CGFloat) {
        self.frame = frame
        self.visibleFrame = visibleFrame
        self.safeAreaTop = safeAreaTop
    }
}

public enum BarGeometry {
    /// Rect covering the menu bar and notch, or nil for screens without a notch.
    /// Height takes the larger of menu bar and notch so an auto-hidden menu bar still blends.
    public static func barRect(for m: ScreenMetrics) -> CGRect? {
        guard m.safeAreaTop > 0 else { return nil }
        let height = max(m.frame.maxY - m.visibleFrame.maxY, m.safeAreaTop)
        return CGRect(x: m.frame.minX, y: m.frame.maxY - height, width: m.frame.width, height: height)
    }
}
```

- [ ] **Step 5: 运行，确认通过**

Run: `swift test --filter BarGeometryTests`
Expected: 5 tests passed。

- [ ] **Step 6: 提交**

```bash
git add Package.swift Sources Tests
git commit -m "feat: add package scaffold and bar geometry"
```

---

### Task 2: BarWindow

**Files:**
- Create: `Sources/HideNotchCore/BarWindow.swift`
- Test: `Tests/HideNotchTests/BarWindowTests.swift`

**Interfaces:**
- Consumes: 无
- Produces:
  - `@MainActor public protocol BarWindowHosting: AnyObject { var frame: CGRect { get }; func show(at rect: CGRect); func hide() }`
  - `public final class BarWindow: NSWindow, BarWindowHosting { public init(); static let barLevel: NSWindow.Level }`

- [ ] **Step 1: 写失败测试**

`Tests/HideNotchTests/BarWindowTests.swift`：

```swift
import AppKit
import Testing
@testable import HideNotchCore

@MainActor
struct BarWindowTests {
    @Test func keepsRequestedFrameOverMenuBar() {
        // 回归：AppKit 默认会把窗口挪到菜单栏下方，压住应用标题栏
        let window = BarWindow()
        let rect = NSRect(x: 0, y: 1130, width: 1800, height: 39)
        #expect(window.constrainFrameRect(rect, to: NSScreen.main) == rect)
    }

    @Test func sitsJustBelowMenuBarLevel() {
        #expect(BarWindow().level.rawValue == NSWindow.Level.mainMenu.rawValue - 1)
    }

    @Test func isOpaqueBlackAndClickThrough() {
        let window = BarWindow()
        #expect(window.backgroundColor == .black)
        #expect(window.isOpaque)
        #expect(!window.hasShadow)
        #expect(window.ignoresMouseEvents)
        #expect(!window.isReleasedWhenClosed)
    }

    @Test func joinsAllSpacesButNotFullScreen() {
        let behavior = BarWindow().collectionBehavior
        #expect(behavior.contains(.canJoinAllSpaces))
        #expect(behavior.contains(.stationary))
        #expect(behavior.contains(.ignoresCycle))
        #expect(!behavior.contains(.fullScreenAuxiliary))
    }

    @Test func showMovesAndHideOrdersOut() {
        let window = BarWindow()
        let rect = CGRect(x: 0, y: 1130, width: 1800, height: 39)
        window.show(at: rect)
        #expect(window.frame == rect)
        #expect(window.isVisible)
        window.hide()
        #expect(!window.isVisible)
    }
}
```

- [ ] **Step 2: 运行，确认失败**

Run: `swift test --filter BarWindowTests`
Expected: 编译失败，`cannot find 'BarWindow' in scope`。

- [ ] **Step 3: 实现**

`Sources/HideNotchCore/BarWindow.swift`：

```swift
import AppKit

@MainActor
public protocol BarWindowHosting: AnyObject {
    var frame: CGRect { get }
    func show(at rect: CGRect)
    func hide()
}

public final class BarWindow: NSWindow, BarWindowHosting {
    /// One below the system menu bar so menu titles and status items draw on top.
    public static let barLevel = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue - 1)

    public init() {
        super.init(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: true)
        backgroundColor = .black
        isOpaque = true
        hasShadow = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        level = Self.barLevel
        // No .fullScreenAuxiliary: the bar must not appear in full-screen spaces.
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
    }

    /// AppKit otherwise pushes the window below the menu bar, over app title bars.
    public override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }

    public func show(at rect: CGRect) {
        setFrame(rect, display: true)
        orderFrontRegardless()
    }

    public func hide() {
        orderOut(nil)
    }
}
```

- [ ] **Step 4: 运行，确认通过**

Run: `swift test --filter BarWindowTests`
Expected: 5 tests passed。若 `showMovesAndHideOrdersOut` 因测试进程无窗口服务连接而失败，记录实际报错并停下来汇报，不要删测试。

- [ ] **Step 5: 提交**

```bash
git add Sources/HideNotchCore/BarWindow.swift Tests/HideNotchTests/BarWindowTests.swift
git commit -m "feat: add click-through black bar window above menu bar region"
```

---

### Task 3: OverlayController

**Files:**
- Create: `Sources/HideNotchCore/OverlayController.swift`
- Create: `Tests/HideNotchTests/Fakes.swift`
- Test: `Tests/HideNotchTests/OverlayControllerTests.swift`

**Interfaces:**
- Consumes: `ScreenMetrics`、`BarGeometry.barRect(for:)`（Task 1）；`BarWindowHosting`（Task 2）
- Produces:
  - `@MainActor public protocol ScreenProviding { func currentScreens() -> [ScreenMetrics] }`
  - `public struct SystemScreens: ScreenProviding { public init() }`
  - `@MainActor public final class OverlayController { public init(screens: ScreenProviding, makeWindow: @escaping @MainActor () -> BarWindowHosting); public var isEnabled: Bool; public func refresh(); private(set) var windows: [BarWindowHosting] }`
  - 测试假对象（Tests 内）：`FakeScreens`、`FakeWindow`、`WindowFactory`

- [ ] **Step 1: 写假对象**

`Tests/HideNotchTests/Fakes.swift`：

```swift
import CoreGraphics
@testable import HideNotchCore

@MainActor
final class FakeScreens: ScreenProviding {
    var list: [ScreenMetrics] = []
    func currentScreens() -> [ScreenMetrics] { list }
}

@MainActor
final class FakeWindow: BarWindowHosting {
    var frame: CGRect = .zero
    var isShown = false
    func show(at rect: CGRect) { frame = rect; isShown = true }
    func hide() { isShown = false }
}

@MainActor
final class WindowFactory {
    var made: [FakeWindow] = []
    func make() -> BarWindowHosting {
        let window = FakeWindow()
        made.append(window)
        return window
    }
}

enum Screens {
    static let notched = ScreenMetrics(
        frame: CGRect(x: 0, y: 0, width: 1800, height: 1169),
        visibleFrame: CGRect(x: 0, y: 0, width: 1800, height: 1130),
        safeAreaTop: 38)
    static let external = ScreenMetrics(
        frame: CGRect(x: 1800, y: 0, width: 1920, height: 1080),
        visibleFrame: CGRect(x: 1800, y: 0, width: 1920, height: 1055),
        safeAreaTop: 0)
}
```

- [ ] **Step 2: 写失败测试**

`Tests/HideNotchTests/OverlayControllerTests.swift`：

```swift
import CoreGraphics
import Testing
@testable import HideNotchCore

@MainActor
struct OverlayControllerTests {
    let screens = FakeScreens()
    let factory = WindowFactory()

    func makeController() -> OverlayController {
        OverlayController(screens: screens, makeWindow: factory.make)
    }

    @Test func newControllerIsDisabled() {
        screens.list = [Screens.notched]
        let controller = makeController()
        #expect(!controller.isEnabled)
        #expect(factory.made.isEmpty)
    }

    @Test func enablingShowsBarOnNotchedScreenOnly() {
        screens.list = [Screens.notched, Screens.external]
        let controller = makeController()
        controller.isEnabled = true
        #expect(controller.windows.count == 1)
        #expect(factory.made.count == 1)
        #expect(factory.made[0].isShown)
        #expect(factory.made[0].frame == CGRect(x: 0, y: 1130, width: 1800, height: 39))
    }

    @Test func refreshWhileDisabledCreatesNothing() {
        screens.list = [Screens.notched]
        let controller = makeController()
        controller.refresh()
        #expect(factory.made.isEmpty)
    }

    @Test func refreshMovesExistingWindow() {
        screens.list = [Screens.notched]
        let controller = makeController()
        controller.isEnabled = true
        var resized = Screens.notched
        resized.frame = CGRect(x: 0, y: 0, width: 1512, height: 982)
        resized.visibleFrame = CGRect(x: 0, y: 0, width: 1512, height: 945)
        resized.safeAreaTop = 32
        screens.list = [resized]
        controller.refresh()
        #expect(factory.made.count == 1)
        #expect(factory.made[0].frame == CGRect(x: 0, y: 945, width: 1512, height: 37))
    }

    @Test func refreshRemovesWindowWhenScreenGone() {
        screens.list = [Screens.notched]
        let controller = makeController()
        controller.isEnabled = true
        screens.list = [Screens.external]
        controller.refresh()
        #expect(controller.windows.isEmpty)
        #expect(!factory.made[0].isShown)
    }

    @Test func disablingHidesAll() {
        screens.list = [Screens.notched]
        let controller = makeController()
        controller.isEnabled = true
        controller.isEnabled = false
        #expect(controller.windows.isEmpty)
        #expect(!factory.made[0].isShown)
    }

    @Test func repeatedRefreshIsIdempotent() {
        screens.list = [Screens.notched]
        let controller = makeController()
        controller.isEnabled = true
        for _ in 0..<5 { controller.refresh() }
        #expect(controller.windows.count == 1)
        #expect(factory.made.count == 1)
    }

    @Test func reEnableReusesSlots() {
        screens.list = [Screens.notched]
        let controller = makeController()
        for _ in 0..<3 {
            controller.isEnabled = true
            controller.isEnabled = false
        }
        controller.isEnabled = true
        #expect(controller.windows.count == 1)
        #expect(factory.made.filter(\.isShown).count == 1)
    }
}
```

- [ ] **Step 3: 运行，确认失败**

Run: `swift test --filter OverlayControllerTests`
Expected: 编译失败，`cannot find type 'ScreenProviding' in scope`。

- [ ] **Step 4: 实现**

`Sources/HideNotchCore/OverlayController.swift`：

```swift
import AppKit

@MainActor
public protocol ScreenProviding {
    func currentScreens() -> [ScreenMetrics]
}

public struct SystemScreens: ScreenProviding {
    public init() {}

    public func currentScreens() -> [ScreenMetrics] {
        NSScreen.screens.map {
            ScreenMetrics(frame: $0.frame, visibleFrame: $0.visibleFrame, safeAreaTop: $0.safeAreaInsets.top)
        }
    }
}

/// Keeps one bar window per notched screen in sync with the current screen layout.
@MainActor
public final class OverlayController {
    private let screens: ScreenProviding
    private let makeWindow: @MainActor () -> BarWindowHosting
    private(set) var windows: [BarWindowHosting] = []

    public var isEnabled = false {
        didSet { refresh() }
    }

    public init(screens: ScreenProviding, makeWindow: @escaping @MainActor () -> BarWindowHosting) {
        self.screens = screens
        self.makeWindow = makeWindow
    }

    public func refresh() {
        let rects = isEnabled ? screens.currentScreens().compactMap(BarGeometry.barRect(for:)) : []
        while windows.count > rects.count {
            windows.removeLast().hide()
        }
        while windows.count < rects.count {
            windows.append(makeWindow())
        }
        for (window, rect) in zip(windows, rects) {
            window.show(at: rect)
        }
    }
}
```

- [ ] **Step 5: 运行，确认通过**

Run: `swift test --filter OverlayControllerTests`
Expected: 8 tests passed。

- [ ] **Step 6: 提交**

```bash
git add Sources/HideNotchCore/OverlayController.swift Tests/HideNotchTests/Fakes.swift Tests/HideNotchTests/OverlayControllerTests.swift
git commit -m "feat: add overlay controller managing one bar per notched screen"
```

---

### Task 4: Preferences

**Files:**
- Create: `Sources/HideNotchCore/Preferences.swift`
- Test: `Tests/HideNotchTests/PreferencesTests.swift`

**Interfaces:**
- Consumes: 无
- Produces: `public final class Preferences { public init(defaults: UserDefaults = .standard); public var overlayEnabled: Bool }`

- [ ] **Step 1: 写失败测试**

`Tests/HideNotchTests/PreferencesTests.swift`：

```swift
import Foundation
import Testing
@testable import HideNotchCore

struct PreferencesTests {
    let suite = "HideNotchTests.\(UUID().uuidString)"

    func makeDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func overlayEnabledDefaultsToTrue() {
        #expect(Preferences(defaults: makeDefaults()).overlayEnabled)
    }

    @Test func overlayEnabledPersists() {
        let defaults = makeDefaults()
        Preferences(defaults: defaults).overlayEnabled = false
        #expect(!Preferences(defaults: defaults).overlayEnabled)
        defaults.removePersistentDomain(forName: suite)
    }
}
```

- [ ] **Step 2: 运行，确认失败**

Run: `swift test --filter PreferencesTests`
Expected: 编译失败，`cannot find 'Preferences' in scope`。

- [ ] **Step 3: 实现**

`Sources/HideNotchCore/Preferences.swift`：

```swift
import Foundation

public final class Preferences {
    static let overlayEnabledKey = "overlayEnabled"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [Self.overlayEnabledKey: true])
    }

    public var overlayEnabled: Bool {
        get { defaults.bool(forKey: Self.overlayEnabledKey) }
        set { defaults.set(newValue, forKey: Self.overlayEnabledKey) }
    }
}
```

- [ ] **Step 4: 运行，确认通过**

Run: `swift test --filter PreferencesTests`
Expected: 2 tests passed。

- [ ] **Step 5: 提交**

```bash
git add Sources/HideNotchCore/Preferences.swift Tests/HideNotchTests/PreferencesTests.swift
git commit -m "feat: add preferences with overlay enabled by default"
```

---

### Task 5: 开机自启 + 菜单栏图标

**Files:**
- Create: `Sources/HideNotchCore/LoginItem.swift`
- Create: `Sources/HideNotchCore/StatusItemController.swift`
- Modify: `Tests/HideNotchTests/Fakes.swift`（追加 `FakeLoginItem`）
- Test: `Tests/HideNotchTests/StatusItemControllerTests.swift`

**Interfaces:**
- Consumes: `Preferences`（Task 4）；`OverlayController`、`FakeScreens`、`WindowFactory`、`Screens`（Task 3）
- Produces:
  - `@MainActor public protocol LoginItemControlling: AnyObject { var isEnabled: Bool { get }; func setEnabled(_ on: Bool) throws }`
  - `public final class SystemLoginItem: LoginItemControlling { public init() }`
  - `@MainActor public final class StatusItemController: NSObject, NSMenuDelegate { public init(preferences:overlay:loginItem:); public func install(); func toggleOverlay(); func toggleLoginItem(); let overlayItem: NSMenuItem; let loginMenuItem: NSMenuItem; let menu: NSMenu }`

- [ ] **Step 1: 追加假登录项**

在 `Tests/HideNotchTests/Fakes.swift` 末尾追加：

```swift
struct LoginItemError: Error {}

@MainActor
final class FakeLoginItem: LoginItemControlling {
    var isEnabled = false
    var shouldFail = false
    func setEnabled(_ on: Bool) throws {
        if shouldFail { throw LoginItemError() }
        isEnabled = on
    }
}
```

- [ ] **Step 2: 写失败测试**

`Tests/HideNotchTests/StatusItemControllerTests.swift`：

```swift
import AppKit
import Testing
@testable import HideNotchCore

@MainActor
struct StatusItemControllerTests {
    let suite = "HideNotchTests.\(UUID().uuidString)"
    let screens = FakeScreens()
    let factory = WindowFactory()
    let login = FakeLoginItem()

    func makeSUT(overlayEnabled: Bool = true) -> (StatusItemController, Preferences, OverlayController) {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let prefs = Preferences(defaults: defaults)
        prefs.overlayEnabled = overlayEnabled
        screens.list = [Screens.notched]
        let overlay = OverlayController(screens: screens, makeWindow: factory.make)
        overlay.isEnabled = prefs.overlayEnabled
        let sut = StatusItemController(preferences: prefs, overlay: overlay, loginItem: login)
        return (sut, prefs, overlay)
    }

    @Test func menuHasToggleLoginAndQuit() {
        let (sut, _, _) = makeSUT()
        #expect(sut.menu.items.map(\.title) == ["黑色菜单栏", "开机自启", "", "退出"])
        #expect(sut.menu.items[2].isSeparatorItem)
    }

    @Test func menuReflectsDisabledPreference() {
        let (sut, _, overlay) = makeSUT(overlayEnabled: false)
        #expect(sut.overlayItem.state == .off)
        #expect(overlay.windows.isEmpty)
    }

    @Test func toggleOverlayUpdatesPreferenceOverlayAndMenu() {
        let (sut, prefs, overlay) = makeSUT()
        #expect(sut.overlayItem.state == .on)
        sut.toggleOverlay()
        #expect(!prefs.overlayEnabled)
        #expect(!overlay.isEnabled)
        #expect(overlay.windows.isEmpty)
        #expect(sut.overlayItem.state == .off)
    }

    @Test func toggleLoginItemEnables() {
        let (sut, _, _) = makeSUT()
        sut.toggleLoginItem()
        #expect(login.isEnabled)
        #expect(sut.loginMenuItem.state == .on)
        #expect(sut.loginMenuItem.title == "开机自启")
    }

    @Test func loginItemFailureIsShown() {
        let (sut, _, _) = makeSUT()
        login.shouldFail = true
        sut.toggleLoginItem()
        #expect(!login.isEnabled)
        #expect(sut.loginMenuItem.state == .off)
        #expect(sut.loginMenuItem.title == "开机自启（失败）")
    }

    @Test func loginItemSuccessClearsFailure() {
        let (sut, _, _) = makeSUT()
        login.shouldFail = true
        sut.toggleLoginItem()
        login.shouldFail = false
        sut.toggleLoginItem()
        #expect(sut.loginMenuItem.title == "开机自启")
        #expect(sut.loginMenuItem.state == .on)
    }

    @Test func menuWillOpenResyncsExternalChanges() {
        let (sut, _, _) = makeSUT()
        login.isEnabled = true  // 用户在系统设置里改了登录项
        sut.menuWillOpen(sut.menu)
        #expect(sut.loginMenuItem.state == .on)
    }
}
```

- [ ] **Step 3: 运行，确认失败**

Run: `swift test --filter StatusItemControllerTests`
Expected: 编译失败，`cannot find type 'LoginItemControlling' in scope`。

- [ ] **Step 4: 实现登录项**

`Sources/HideNotchCore/LoginItem.swift`：

```swift
import ServiceManagement

@MainActor
public protocol LoginItemControlling: AnyObject {
    var isEnabled: Bool { get }
    func setEnabled(_ on: Bool) throws
}

/// Registers the running app bundle as a login item; the system is the source of truth.
public final class SystemLoginItem: LoginItemControlling {
    public init() {}

    public var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    public func setEnabled(_ on: Bool) throws {
        if on {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
```

- [ ] **Step 5: 实现菜单栏图标**

`Sources/HideNotchCore/StatusItemController.swift`：

```swift
import AppKit
import os

@MainActor
public final class StatusItemController: NSObject, NSMenuDelegate {
    private static let log = Logger(subsystem: "com.leether.HideNotch", category: "StatusItem")
    private static let loginTitle = "开机自启"

    private let preferences: Preferences
    private let overlay: OverlayController
    private let loginItem: LoginItemControlling
    private var statusItem: NSStatusItem?
    private var loginItemFailed = false

    let menu = NSMenu()
    let overlayItem = NSMenuItem(title: "黑色菜单栏", action: #selector(toggleOverlay), keyEquivalent: "")
    let loginMenuItem = NSMenuItem(title: StatusItemController.loginTitle, action: #selector(toggleLoginItem), keyEquivalent: "")

    public init(preferences: Preferences, overlay: OverlayController, loginItem: LoginItemControlling) {
        self.preferences = preferences
        self.overlay = overlay
        self.loginItem = loginItem
        super.init()

        let quitItem = NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q")
        for item in [overlayItem, loginMenuItem, quitItem] {
            item.target = self
        }
        menu.addItem(overlayItem)
        menu.addItem(loginMenuItem)
        menu.addItem(.separator())
        menu.addItem(quitItem)
        menu.delegate = self
        syncMenuState()
    }

    public func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(
            systemSymbolName: "rectangle.topthird.inset.filled", accessibilityDescription: "HideNotch")
        item.menu = menu
        statusItem = item
    }

    public func menuWillOpen(_ menu: NSMenu) {
        syncMenuState()
    }

    @objc func toggleOverlay() {
        preferences.overlayEnabled.toggle()
        overlay.isEnabled = preferences.overlayEnabled
        syncMenuState()
    }

    @objc func toggleLoginItem() {
        do {
            try loginItem.setEnabled(!loginItem.isEnabled)
            loginItemFailed = false
        } catch {
            loginItemFailed = true
            Self.log.error("Login item update failed: \(error.localizedDescription, privacy: .public)")
        }
        syncMenuState()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func syncMenuState() {
        overlayItem.state = preferences.overlayEnabled ? .on : .off
        loginMenuItem.state = loginItem.isEnabled ? .on : .off
        loginMenuItem.title = loginItemFailed ? "\(Self.loginTitle)（失败）" : Self.loginTitle
    }
}
```

- [ ] **Step 6: 运行，确认通过**

Run: `swift test --filter StatusItemControllerTests`
Expected: 7 tests passed。

- [ ] **Step 7: 运行全部测试**

Run: `swift test`
Expected: 27 tests passed，0 failures。

- [ ] **Step 8: 提交**

```bash
git add Sources/HideNotchCore/LoginItem.swift Sources/HideNotchCore/StatusItemController.swift Tests/HideNotchTests
git commit -m "feat: add status item menu with overlay and login item toggles"
```

---

### Task 6: App 组装 + 打包脚本

**Files:**
- Create: `Sources/HideNotchCore/AppDelegate.swift`
- Modify: `Sources/HideNotch/main.swift`（替换 Task 1 占位）
- Create: `Resources/Info.plist`
- Create: `scripts/build-app.sh`

**Interfaces:**
- Consumes: `Preferences`、`OverlayController`、`SystemScreens`、`BarWindow`、`StatusItemController`、`SystemLoginItem`
- Produces: `@MainActor public final class AppDelegate: NSObject, NSApplicationDelegate { public override init() }`；`~/Applications/HideNotch.app`

本任务是系统集成胶水（通知订阅、`NSApplication` 启动），没有可隔离的单元逻辑；其行为由 Task 7 人工验收覆盖。

- [ ] **Step 1: 实现 AppDelegate**

`Sources/HideNotchCore/AppDelegate.swift`：

```swift
import AppKit

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private let preferences = Preferences()
    private let overlay = OverlayController(screens: SystemScreens(), makeWindow: { BarWindow() })
    private var statusController: StatusItemController?

    public override init() {
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        overlay.isEnabled = preferences.overlayEnabled

        let status = StatusItemController(preferences: preferences, overlay: overlay, loginItem: SystemLoginItem())
        status.install()
        statusController = status

        NotificationCenter.default.addObserver(
            self, selector: #selector(layoutChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(
            self, selector: #selector(layoutChanged),
            name: NSWorkspace.didWakeNotification, object: nil)
        workspace.addObserver(
            self, selector: #selector(layoutChanged),
            name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
    }

    @objc private func layoutChanged(_ notification: Notification) {
        overlay.refresh()
    }
}
```

- [ ] **Step 2: 替换入口**

`Sources/HideNotch/main.swift`：

```swift
import AppKit
import HideNotchCore

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
```

- [ ] **Step 3: 编译并跑全量测试**

Run: `swift build && swift test`
Expected: 编译无错误无 Swift 6 并发警告；27 tests passed。

- [ ] **Step 4: 写 Info.plist**

`Resources/Info.plist`：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>HideNotch</string>
    <key>CFBundleIdentifier</key>
    <string>com.leether.HideNotch</string>
    <key>CFBundleName</key>
    <string>HideNotch</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>26.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
```

- [ ] **Step 5: 写打包脚本**

`scripts/build-app.sh`（`chmod +x`）：

```bash
#!/usr/bin/env bash
# Build HideNotch.app (ad-hoc signed) and install it to ~/Applications.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP=".build/HideNotch.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/HideNotch "$APP/Contents/MacOS/HideNotch"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"

DEST="$HOME/Applications"
mkdir -p "$DEST"
rm -rf "$DEST/HideNotch.app"
cp -R "$APP" "$DEST/"
echo "Installed $DEST/HideNotch.app"
```

- [ ] **Step 6: 运行打包并校验签名**

Run: `scripts/build-app.sh && codesign --verify --verbose ~/Applications/HideNotch.app && plutil -lint ~/Applications/HideNotch.app/Contents/Info.plist`
Expected: 输出 `Installed .../HideNotch.app`、`valid on disk`、`OK`。

- [ ] **Step 7: 提交**

```bash
git add Sources Resources scripts
git commit -m "feat: wire app delegate and add app bundle build script"
```

---

### Task 7: 人工验收

**Files:**
- Create: `docs/acceptance/2026-09-27-hidenotch-v1.md`

**Interfaces:**
- Consumes: `~/Applications/HideNotch.app`（Task 6）
- Produces: 验收记录

终端无屏幕录制权限，无法截图；以下项由用户肉眼确认，执行者逐项询问并如实记录（通过 / 不通过 + 现象）。

- [ ] **Step 1: 启动 app**

Run: `open ~/Applications/HideNotch.app && sleep 2 && pgrep -lx HideNotch`
Expected: 输出 HideNotch 进程；菜单栏出现图标。

- [ ] **Step 2: 与用户逐项确认验收清单**

1. 刘海与菜单栏融为纯黑
2. 菜单项可点击
3. 窗口标题栏未被遮挡
4. 全屏应用中不显示黑条
5. 切换桌面空间、打开调度中心后正常
6. 睡眠唤醒后正常
7. 系统设置中更改分辨率后位置正确
8. 菜单开关黑条生效，退出并重新打开 app 后保持
9. 开机自启：勾选后注销重新登录，app 自动运行（失败时菜单显示「开机自启（失败）」，记录现象）
10. 换一张亮色壁纸，菜单栏文字仍可读

- [ ] **Step 3: 写验收记录并提交**

把每项结果写入 `docs/acceptance/2026-09-27-hidenotch-v1.md`（表格：编号 / 项目 / 结果 / 备注）。任何不通过项按 systematic-debugging 流程处理，不在本任务里打补丁。

```bash
git add docs/acceptance/2026-09-27-hidenotch-v1.md
git commit -m "docs: record v1 manual acceptance results"
```
