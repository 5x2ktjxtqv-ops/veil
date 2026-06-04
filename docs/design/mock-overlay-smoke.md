# Mock Overlay Visual Smoke

VEL-011 验证目标：用完全静态 mock 数据启动真实桌面 overlay，观察 HUD 放在刘海/顶栏附近时是否安静、可读、不突兀。

设计修正：刘海区域本身不是屏幕，不能承载内容。整条状态栏黑化会让屏幕顶部像被加厚一块边框，视觉效果一般。当前方向改为悬浮胶囊：胶囊居中覆盖刘海区域，上下贴合刘海高度，左右两侧对称超出到可显示区域并承载状态信息。

VEL-012 冻结结论：Phase 1 默认视觉方案为 `notch capsule` / 刘海延展胶囊。整条黑色顶栏融合、顶部中心 compact HUD 和右侧辅助区状态项均降级为历史方案 / 非默认方案。

## 运行入口

Debug mock overlay 命令：

```sh
swift run Veil -- --mock-telemetry defaultCompact --no-mullvad-approval-prompt
```

`--mock-telemetry` 不带 fixture 时也会默认使用 `defaultCompact`。未知 fixture 会启动失败，避免拼写错误时误入真实 provider 路径。

可用 fixture 来自 VEL-009 `PreviewFixtures`：

- `defaultCompact`
- `fullExpanded`
- `cpuTemperatureUnavailable`
- `vpnOff`
- `approvalRequired`
- `memoryElevated`
- `memoryHigh`
- `latencyDegraded`
- `networkUnknown`

本 smoke 默认只启动 `defaultCompact` mock fixture；该 fixture 是静态数据，但 notch capsule 视图会按 VPN / MEM / CPU 三条 lane 做 `3s` 轮换。

当前 mock overlay 默认形态：

- fixture：`PreviewFixtures.defaultCompact`
- HUD 配置：`StatusHUDConfiguration.notchCapsule`
- 冻结参数：`screenCornerWidth: 4.5`、`screenCornerHeight: 5.5`、`screenCornerControl: 0.50`、`bottomCornerWidth: 14`、`bottomCornerHeight: 9`、`bottomCornerControl: 0.78`
- 历史通过 bounds：`(589, 0, 292, 32)`
- 当前 HUD 尺寸：运行时按刘海几何推导，宽度为 `notch width + 140` 与 `320px` 设计宽度中的较大值；高度为 `max(safeAreaInsets.top, 32)`。
- HUD 位置：优先使用带 `safeAreaInsets.top` 和左右 `auxiliaryTop*Area` 的刘海屏；水平居中覆盖刘海，顶部贴合屏幕顶部。
- 状态显示：默认健康态在 VPN / MEM / CPU 三条 lane 间轮换，分别显示 `FRA 23ms`、`18G 2.1G`、`18% OK`；不显示字段名。中间保留黑色覆盖区，不在物理刘海区域承载文字。
- HUD 背景：纯黑刘海延展形状；顶部先贴住屏幕边框，再在两侧肩部向内收，下沿使用更克制的外圆角。目标是颜色与刘海黑区像素级接近。
- 动态效果：启动时 `0.18s` ease-out 淡入。
- 静态 render：`docs/design/renders/notch-capsule.png`

## 历史烟测记录

状态：已运行。以下记录来自已废弃的顶部中心、右侧辅助区和整条状态栏黑化方案。

重要结论：旧 centered HUD 会撞上物理 camera housing，整条状态栏黑化又会显得屏幕顶部边框变厚；两者均已废弃。新方案采用覆盖刘海的悬浮胶囊，信息只放在左右可显示翼区。

计划运行命令：

```sh
swift run Veil -- --mock-telemetry defaultCompact --no-mullvad-approval-prompt
```

测试使用的 mock fixture：`PreviewFixtures.defaultCompact`

旧 HUD 尺寸：`188 x 24`

是否进入 `AppDelegate`：是。mock overlay 仍走 `applicationDidFinishLaunching`，初始化 legacy `TopFusionBarController` no-op shell，并创建 `OverlayHUDController`。

