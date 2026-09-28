# HideNotch

把带刘海屏幕的菜单栏区域涂成纯黑，让刘海与菜单栏融为一体的 macOS 菜单栏小工具。

## 系统要求

- macOS 26 及以上
- 带刘海内屏的 MacBook（外接无刘海显示器不受影响）

## 安装

1. 打开下载的 `HideNotch-<版本号>.dmg`。
2. 把 `HideNotch.app` 拖到窗口里的 `Applications` 图标上完成安装。
3. 首次启动：从 `~/Applications` 或「应用程序」文件夹双击打开 `HideNotch.app`。App 无 Dock 图标，运行后仅在菜单栏显示图标。

## 使用

点击菜单栏图标，可看到以下菜单项：

- **隐藏刘海**：开关黑条覆盖。勾选状态反映当前是否生效。从关闭切换到开启时会先弹出确认提示；关闭、以及 App 启动（含开机自启）时不会弹确认。
- **开机自启**：勾选后登录时自动启动 App。若系统要求在「系统设置」中批准登录项，菜单会提示「开机自启（需在系统设置中批准）」，再次点击会打开系统设置对应页面。
- **退出**：退出 App。

## 已知限制

- **锁屏 / 睡眠唤醒后的解锁界面**：无法处理，刘海会短暂可见——锁屏界面不会合成当前用户会话内的应用窗口。
- **重启后首个登录界面（开启 FileVault 时）**：无法处理，该界面处于 FileVault 解锁前的启动环境，第三方代码无法运行。
- **注销 / 切换用户的登录窗口**：v1 未实现（需要安装需要管理员权限的登录前代理）。
- **不显示刘海的分辨率 / 外接显示器**：不处理，符合设计目标（无刘海无需隐藏）。

## 从源码构建

```bash
swift test              # 运行单元测试
scripts/build-app.sh    # ad-hoc 签名构建，安装到 ~/Applications，供本机调试
scripts/build-dmg.sh    # 生成签名 + 公证的可分发 DMG（dist/HideNotch-<版本号>.dmg）
```

`scripts/build-dmg.sh` 需要以下环境变量（均有默认值，通常无需设置）：

- `HIDENOTCH_SIGN_IDENTITY`：Developer ID Application 签名身份，默认 `Developer ID Application: XIONGGAO LI (Z8NL57N2AP)`。
- `HIDENOTCH_NOTARY_PROFILE`：`xcrun notarytool` 使用的 keychain profile 名称，默认 `HideNotch`。

首次在一台机器上使用前，需要用你自己的 Apple ID 和 App 专用密码一次性写入 keychain profile（**不要**把 Apple ID / 密码写进脚本或代码库）：

```bash
xcrun notarytool store-credentials HideNotch \
  --apple-id <your-apple-id> \
  --team-id <your-team-id> \
  --password <app-specific-password>
```

之后 `scripts/build-dmg.sh` 会通过该 keychain profile 静默完成签名与公证，无需再次输入凭据。
