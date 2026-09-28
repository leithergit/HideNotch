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
- `Package.swift`：`defaultLocalization: "en"`；`HideNotchCore` target 含 `resources: [.process("Resources")]`，构建产出 `HideNotch_HideNotchCore.bundle`（`Bundle.module`）。
- Targets：
  - `HideNotchCore`（library）：全部逻辑，可测试；`Resources/<lang>.lproj/Localizable.strings` 提供 13 语言本地化文案（见 §4.7）。
  - `HideNotch`（executable）：`main.swift` 薄入口，仅创建 `NSApplication` 与 `AppDelegate`。
  - `IconGen`（executable）：`main.swift` 用法 `IconGen <output.iconset dir>`，依赖 `HideNotchCore`，调用 `NotchIcon.appIconPNG(pixels:)` 写出标准 10 个 `.iconset` 文件（16/32/32/64/128/256/256/512/512/1024）；参数错误或写入失败时非零退出并打印原因。
  - `HideNotchTests`：Swift Testing 单元测试。
- `scripts/assemble-app.sh <sign-identity>`：`swift build -c release` → 用 `IconGen` 生成 `.build/AppIcon.iconset` → `iconutil -c icns` 产出 `Contents/Resources/AppIcon.icns` → 复制 `.build/release/HideNotch_HideNotchCore.bundle` 到 `Contents/Resources/`（缺失则报错退出，因为 `Bundle.module` 找不到资源包会 `fatalError`）→ 组装 `.build/HideNotch.app`（`Info.plist` 含 `LSUIElement=YES`、`CFBundleIdentifier=com.leether.HideNotch`、`CFBundleIconFile=AppIcon`、`CFBundleLocalizations`、`CFBundleDevelopmentRegion=en`）→ 按传入身份 `codesign`（`-` 为 ad-hoc；否则 `--options runtime --timestamp` 签名）→ `codesign --verify --strict` 校验。
- `scripts/build-app.sh`：调用 `scripts/assemble-app.sh -`（ad-hoc 签名）→ 复制到 `~/Applications`，供本机日常调试使用。
- `scripts/build-dmg.sh`：调用 `scripts/assemble-app.sh` 并传入 Developer ID 签名身份 → 组装 `dist/HideNotch-<version>.dmg`（内含 `Applications` 软链接）→ 对 DMG 签名 → `xcrun notarytool submit --wait` 提交 Apple 公证 → 通过后 `xcrun stapler staple` 装订 → `spctl --assess` 验证 Gatekeeper 放行。用于产出可分发的签名 + 公证 DMG。

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
- `canHide = false`：防止其他应用触发「隐藏其他」（Cmd-Opt-H）时把黑条一并隐藏。

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
  - `NSWorkspace.screensDidWakeNotification`
  - `NSWorkspace.activeSpaceDidChangeNotification`
- 唤醒后屏幕参数可能尚未稳定：收到通知时立即 `refresh()` 一次，并在 1 秒后（`Task { @MainActor in ... }`，`[weak self]`）再 `refresh()` 一次。

### 4.4 `Preferences`

- 包装 `UserDefaults`（可注入，测试用独立 suite）。
- `overlayEnabled: Bool`，默认 `true`。

### 4.5 `LoginItemService`

```swift
public enum LoginItemState: Equatable, Sendable { case enabled, disabled, requiresApproval }

@MainActor
public protocol LoginItemControlling: AnyObject {
    var state: LoginItemState { get }
    func setEnabled(_ on: Bool) throws
    func openSystemSettings()
}
```

- 生产实现基于 `SMAppService.mainApp`：`state` 映射 `status`（`.enabled` → `.enabled`；`.requiresApproval` → `.requiresApproval`；其余 → `.disabled`）；`setEnabled` 调用 `register()` / `unregister()`；`openSystemSettings()` 调用 `SMAppService.openSystemSettingsLoginItems()`。
- 状态以系统为准，不另存 UserDefaults。

### 4.6 `StatusItemController`