是否启动 telemetry/provider：否。`AppDelegate` 会先把 mock snapshot 写入 `StatusStore`，创建 overlay 后直接返回，不调用 `startLiveTelemetry()`，不创建刷新 timer。

是否触发 Mullvad / ping / network：否。mock overlay 路径不初始化 `TelemetryService`，因此不会初始化 `MullvadMonitor` 或 `NetworkThroughputSampler`，不会执行 `mullvad status`，不会执行 `/sbin/ping`，不会做 TCP timing 或主动网络探测。

窗口几何观察：

- 首次新方案运行发现 `NSScreen.main` 指向外接屏，HUD 误落在外接屏右上角，bounds 为 `(x: -200, y: 4, width: 188, height: 24)`；已停止该次运行并修正为优先选择带 `safeAreaInsets.top` 和 `auxiliaryTopRightArea` 的刘海屏。
- 修正后 HUD window：`188 x 24`，内建刘海屏右侧辅助区，bounds 为 `(x: 835, y: 4, width: 188, height: 24)`。
- 历史记录：早期 `TopFusionBarController` 曾创建内建刘海屏 top fusion strip，bounds 为 `(x: 0, y: 33, width: 1470, height: 33)`。
- 历史记录：早期 `TopFusionBarController` 曾在外接/副屏创建 top fusion strip，bounds 为 `(x: -2778, y: 14, width: 1389, height: 32)`。当前实现已改为 no-op shell，Phase 1 默认 mock smoke 只创建主 HUD overlay。
- 结束后确认屏幕上 `Veil` 窗口数量为 `0`。

构建验证：

- `swift build`：通过。
- `swift test`：通过，14 个测试通过。
- `swift build -c release`：通过。

## 历史视觉观察

旧顶部中心方案位置：不成立。HUD 位于主屏顶部中心，几何上看似靠近刘海/顶栏，但中心区域包含不可显示的 camera housing，不能作为信息承载区。

旧右侧辅助区方案位置：几何可用，但没有覆盖刘海本体，不能作为 VEL-012 默认方案。

宽度：`188 x 24` 能承载状态图标、`RAM 18G`、`VPN FRA`。是否需要进一步压缩间距，需要以肉眼观察右侧菜单栏 extras 冲突为准。

颜色：以下判断仅适用于已废弃的整条状态栏黑化方案。HUD 自身透明，黑色来自状态栏融合层；该方向已降级为历史方案 / 非默认方案。

顶部状态条：默认健康态没有额外顶部状态条；状态表达由左侧状态图标承担。

旧右侧辅助区菜单栏遮挡：HUD 几何上贴近刘海右侧辅助区左缘，不靠近最右侧系统状态图标。该判断只保留为历史记录，不作为 VEL-012 默认胶囊依据。

系统状态层感：当时方向为“整条状态栏黑化隐藏刘海 + 右侧辅助状态项”，VEL-012 后不再作为默认视觉方向。

## 历史待验证项

以下待验证项已经由 2026-05-08 precise micro corner smoke 关闭；未经用户再次批准，不运行新的 notch capsule overlay。

待验证项：

- 用户肉眼结论：胶囊是否完全覆盖刘海区域，上下是否严丝合缝。
- 用户肉眼结论：胶囊左右两侧是否对称超出到显示区域。
- 用户肉眼结论：四角圆弧是否接近刘海下弧度。
- 用户肉眼结论：黑色是否与刘海区域像素级接近。
- 用户肉眼结论：状态图标是否足够安静，不像独立 App badge。
- 用户肉眼结论：左右翼区的 RAM/VPN 是否足够清晰。
- 异常 fixture：warning/critical 图标是否过强。

## 用户反馈后的调整

反馈：黑色条太靠下，未隐藏刘海；信息显示区域太靠右，未贴近刘海，也没有显示在黑色条内部。

调整：

