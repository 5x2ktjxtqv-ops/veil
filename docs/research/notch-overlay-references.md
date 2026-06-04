# Notch / Top Bar Reference Research

状态：Draft  
日期：2026-05-06  
范围：TopNotch、Forehead、TheBoringNotch、Atoll  
原则：只提炼可借鉴点和风险，不复制代码，不直接照抄。

## 1. 研究结论摘要

Veil Phase 1 应采用原生 AppKit overlay 路线，而不是修改壁纸路线。

推荐路径：

- 顶栏融合：使用独立的黑色 click-through AppKit 窗口，覆盖每个屏幕的菜单栏背景区域，但不接管菜单栏内容。
- HUD overlay：使用 `NSPanel`/`NSWindow` 承载 SwiftUI HUD，定位在主屏幕或选定屏幕的顶部中心。
- 窗口层级：HUD 使用保守的系统级窗口层级，Phase 1 以稳定可见、不干扰点击为先；不要使用极高层级或私有 SkyLight 方案。
- click-through：Phase 1 默认完全 click-through，HUD 不接管鼠标事件。
- fullscreen、多显示器、click-through 完整打磨：归入 Phase 2 稳定性重点。
- notch 定位：优先使用 `safeAreaInsets`、`auxiliaryTopLeftArea`、`auxiliaryTopRightArea`、`visibleFrame` 推导；Phase 1 可先使用顶部中心近似定位。

不推荐路径：

- 不修改用户壁纸。
- 不复制 GPL 项目的源码。
- 不引入 TheBoringNotch / Atoll 的媒体中心、插件、通知、锁屏组件等复杂方向。
- 不使用 Electron、WebView 或重型依赖。
- 不依赖私有框架作为 Phase 1 基础能力。

## 2. 参考项目概览

| 项目 | 类型 | 对 Veil 的价值 | 对 Veil 的风险 |
| --- | --- | --- | --- |
| TopNotch | 黑色菜单栏/壁纸处理工具 | 证明“黑色顶栏融合”是有效视觉策略 | 修改壁纸，不适合承载实时 HUD |
| Forehead | 黑色菜单栏/圆角壁纸工具 | 证明黑顶栏和圆角能强化原生感 | 壁纸兼容、动态壁纸、恢复/卸载风险 |
| TheBoringNotch | 开源 Swift notch overlay | AppKit overlay、窗口层级、notch 几何、多屏经验 | GPL、功能过重、互动娱乐化、部分私有/复杂机制 |
| Atoll | 开源 Swift Dynamic Island | 多显示器、fullscreen、窗口承载和系统状态经验 | 更重的功能面、插件/扩展/权限复杂度、GPL |

## 3. TopNotch

资料来源：