- `NSStatusItem`，图标使用 `NotchIcon.menuBarImage()`：代码绘制的自定义 glyph（屏幕轮廓 + 顶部实心条 + 从条中央向下凸出的刘海），18×18 pt 模板图（`isTemplate = true`，随浅色/深色菜单栏自动着色）。同一套 `NotchIcon`（`Sources/HideNotchCore/NotchIcon.swift`）也用于生成 App 图标（见 §3 `IconGen`），两者共享同一份 `GlyphLayout` 几何比例，不重复实现。
- 菜单文字全部来自 `L10n`（见 §4.7），随系统语言本地化；下列文案为 zh-Hans 取值，未做行为变更。
- 菜单：
  - 「隐藏刘海」（`L10n.hideNotch`，✓ 反映 `Preferences.overlayEnabled`）→ 切换并驱动 `OverlayController.isEnabled`。
    - 从关闭切到开启前，先弹出确认 `NSAlert`（`confirmEnable`，默认实现 `askToEnable()`）：`NSApplication.shared.activate()` 后展示，messageText `L10n.enableAlertTitle`「隐藏刘海」，informativeText `L10n.enableAlertMessage`「将把带刘海屏幕的菜单栏背景变成黑色，与刘海融为一体。」，按钮 `L10n.enableAlertConfirm`「开启」（默认）/`L10n.enableAlertCancel`「取消」。取消则不写入 preference、不创建窗口、菜单项保持 `.off`。
    - 关闭时不弹确认；App 启动（含首次启动、登录项启动）也不弹确认——`AppDelegate` 不受影响。
  - 「开机自启」（`L10n.launchAtLogin`，✓ 仅当 `LoginItemControlling.state == .enabled`）：
    - 点击时若当前 `state == .requiresApproval`，调用 `openSystemSettings()` 打开系统设置登录项页面，不调用 `setEnabled`。
    - 否则 `.enabled` → `setEnabled(false)`；`.disabled` → `setEnabled(true)`；抛错时记录 `os_log` 并置失败标记。
    - 标题优先级：失败标记 → `L10n.launchAtLoginFailed`「开机自启（失败）」；否则 `state == .requiresApproval` → `L10n.launchAtLoginNeedsApproval`「开机自启（需在系统设置中批准）」；否则 `L10n.launchAtLogin`「开机自启」。
  - 分隔线，「退出」（`L10n.quit`）。
- 菜单每次打开前（`menuWillOpen`）刷新勾选状态与标题。

### 4.7 `L10n`

- `Sources/HideNotchCore/L10n.swift`：`supportedLanguages`（13 个 lproj 目录名：`en`、`zh-Hans`、`zh-Hant`、`ja`、`ko`、`fr`、`de`、`es`、`it`、`pt`、`th`、`vi`、`id`）与 `keys`（`menu.hideNotch`、`menu.launchAtLogin`、`menu.launchAtLogin.failed`、`menu.launchAtLogin.needsApproval`、`menu.quit`、`alert.enable.title`、`alert.enable.message`、`alert.enable.confirm`、`alert.enable.cancel`）。
- 每个 key 对应一个静态计算属性（如 `L10n.hideNotch`），内部调用 `tr(_:bundle:)` → `bundle.localizedString(forKey:value:table:)`，`bundle` 默认 `Bundle.module`（SwiftPM 生成，随 `HideNotchCore` target 的 `resources: [.process("Resources")]` 打包为 `HideNotch_HideNotchCore.bundle`）。
- 文案来自 `Resources/<lang>.lproj/Localizable.strings`；`Package.swift` 声明 `defaultLocalization: "en"` 作为开发语言与系统找不到匹配语言时的回退。
- `StatusItemController` 与 `askToEnable()` 的全部菜单 / 弹窗文案均通过 `L10n` 取得，无硬编码文案。

## 5. 数据流

```
启动 → Preferences 读取 → OverlayController.isEnabled = pref → refresh()
                        → StatusItemController 挂载
屏幕参数变化 / 唤醒 / 切换空间 → OverlayController.refresh()
菜单切换「隐藏刘海」（开启前需确认）→ Preferences 写入 → OverlayController.isEnabled
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
| ad-hoc 签名下 `SMAppService` | 可能需要在系统设置中批准；失败时菜单显式提示，不静默。注册成功但 `status == .requiresApproval` 时，菜单显示「开机自启（需在系统设置中批准）」（勾选为关），再次点击打开系统设置登录项页面，而非重复调用 `register()` |

### 6.1 已知限制（用户已接受，2026-09-27）

| 场景 | 结论 | 依据 |
|---|---|---|
| 锁屏 / 睡眠唤醒后的解锁界面 | 无法处理，刘海可见 | Spike：黑条窗口层级设为 `CGShieldingWindowLevel() + 1` 及 `CGWindowLevelForKey(.maximumWindow) - 1`，并设置 `canBecomeVisibleWithoutLogin = true`；锁屏期间 AppKit 仍报告窗口可见，但 macOS 27 锁屏界面不合成会话内的应用窗口，用户实测均不可见 |
| 重启后首个登录界面（FileVault 开启） | 无法处理 | 该界面为 FileVault 启动前解锁环境，第三方代码不可运行 |
| 注销 / 切换用户的登录窗口 | 未实现 | 需安装 `/Library/LaunchAgents` 登录前代理（管理员权限），v1 不做 |
| 不显示刘海的分辨率 | 不处理（符合目标） | `safeAreaInsets.top == 0`，无刘海可隐藏 |

唯一可能覆盖锁屏的方案是改写壁纸（在壁纸图片顶部画黑带，TopNotch 的思路），未采用：会与壁纸轮换工具（本机 OnlySwitch 按文件夹轮换）互相覆盖，不支持动态 / 航拍壁纸，需要负责还原用户壁纸，且 TopNotch 在 macOS 27 上已失效。

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