- 黑色状态栏融合层从菜单栏下方层级提升到 `.statusBar` 层级，避免被系统放到菜单栏下面。
- HUD 层级提升到 `.statusBar + 1`，确保信息画在黑色状态栏上方。
- 右侧辅助区 inset 从 `10px` 收紧到 `2px`，让状态项更贴近刘海右边缘。
- 状态项内部 padding 和 spacing 收紧，减少信息离刘海的视觉距离。

复测记录：

- 用户批准后运行 `swift run Veil -- --mock-telemetry defaultCompact --no-mullvad-approval-prompt`，约 90 秒后结束。
- HUD window：`188 x 24`，bounds 为 `(x: 827, y: 4, width: 188, height: 24)`，layer 为 `26`。
- 历史记录：早期内建屏黑色状态栏融合层 bounds 为 `(x: 0, y: 0, width: 1470, height: 32)`，layer 为 `25`。
- 历史记录：早期外接/副屏黑色融合层 bounds 为 `(x: -2778, y: 14, width: 1389, height: 30)`，layer 为 `25`。当前默认代码不再创建这些融合层。
- 结束后确认屏幕上 `Veil` 窗口数量为 `0`，且无 `Veil` 进程。
- `swift test`：通过，14 个测试通过。
- `swift build -c release`：通过。

## 悬浮胶囊调整

反馈：整条黑色状态栏效果一般，会吃掉屏幕顶部一块，让屏幕边框变宽；胶囊悬浮风格更佳。

当前实现：

- 生产默认配置切换为 `StatusHUDConfiguration.notchCapsule`。
- 不再创建整条黑色状态栏融合层。
- overlay 窗口水平居中覆盖刘海，顶部贴合屏幕顶部。
- 历史 VEL-020 宽度由左右辅助区推导的刘海宽度加左右各 `120px` 可视外展组成，且不小于 `420px` 设计宽度；该旧实现的左/右内容边距为 `48px`，已在后续 rotating pair 方向中收紧。
- 窗口高度为 `max(safeAreaInsets.top, 32)`，用于覆盖刘海高度。
- 左翼显示 RAM；右翼显示 VPN；中间黑色覆盖区不显示文字。
- 默认态进一步克制为左翼仅显示 RAM 数值、右翼仅显示 VPN 位置；正常态不显示状态点，不显示 `RAM` / `VPN` 标签。
- 异常态才显示更明确的 `MEM HIGH`、`VPN OFF`、warning/critical 颜色或状态图标。
- 胶囊背景为纯黑，四角连续圆角半径 `12px`，启动时 `0.18s` ease-out 淡入。
- 静态 render 已导出到 `docs/design/renders/notch-capsule.png`。
- `swift build`：通过。
- `swift test`：通过，14 个测试通过。
- `swift build -c release`：通过。

## 顶部外弧修正

反馈：上边左右角的圆弧方向做反了，普通圆角会往内收；目标是像刘海上角一样往外自然延展。

调整：

- 不再使用 `UnevenRoundedRectangle` 的顶部圆角。
- 新增自定义 `NotchIslandShape`：顶部整条黑色贴屏幕边框，不切掉上角黑色像素；只在下沿做圆弧。
- 下沿圆角保持 `18px`，用于维持“刘海向下延展”的柔和感。
- 静态 render、`swift build`、`swift test`、`swift build -c release` 均已通过。

复测反馈：方向对了，但顶部角完全是直角，下角弧度太大。

调整：

- 自定义 shape 顶部加入 `4px` shoulder radius，避免完全直角。
- 下沿圆角从 `18px` 收敛到 `12px`，降低夸张感。
- 静态 render、`swift build`、`swift test`、`swift build -c release` 均已通过。

## MacBook Air 参考形状复测

反馈：参考真实 MacBook Air 刘海，顶部和底部圆角方向不同。顶部应该像刘海区域左右自然伸出，不能做成顶部被咬掉的内弧；下沿也不能夸张成大胶囊。

调整：

