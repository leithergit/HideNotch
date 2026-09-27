# DEVLOG

## 2026-09-27 — HideNotch v1 / v1.1

**会话摘要**：从零实现 macOS 27 刘海隐藏工具 HideNotch：在带刘海屏幕的菜单栏下方铺一层纯黑窗口，使刘海与菜单栏融为一体（TopNotch 闭源且在 macOS 27 失效，改用窗口方案，不改壁纸）。

**本次完成**
- Spike 验证窗口方案可行；发现并解决 AppKit `constrainFrameRect` 把窗口挤到菜单栏下方的问题
- 设计 `docs/designs/hidenotch.md`、计划 `docs/plans/2026-09-27-hidenotch-v1.md`
- 子代理驱动实现 v1（6 个任务，逐任务审查 + 整体终审 + 修复波）：黑条、多屏/唤醒/空间切换刷新、偏好、开机自启（含需批准状态提示）、Cmd-Opt-H 防隐藏
- v1.1：菜单改名「隐藏刘海」+ 开启前确认弹窗；代码绘制的菜单栏 / app 图标（IconGen 生成 AppIcon.icns）
- 人工验收 14 项：13 通过、1 不适用（`docs/acceptance/2026-09-27-hidenotch-v1.md`）
- 锁屏界面 Spike：应用窗口在 macOS 27 锁屏上不可见（任何层级）→ 用户接受限制，写入设计 §6.1
- 测试：36 个（Swift Testing），零警告

**未完成 / 阻塞**
- 无阻塞。已知限制见设计 §6.1（锁屏、FileVault 启动登录界面、注销登录窗口）
- 延后的小项（均非必须）：`askToEnable` 可改 internal + `@usableFromInline`；`NotchIconTests` 有未用变量；设计 §7 测试清单与计划中历史代码片段仍为旧 `isEnabled` API

**下次起点建议**
- 构建安装：`scripts/build-app.sh`（ad-hoc 签名，装到 `~/Applications/HideNotch.app`）
- 跑测试：`swift test`

**当前状态**
- 分支：`feature/hidenotch-v1`（仓库尚无 main），收尾方式见本次会话结论
- 已安装并开机自启：`~/Applications/HideNotch.app`
- 未跟踪文件 `resumeclaud.sh` 非本项目产出，未提交
- 无环境变量改动