- [TopNotch 官方网站](https://topnotch.app/)
- [Macworld: How to hide the notch](https://www.macworld.com/article/548163/macbook-pro-black-out-notch-apps-utilities.html)

定位：

TopNotch 是轻量 macOS 工具，核心目标是让菜单栏变黑，从视觉上隐藏刘海。官方说明包含动态壁纸、多显示器、Spaces、后台监听壁纸变化和圆角选项。

可借鉴点：

- 黑色菜单栏融合是有效且用户能理解的视觉策略。
- 背景运行、低存在感、低配置负担，符合 Veil 的克制方向。
- 多显示器和 Spaces 从第一天就是风险点，不能等到后期才发现。
- 圆角不是核心功能，但“顶栏黑化 + 壁纸圆角一致”会提升原生感。

风险：

- TopNotch 的主要路线是处理壁纸，不是实时 overlay。
- 动态壁纸、系统壁纸切换、外接显示器、系统更新都可能让壁纸方案变脆。
- 壁纸修改会带来恢复、同步、用户信任和调试问题。
- 它不能直接解决 HUD 的窗口层级、click-through、数据更新问题。

Veil 取舍：

- 借鉴“黑色顶栏融合”的视觉目标。
- 不借鉴“修改壁纸”的实现路线。
- 当前 Phase 1 使用 notch capsule HUD overlay 承载这个视觉目标，不再默认创建 AppKit 黑色顶栏融合窗口。

## 4. Forehead

资料来源：

- [Product Hunt: Forehead](https://www.producthunt.com/products/forehead?launch=forehead)
- [iThinkDifferent: Forehead app hides the notch](https://www.ithinkdiff.com/forehead-app-hide-notch-2021-macbook-pro/)
- [Macworld: Forehead section](https://www.macworld.com/article/548163/macbook-pro-black-out-notch-apps-utilities.html)

定位：

Forehead 同样是隐藏刘海的视觉工具，重点是让菜单栏变黑、给屏幕或壁纸增加圆角，并允许在默认壁纸和 notchless 版本之间切换。

可借鉴点：

- “不减少可用空间，只让菜单栏与黑色边框融合”是 Veil 应保留的视觉前提。
- 圆角和黑色顶栏共同塑造“像系统原生的一部分”的感受。
- 用户对这类工具的容忍度很低：一旦壁纸恢复、输入失效或无法关闭，就会严重破坏信任。

风险：

- 壁纸修改方式对动态壁纸、系统版本和用户壁纸来源敏感。
- 工具越接近“屏幕外观修改器”，越容易背离 Veil 的系统生命体征 HUD 定位。
- Forehead 的产品价值集中在外观处理，不能为 Veil 的实时状态层提供架构参考。

Veil 取舍：

- 借鉴黑色顶栏和圆角协调的产品感。
- 不做壁纸编辑、壁纸切换、全屏圆角工具。
- 不把 Veil 扩展成 notch 美化工具。

## 5. TheBoringNotch

资料来源：

- [TheBoringNotch GitHub](https://github.com/TheBoredTeam/boring.notch)
- 只读源码检索：`ff5e01a22deb2b3719a19712364f0d725a13e0de`

定位：

TheBoringNotch 是开源 Swift macOS notch overlay，将刘海区域变成互动式 Dynamic Island，包含音乐、日历、文件 shelf、系统 HUD 替代、hover 展开等能力。

可借鉴点：

- overlay 使用 AppKit 窗口承载 SwiftUI 内容，是 Veil 可采用的主路线。
- 使用 borderless / non-activating / HUD 风格窗口，有利于创建不像普通 App 的顶部 overlay。
- fullscreen 兼容通常依赖 `fullScreenAuxiliary`、`canJoinAllSpaces`、`stationary`、`ignoresCycle` 等 collection behavior 组合。
- notch 定位可以通过屏幕 frame 顶部中心计算，再结合 `safeAreaInsets.top` 判断是否为刘海屏。
- notch 宽度可以通过屏幕顶部左右辅助区域推导，避免纯硬编码。
- 多显示器必须有屏幕标识和窗口重建逻辑，不能只依赖 `NSScreen.main`。

风险：

- 项目是 GPL-3.0，Veil 不能复制其源码或结构性实现。
- 功能方向偏娱乐化 Dynamic Island，和 Veil 的低信息密度 HUD 哲学不同。
- 交互模型依赖 hover、拖拽、文件 shelf、媒体控制等，容易把 Veil 带向复杂面板。
- 窗口层级较激进，可能在某些场景遮挡系统 UI 或与菜单栏/全屏应用争夺层级。
- 项目包含锁屏、私有/半私有空间管理等复杂方案，Phase 1 不应采用。

Veil 取舍：

- 借鉴 AppKit overlay 的窗口承载思路。
- 借鉴 fullscreen collection behavior 的方向，但 Phase 1 只做保守组合。
- 借鉴 notch 几何推导思路；当前默认实现优先选择带刘海安全区的目标屏，并将 HUD 居中覆盖刘海。
- 不借鉴媒体中心、shelf、通知、扩展系统、锁屏窗口和复杂 hover 交互。

## 6. Atoll

资料来源：

- [Atoll GitHub](https://github.com/Ebullioscopic/Atoll)
- 只读源码检索：`a6d5251842f3d55c11e64c938b7370a2e98c083a`

定位：

Atoll 是基于 Boring.Notch 演进的开源 Swift Dynamic Island 项目。它包含媒体控制、Live Activities、Stats、计时器、剪贴板、天气、扩展、锁屏组件、手势和设置系统。

可借鉴点：

- 多显示器策略更完整：支持 selected screen、preferred screen、show on all displays、屏幕变化后清理和重建窗口。
- fullscreen 检测被单独抽成观察器，说明它不应该和 View 或 provider 混在一起。
- 窗口定位仍然以屏幕顶部中心为基础，再按实际窗口尺寸调整。
- 对非刘海屏和外接显示器需要 fallback，不应假设所有屏幕都有 notch。
- 截屏可见性、权限、锁屏等问题会快速扩散复杂度，应明确延后。

风险：

- Atoll 功能面非常大，包含 Veil 明确禁止的天气、娱乐化 Dynamic Island、插件/扩展、重型面板等方向。
- 部分窗口允许成为 key/main window，适合互动工具，但不适合 Veil Phase 1 的 click-through HUD。
- 依赖、权限和设置系统复杂，和 Veil Phase 1 的原生最小闭环相冲突。
- 同样是 GPL-3.0，不能复制源码。

Veil 取舍：

- 借鉴屏幕变化、窗口重建、多显示器 fallback 的风险意识。
- 借鉴 Stats 类能力的“采样要低资源”原则，不借鉴其大面板 UI。
- 不引入扩展系统、锁屏 widget、天气、剪贴板、终端、媒体和复杂设置。
- 不把 HUD 变成可交互控制中心。

## 7. 研究重点结论

### 黑色菜单栏融合策略

结论：

- TopNotch 和 Forehead 证明黑色菜单栏是隐藏刘海、降低视觉突兀感的有效策略。
- 但壁纸修改路线不适合 Veil，因为 Veil 需要实时状态 HUD，并且不能增加恢复壁纸、动态壁纸和同步状态的复杂度。

早期 Veil Phase 1 推荐：

- 使用 `TopBarFusion` 创建黑色 click-through 顶栏融合窗口。
- 顶栏融合窗口覆盖每个屏幕的菜单栏背景区域，但不承载状态内容。
- 不编辑用户壁纸。
- 不做圆角编辑器，只保留后续视觉微调空间。

当前 Phase 1 决策：

- 默认视觉方案改为只创建 notch capsule HUD overlay。
- 整条顶栏融合降级为历史方案 / 非默认方案。
- 当前 `TopFusionBarController` 保留为 legacy no-op shell，不创建融合窗口。

主要风险：

- 黑色窗口层级太高会遮挡菜单栏文字和图标。
- 层级太低可能无法影响菜单栏半透明背景。
- 外接显示器、隐藏菜单栏、自动显示菜单栏时，菜单栏高度推导可能不稳定。

### Overlay window level

结论：

- Boring/Atoll 使用 AppKit panel/window 承载 SwiftUI 内容，并通过较高窗口层级确保 notch overlay 可见。
- 对 Veil 来说，可见性重要，但不应为了可见性牺牲系统 UI 的可用性。

Veil Phase 1 推荐：

- HUD 使用 `NSPanel` 或等价 `NSWindow`。
- style 使用 borderless、non-activating 的轻量组合。
- level 先使用保守的 status/menu-bar 附近层级；只有在实测 fullscreen 或菜单栏下不可见时，再小步上调。
- 默认只创建 HUD overlay；若未来恢复顶栏融合层，仍应与 HUD overlay 分成两个窗口职责。

主要风险：

- 过高层级会覆盖系统菜单、弹窗、屏幕共享提示或权限提示。
- 不同 macOS 版本对窗口层级和 Spaces 的处理可能不同。
- private SkyLight/CGS 方案不适合作为 Phase 1 基础。

### Click-through 行为

结论：

- Boring/Atoll 是互动型 notch 工具，需要接收 hover、点击、拖拽。
- Veil Phase 1 是常驻状态 HUD，默认应该不接管鼠标。

Veil Phase 1 推荐：

- `OverlayWindow` 默认 `ignoresMouseEvents = true`。
- 若未来恢复 `TopBarFusion`，它必须 click-through。
- SwiftUI HUD 不做按钮、不做 hover 展开、不做拖拽区域。

Phase 2/3 再考虑：

- 如果加入 hover 展开，只在展开交互期间切换可交互状态。
- hover 触发区域需要单独设计，避免挡住菜单栏和系统状态项。

主要风险：

- 完全 click-through 无法直接依赖 SwiftUI `onHover`。
- hover 展开会改变窗口是否吞鼠标事件，是后续复杂度来源。

### Fullscreen 兼容方式

结论：

- Boring/Atoll 都把 fullscreen 作为独立稳定性问题，而不是普通窗口显示问题。
- collection behavior 是第一层手段；Space/fullscreen 检测是第二层手段。

Veil Phase 1 推荐：

- `OverlayWindow` 使用 fullscreen auxiliary、can join all spaces、stationary、ignores cycle 等行为组合。
- 不引入 MacroVisionKit 或复杂 fullscreen detector。
- 不根据前台 App 做隐藏策略。

Phase 2 稳定性重点：

- fullscreen 应用切换。
- 全屏视频。
- 多 Space 切换。
- 外接显示器上的 fullscreen。
- 睡眠唤醒后 overlay 是否丢失。

主要风险：

- 某些 fullscreen App 会改变菜单栏可见性和 Space 层级。
- 顶栏融合窗口已经不是默认路径；若未来恢复，在 fullscreen 中可能多余或不可见。
- 强行常驻 fullscreen 可能干扰沉浸式应用。

### Notch 定位方式

结论：

- 开源项目通常以屏幕顶部中心作为基础定位。
- 更精确的 notch 宽高可以由 `safeAreaInsets.top` 和顶部左右辅助区域推导。
- 非刘海屏必须有 fallback。

Veil Phase 1 推荐：

- HUD 默认定位到目标屏幕顶部中心。
- 高度先基于菜单栏高度和 HUD 固定高度计算。
- 若 `safeAreaInsets.top > 0`，认为目标屏幕具备 notch/safe area。
- 若能读取顶部左右辅助区域，则用于估算 notch 宽度；否则使用固定 HUD 宽度。
- 非刘海屏仍可显示在顶部中心，但不模拟大型 Dynamic Island。

主要风险：

- 不同 MacBook 型号、缩放比例、显示器排列会导致 point 尺寸不同。
- `NSScreen.main` 不一定是用户正在工作的屏幕。
- 外接显示器没有 notch，强行套用 notch 尺寸会显得突兀。

### 多显示器风险

结论：

- 多显示器不是简单遍历 `NSScreen.screens`，还涉及主屏、菜单栏所在屏、外接屏、屏幕 UUID/name 变化、Space 和 frame 坐标系。

Veil Phase 1 推荐：

- 默认不创建 `TopBarFusion` 窗口。
- `OverlayWindow` 优先显示在带刘海安全区的目标屏，先不做每屏 HUD。
- 监听屏幕参数变化并重新定位 HUD。
- provider 与屏幕无关，避免数据层被多屏复杂度污染。

Phase 2 稳定性重点：

- 外接显示器插拔。
- 主屏切换。
- 菜单栏迁移。
- 刘海屏 + 非刘海屏混用。
- 不同缩放比例。
- Space/fullscreen 跨屏切换。

主要风险：

- 以 localized name 作为屏幕 ID 可能不稳定。
- 以 `NSScreen.main` 作为唯一依据会在多屏工作流中错位。
- 多屏都显示 HUD 可能增加干扰，不符合 Veil 的低信息密度原则。

## 8. Veil Phase 1 推荐实现路径

### 8.1 TopBarFusion

历史方案 / 非默认方案：

- AppKit 独立窗口。
- 每个屏幕一个黑色 passthrough window。
- 高度使用 `screen.frame.maxY - screen.visibleFrame.maxY` 推导，并设置合理上下限。
- 窗口层级低于真实菜单栏内容，避免遮挡菜单项。
- 响应屏幕参数变化重建。
- 当前默认代码仅保留 legacy no-op shell，不创建窗口。

不做：

- 不修改壁纸。
- 不做动态壁纸处理。
- 不做圆角编辑器。
- 不做主题系统。

### 8.2 OverlayWindow

推荐：

- AppKit `NSPanel`。
- borderless、non-activating、透明背景、无阴影。
- 通过 `NSHostingView` 承载 SwiftUI `HUDView`。
- 默认 click-through。
- 优先定位到带刘海安全区的目标屏，并水平居中覆盖刘海。
- 保守窗口层级，实测后再调。

不做：

- 不使用私有 SkyLight/CGS。
- 不做 hover 展开。
- 不做拖拽、文件 drop、手势。
- 不把窗口变成 key/main window。

### 8.3 HUDView

推荐：

- SwiftUI 只渲染状态。
- 固定尺寸、两行以内。
- 消费 `StatusStore.snapshot`。
- 文本优先，不画复杂图表。

不做：

- 不直接接触 AppKit 窗口。
- 不直接采样系统数据。
- 不处理鼠标事件。

### 8.4 Phase 2 预留

必须进入 Phase 2 稳定性清单：

- fullscreen。
- 多显示器。
- click-through 与 hover 交互切换。
- 睡眠恢复。
- 屏幕参数变化。
- 刘海屏/非刘海屏 fallback。

Phase 1 只要把边界留干净，不要提前引入复杂 detector、插件和设置系统。

## 9. 不直接照抄声明

TheBoringNotch 和 Atoll 都是很有价值的参考，但 Veil 不直接复制它们的代码、文件结构或交互模型。

原因：

- Veil 的产品身份是安静系统生命体征 HUD，不是 Dynamic Island 工具。
- 参考项目包含 GPL-3.0 代码，复制会带来许可证和维护边界问题。
- 它们的大量功能属于 Veil 明确禁止范围。
- Veil Phase 1 需要的是小、稳、原生、低干扰的窗口和数据闭环。

Veil 只吸收以下结论：

- AppKit 负责窗口与系统行为。
- SwiftUI 负责 HUD 内容。
- 默认只保留 HUD overlay；若恢复顶栏融合，也应与 HUD overlay 分层。
- notch 定位从屏幕几何推导开始。
- fullscreen、多显示器、click-through 是独立稳定性问题。