- `NotchIslandShape` 改为顶部完整贴边：顶部先保持黑色贴住屏幕边框。
- 两侧肩部使用 `7px` 半径向内收，模拟真实刘海上肩部的过渡。
- 下沿外圆角收敛到 `6px`，避免过强的 pill / 后视镜感。
- 静态 render 已导出到 `docs/design/renders/notch-capsule.png`。

复测记录：

- 运行命令：`swift run Veil -- --mock-telemetry defaultCompact --no-mullvad-approval-prompt`。
- 测试 fixture：`PreviewFixtures.defaultCompact`。
- 是否进入 `AppDelegate`：是。mock snapshot 写入 `StatusStore` 后创建 overlay。
- 是否启动 telemetry/provider：否。mock 路径在创建 overlay 后直接返回，不调用 `startLiveTelemetry()`，不创建刷新 timer。
- 是否触发 Mullvad / ping / network：否。没有初始化 `TelemetryService` 的真实采样路径，不执行 Mullvad CLI，不执行 ping，不做 TCP timing 或主动网络探测。
- HUD 尺寸：`StatusHUDConfiguration.notchCapsule` 设计尺寸为 `292 x 32`；本次 `CGWindowList` 报告窗口 bounds 为 `(x: 603, y: 47, width: 264, height: 30)`。
- 烟测时长：约 90 秒，随后手动发送 `Ctrl-C` 结束。
- 结束确认：屏幕上 `Veil` 窗口数量为 `0`，且无 `Veil` 进程。
- 验证：`swift build` 通过；`swift test` 通过，14 个测试通过；`swift build -c release` 通过。
- 肉眼观察：本轮等待用户确认；代码侧只记录运行边界和窗口几何，不替代视觉判断。

复测反馈：形状变成两层，像台阶；真实参考图应该是一层连续轮廓。

调整：

- 移除 `topFlatHeight` / shoulder 平台，不再先画一层顶部黑帽子。
- `NotchIslandShape` 改为单层主体：完整黑色主体加顶部角透明 cutout。
- 顶部 cutout 半径为 `8px`，下沿外圆角保持克制的 `6px`。
- 静态 render 已导出到 `docs/design/renders/notch-capsule.png`。
- 尚未再次运行 overlay 烟测；需要用户再次明确批准。
- 验证：`swift build` 通过；`swift test` 通过，14 个测试通过；`swift build -c release` 通过。

复测反馈：单层 cutout 方向仍不对，用户观察像上下颠倒。

调整：

- 将上角方向翻回“顶部外展”：顶部为全宽黑色，向下用连续曲线收进到主体侧边。
- 保持单层轮廓，不再画水平台阶或第二层肩部。
- `NotchIslandShape` 使用 `topOutsetRadius: 8` 与 `bottomRadius: 6`。
- 静态 render 已导出到 `docs/design/renders/notch-capsule.png`。
- 尚未再次运行 overlay 烟测；需要用户再次明确批准。
- 验证：`swift build` 通过；`swift test` 通过，14 个测试通过；`swift build -c release` 通过。

复测反馈：整体上沿仍有台阶，顶部外展过厚，像多出一条帽檐。

调整：

- 不再翻转方向，保留顶部外展思路，但把外展半径从 `8px` 收敛到 `4px`。
- 下沿外圆角从 `6px` 微收为 `5px`，保持整体更克制。
- 静态 render 已导出到 `docs/design/renders/notch-capsule.png`。
- 尚未再次运行 overlay 烟测；需要用户再次明确批准。
- 验证：`swift build` 通过；`swift test` 通过，14 个测试通过；`swift build -c release` 通过。

复测反馈：还有一点点小沿，没有完全对齐屏幕边框。

调整：

- 保持 `topOutsetRadius: 4`，但把上角外弧整体画到可见 view 上方。
- 可见区域不再绘制顶部全宽帽檐；顶部 alpha 从主体边界开始，目标是让外弧被屏幕边框裁掉。
- 静态 render 已导出到 `docs/design/renders/notch-capsule.png`。
- 尚未再次运行 overlay 烟测；需要用户再次明确批准。
- 验证：`swift build` 通过；`swift test` 通过，14 个测试通过；`swift build -c release` 通过。

复测反馈：这一版已经非常接近，只需要四个角弧度再大一点。

调整：

- 顶部外弧半径从 `4px` 增加到 `6px`。
- 下沿外圆角从 `5px` 增加到 `7px`。
- 继续把顶部外弧画在可见区域上方，避免重新出现小沿/帽檐。
- 静态 render 已导出到 `docs/design/renders/notch-capsule.png`。
- 尚未再次运行 overlay 烟测；需要用户再次明确批准。
- 验证：`swift build` 通过；`swift test` 通过，14 个测试通过；`swift build -c release` 通过。

复测反馈：基本可以；唯一问题是上边两个角弧度再大一点，当前略直角。

调整：

- 只调上角：顶部外弧半径从 `6px` 增加到 `8px`。
- 下沿外圆角保持 `7px`，避免底部重新变夸张。
- 继续把顶部外弧画在可见区域上方，避免重新出现小沿/帽檐。
- 静态 render 已导出到 `docs/design/renders/notch-capsule.png`。
- 尚未再次运行 overlay 烟测；需要用户再次明确批准。
- 验证：`swift build` 通过；`swift test` 通过，14 个测试通过；`swift build -c release` 通过。

复测反馈：上角圆弧方向仍反，且出现更明显的顶部台阶；参考图应按黑色边框/刘海与白色屏幕的过渡判断。

调整：

- 移除 `topBandHeight`，不再绘制可见顶部平台。
- `NotchIslandShape` 改为 `screenCornerRadius: 9`、`bottomRadius: 7`。
- 顶边只保留贴屏幕边框的一条边，随后立即进入屏幕圆角切入黑色的曲线。
- 静态 render 已导出到 `docs/design/renders/notch-capsule.png`。
- 尚未再次运行 overlay 烟测；需要用户再次明确批准。
- 验证：`swift build` 通过；`swift test` 通过，14 个测试通过；`swift build -c release` 通过。

复测反馈：方向已经非常接近；原生刘海红圈处更接近直角，只需要一点点过渡弧，不能做成明显圆角。

调整：

- `NotchIslandStyle` 参数化 notch 轮廓，生产默认使用 `screenCornerWidth: 5`、`screenCornerHeight: 6`、`screenCornerControl: 0.54`、`bottomRadius: 7`。
- 该版本比上一版 `6 x 7` 少约 1px 圆角推进：顶部边缘更接近直角，但仍保留抗锯齿过渡。
- 静态 render 已导出到 `docs/design/renders/notch-capsule.png`。
- 对比候选图已导出到 `docs/design/renders/notch-capsule-candidates-precise-5x6.png`。
- 验证：`swift build` 通过；`swift test` 通过，14 个测试通过；`swift build -c release` 通过。

2026-05-08 mock overlay smoke：precise micro corner

- 运行命令：`swift run Veil -- --mock-telemetry defaultCompact --no-mullvad-approval-prompt`。
- 测试 fixture：`PreviewFixtures.defaultCompact`。
- HUD 配置：`StatusHUDConfiguration.notchCapsule`。
- HUD 尺寸：设计尺寸 `292 x 32`；本次 `CGWindowList` 报告窗口 bounds 为 `(x: 589, y: 0, width: 292, height: 32)`。
- 是否进入 AppDelegate：是，进入 `AppDelegate` 的 mock telemetry 分支并创建 overlay；未进入 live telemetry 启动路径。
- 是否启动 telemetry/provider：否，mock 分支写入静态 snapshot 后返回，不启动真实 provider。
- 是否触发 Mullvad / ping / network：否；不执行 Mullvad CLI，不做 ping、TCP timing 或任何网络探测。
- 结束确认：用户反馈“烟测通过”后发送 `Ctrl-C` 停止；屏幕上 `Veil` 窗口数量为 `0`，且无 `Veil` 进程。
- 肉眼观察：用户确认该版极其接近并通过 smoke；最终上角保持接近直角的微过渡弧，信息区域保持克制，未反馈遮挡菜单栏或突兀问题。

## VEL-012 视觉基线冻结

状态：已冻结。本文不再把整条黑色顶栏融合、右侧辅助区状态项或 240 compact HUD 作为 Phase 1 默认方向。

冻结项：

- 默认 HUD 配置：`StatusHUDConfiguration.notchCapsule`。
- 生产默认代码路径：`StatusHUDConfiguration.productionCompact = .notchCapsule`。
- 最终通过参数：`screenCornerWidth: 4.5`、`screenCornerHeight: 5.5`、`screenCornerControl: 0.50`、`bottomCornerWidth: 14`、`bottomCornerHeight: 9`、`bottomCornerControl: 0.78`。
- VEL-012 smoke bounds：`(589, 0, 292, 32)`；VEL-031 follow-up 后当前设计尺寸为 `320 x 32`。
- 默认信息策略：VPN / MEM / CPU rotating pair，`3s` 轮换，无字段名，中间覆盖刘海且不承载文字。
- Mock overlay smoke：已通过。
- 结束状态：屏幕上 `Veil` 窗口数量为 `0`，且无 `Veil` 残留进程。

## 2026-05-09 Notch Capsule Alignment Smoke

运行命令：

```sh
swift run Veil -- --mock-telemetry latencyDegraded --no-mullvad-approval-prompt
```

验证目标：

- 使用 `latencyDegraded` mock fixture 显示左侧 RAM 与右侧 location + latency，验证 VEL-020 后的 `420 x 32` 胶囊宽度和左右外侧等边距。
- 本次只运行 mock overlay，不启动 live telemetry，不执行 Mullvad CLI，不执行 ping，不做网络探测。

运行记录：

- 运行前 `pgrep -x Veil` 无输出。
- 运行前屏幕上 `Veil` 窗口数量为 `0`。
- 运行中 `CGWindowList` 观察到 1 个 `Veil` overlay window，bounds 为 `(x: 525, y: 0, width: 420, height: 32)`。
- 左内容左边距与右内容右边距保持一致；用户确认“这个距离已经最大了，可以确定”。
- 本次确认只冻结几何距离和对齐边界；最终展示内容仍待后续敲定。

结束确认：

- 使用 `Ctrl-C` 停止 `swift run Veil ...`。
- 结束后屏幕上 `Veil` 窗口数量为 `0`。
- 结束后 `pgrep -x Veil` 无输出。

VEL-012 文档冻结任务没有重新启动 Veil、没有运行 overlay、没有执行 Mullvad CLI、没有执行 ping / TCP timing / 网络探测。

## 2026-05-10 VEL-031 292 Rotating Pair Mock Overlay Smoke

验证目标：

- 使用 `defaultCompact` mock fixture 启动真实桌面 overlay，验证当前 notch capsule 视觉收口。
- 确认 overlay bounds 为 `292 x 32`。
- 确认 mock overlay 路径不启动 live telemetry，不执行 Mullvad CLI，不执行 ping、TCP timing 或网络探测，不读取真实 CPU 温度传感器。
- 通过 `StatusHUDView` 的 `TimelineView` 路径和 mapping tests 交叉确认 VPN / MEM / CPU 三 lane 按 `3s` 轮换且不显示字段名；本次不截图、不 OCR、不采集桌面画面。

运行命令：

```sh
swift run Veil -- --mock-telemetry defaultCompact --no-mullvad-approval-prompt
```

运行记录：

- 用户已明确批准本次 mock overlay smoke。
- 运行前 `pgrep -x Veil` 无输出。
- 运行前屏幕上 `Veil` 窗口数量为 `0`。
- build/run 启动后进入 `AppDelegate` mock telemetry 分支：`defaultCompact` snapshot 写入 `StatusStore`，创建 overlay 后不调用 `startLiveTelemetry()`。
- 运行中 06:56:43 CST：`CGWindowList` 观察到 1 个 `Veil` overlay window，bounds 为 `(x: 589, y: 0, width: 292, height: 32)`，layer `26`，alpha `1`。
- 运行中 06:56:57 CST：再次观察到 1 个 `Veil` overlay window，bounds 仍为 `(x: 589, y: 0, width: 292, height: 32)`，layer `26`，alpha `1`。
- 运行中 06:57:27 CST：第三次观察到 1 个 `Veil` overlay window，bounds 仍为 `(x: 589, y: 0, width: 292, height: 32)`，layer `26`，alpha `1`。
- 观察时长：约 `55s`，覆盖多个 `3s` lane 轮换周期。

内容契约确认：

- `PreviewFixtures.defaultCompact` 当前提供 VPN `FRA / 23ms`、MEM `18G / 2.1G`、CPU `18% / OK`。
- `StatusHUDMapping.notchCapsuleLaneRotationInterval = 3`，顺序为 VPN -> MEM -> CPU。
- `StatusHUDView` 在未指定 fixed lane 时使用 `TimelineView(.periodic(..., by: 3))` 驱动实际 overlay 内容。
- `NotchCapsuleHUDMappingTests` 断言三条 lane 的 label 为空、value 不包含字段名、`notchVoid` 为空。
- CPU lane 右侧来自 thermal pressure；unknown 时显示 `--`。摄氏温度 optional path 不作为 default notch lane 右值。

结束确认：

- 使用 `Ctrl-C` 停止 `swift run Veil ...`。
- 结束时间：06:57:38 CST。
- 结束后屏幕上 `Veil` 窗口数量为 `0`。
- 结束后 `pgrep -x Veil` 无输出。
- 本次没有启动 live telemetry，没有执行 Mullvad CLI，没有执行 ping / TCP timing / 公网 IP 查询 / Speedtest / 网络探测，没有读取真实 CPU 温度传感器，没有切换显示器，没有进入 fullscreen，没有做 sleep/wake。

验证：

- `swift build`：通过。
- `swift test`：通过，29 个 XCTest tests。
- `swift build -c release`：通过。

## 2026-05-10 VEL-031 320 Calculated Width Mock Overlay Smoke

验证目标：

- 使用 `defaultCompact` mock fixture 启动真实桌面 overlay，验证按展示需求计算后的 `320 x 32` notch capsule。
- 确认 overlay bounds 为 `320 x 32`。
- 确认 mock overlay 路径不启动 live telemetry，不执行 Mullvad CLI，不执行 ping、TCP timing 或网络探测，不读取真实 CPU 温度传感器。
- 验证布局模型：`180px` 刘海空区、`34px` 最小视觉边距、最大参考内容 `34px` 加 `2px` 安全余量，合成 `320px` 外框。

运行命令：

```sh
swift run Veil -- --mock-telemetry defaultCompact --no-mullvad-approval-prompt
```

运行记录：

- 用户已明确批准本次 mock overlay smoke。
- 运行前 `pgrep -x Veil` 无输出。
- 运行前屏幕上 `Veil` 窗口数量为 `0`。
- 运行中 07:44:42 CST：`CGWindowList` 观察到 1 个 `Veil` overlay window，bounds 为 `(x: 575, y: 0, width: 320, height: 32)`，layer `26`，alpha `1`。
- 运行中 07:45:05 CST：再次观察到 1 个 `Veil` overlay window，bounds 仍为 `(x: 575, y: 0, width: 320, height: 32)`，layer `26`，alpha `1`。
- 运行中 07:45:32 CST：第三次观察到 1 个 `Veil` overlay window，bounds 仍为 `(x: 575, y: 0, width: 320, height: 32)`，layer `26`，alpha `1`。
- 观察时长：约 `60s`，覆盖多个 `3s` lane 轮换周期。

结束确认：

- 使用 `Ctrl-C` 停止 `swift run Veil ...`。
- 结束时间：07:45:42 CST。
- 结束后屏幕上 `Veil` 窗口数量为 `0`。
- 结束后 `pgrep -x Veil` 无输出。
- 本次没有启动 live telemetry，没有执行 Mullvad CLI，没有执行 ping / TCP timing / 公网 IP 查询 / Speedtest / 网络探测，没有读取真实 CPU 温度传感器，没有切换显示器，没有进入 fullscreen，没有做 sleep/wake。

验证：

- `swift build`：通过。
- `swift test`：通过，30 个 XCTest tests。
- `swift build -c release`：通过。

## 2026-05-17 Bottom Corner Anti-Alias Mock Overlay Smoke

验证目标：

- 复核下沿两角从小圆角改为横向更长的 `18 x 12` 软曲线后，实机 overlay 不再出现明显硬台阶。
- 确认 mock overlay 路径不启动 live telemetry，不执行 Mullvad CLI，不执行 ping、TCP timing 或网络探测，不读取真实 CPU 温度传感器。

运行命令：

```sh
swift run Veil -- --mock-telemetry defaultCompact --no-mullvad-approval-prompt
```

运行记录：

- 运行前发现旧的 local `Veil.app` 正在显示 overlay，PID 为 `8364`；为避免 overlay coordinator 跳过源码 smoke，先停止该进程。
- 第一次源码 smoke 复现到 `320 x 33` overlay，截图放大确认旧小圆角边缘台阶明显。
- 移除 `drawingGroup` 后再次源码 smoke，边缘台阶仍可见，说明问题不只是离屏栅格化。
- 将下沿两角改为 `bottomCornerWidth: 18`、`bottomCornerHeight: 12`、`bottomCornerControl: 0.86`，并加一圈 `0.32` alpha 的 1px edge coverage 后重新 smoke。`18 x 12` 比上一版 `14 x 9` 更接近硬件刘海底部两角的大弧度，`0.86` 保持较软的直线过渡。
- 最终 smoke 运行中 `CGWindowList` 观察到 3 个 `Veil` window：一个 `(x: 575, y: 0, width: 320, height: 33)` HUD overlay，两个 `24 x 24` bottom corner mask windows；layer 均为 `26`，alpha 为 `1`。
- 截图裁剪保存到临时路径 `/tmp/veil-continuous-18x12-crop.png`，放大图保存到 `/tmp/veil-continuous-18x12-left-bottom-zoom.png`。正常尺寸下底角过渡比 `9pt` 小圆角更软；放大图仍能看到像素阶梯，但不再是之前紧凑 45 度小圆弧的硬台阶。

结束确认：

- 使用 `Ctrl-C` 停止 `swift run Veil ...`。
- 结束后 `pgrep -x Veil` 无输出。
- 本次没有启动 live telemetry，没有执行 Mullvad CLI，没有执行 ping / TCP timing / 公网 IP 查询 / Speedtest / 网络探测，没有读取真实 CPU 温度传感器，没有切换显示器，没有进入 fullscreen，没有做 sleep/wake。

验证：

- `swift test --filter StatusHUDConfigurationTests`：通过，5 个 XCTest tests。
- `swift test`：通过，125 个 XCTest tests。

## 2026-05-20 official image notch-corner refinement

复审反馈：在底部屏幕圆角已用 Apple 官方产品图拟合后，刘海延展胶囊的四个可见角也需要用同一思路收口，减少“通用胶囊”感。

处理记录：

- 新增 `Tools/fit-apple-notch-island.py`，用 Apple M4 MacBook Air support image 和本机运行时 `179pt` 刘海 gap 锁定官方图中的稳定黑色刘海主体。
- 拟合结果记录在 `docs/design/notch-island-apple-fit.md`；官方图中 `93px` 稳定黑色主体映射为 `179.17pt`，与本机 notch gap 对齐。
- 生产默认参数从 `5 / 6 / 0.54` 和 `18 / 12 / 0.86` 收到 `4.5 / 5.5 / 0.50` 和 `14 / 9 / 0.78`。
- 数据 lane、轮换、左右 indicator slot 和 `320 x 32` 设计宽度均未改变。
