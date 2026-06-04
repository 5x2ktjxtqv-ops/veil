# Veil Phase 1 Architecture

状态：Draft, Phase 1 visual baseline frozen by VEL-012  
版本：v0.1  
日期：2026-05-08

## 1. 架构目标

Phase 1 的目标不是搭一个可扩展平台，而是用 Swift、AppKit、SwiftUI 做出一个能长期演进的原生最小闭环：

- 使用 `notch capsule` / 刘海延展胶囊完成刘海视觉融合。
- 在刘海左右翼区稳定显示一个低信息密度 HUD。
- 采集 RAM、Swap、Mullvad 状态、当前延迟和轻量下载速率。
- 保持低 CPU、低 RAM、低网络扰动。

Phase 1 的架构判断标准：任何模块只要不能帮助这个最小闭环跑起来，都不应该进入当前设计。

## 2. 明确不引入

Phase 1 不包含：

- 复杂插件系统。
- Electron。
- WebView UI。
- React、Vue 或其他 Web 前端运行时。
- 重型状态管理框架。
- 重型图表库。
- 大型监控 Dashboard。
- 后台服务守护进程。
- 跨平台抽象层。
- Mullvad reverse engineering。

依赖原则：

- 优先使用 macOS 原生 API。
- Swift Package 保持轻量。
- 除非某个依赖能显著降低系统级复杂度，否则不引入第三方库。

## 3. 总体分层

Veil Phase 1 采用三层结构：

```text
┌─────────────────────────────────────────────┐
│ 视觉基线层                                   │
│ NotchCapsule / Legacy TopFusion Shell        │
└─────────────────────────────────────────────┘
                    │
┌─────────────────────────────────────────────┐
│ Overlay 引擎                                 │
│ OverlayWindow / HUDView / StatusStore        │
└─────────────────────────────────────────────┘
                    │
┌─────────────────────────────────────────────┐
│ 数据提供层                                   │
│ Memory / CPU / Network / Mullvad Providers   │
└─────────────────────────────────────────────┘
```

数据流：

```text
MemoryProvider ───┐
CPUProvider ──────┤
NetworkProvider ──┼─ TelemetryService ── StatusStore ── HUDView
MullvadProvider ──┘
```

窗口流：

```text
AppDelegate
  ├─ Legacy TopFusion no-op shell
  └─ OverlayWindow
       └─ HUDView
```

## 4. AppKit 与 SwiftUI 边界

### 必须使用 AppKit 的部分

这些部分直接处理 macOS 窗口、屏幕、层级和系统事件，必须放在 AppKit：

- `OverlayWindow`
- `TopFusionBarController` legacy no-op shell
- `AppDelegate`
- 屏幕变化监听。
- 窗口层级控制。
- click-through 行为。
- 全屏空间行为。
- 多显示器窗口重建。
- 睡眠唤醒后的窗口恢复。

原因：

- SwiftUI 不适合作为 Phase 1 的窗口层级控制核心。
- 刘海、菜单栏、fullscreen auxiliary window、click-through 都是 AppKit 更直接、更可控。

### 可以使用 SwiftUI 的部分

这些部分只负责声明式渲染，不直接管理系统窗口：

- `HUDView`
- 指标文本布局。
- 状态颜色。
- 简单 hover 展开视图，Phase 1 不实现。

SwiftUI 使用边界：

- SwiftUI 只消费 `StatusStore`。
- SwiftUI 不直接调用系统采样 API。
- SwiftUI 不负责创建、定位或管理窗口。
- SwiftUI 不持有 Mullvad、内存或网络 provider。

## 5. 模块边界

### NotchCapsuleVisualBaseline

所属层：视觉基线层  
技术归属：SwiftUI shape + AppKit window positioning  
当前源码对应：`StatusHUDConfiguration`、`NotchIslandStyle`、`NotchIslandShape`、`OverlayHUDController`、`HUDPanel`

职责：

- 冻结 Phase 1 默认视觉方案为 `StatusHUDConfiguration.productionCompact = .notchCapsule`。
- 使用刘海延展胶囊覆盖物理刘海，并让左右翼区承载 RAM / VPN。
- 保持最终通过参数：`screenCornerWidth: 4.5`、`screenCornerHeight: 5.5`、`screenCornerControl: 0.50`、`bottomCornerWidth: 14`、`bottomCornerHeight: 9`、`bottomCornerControl: 0.78`。
- 将整条黑色顶栏融合保留为历史方案 / 非默认方案；当前 `TopFusionBarController` 只是兼容壳，不创建窗口。

输入：

- `StatusHUDConfiguration.productionCompact`
- `NotchIslandStyle.nativeSoft`
- `NSScreen.safeAreaInsets.top`
- `NSScreen.auxiliaryTopLeftArea` / `auxiliaryTopRightArea`

输出：

- 一个水平居中覆盖刘海的黑色胶囊 HUD。

不负责：

- 不创建整条黑色顶栏窗口作为默认态。
- 不把中间刘海覆盖区变成信息区。
- 不做壁纸管理。
- 不做主题系统。
- 不改变 live data 的采样策略。

Phase 1 成功标准：

- `productionCompact` 与 `notchCapsule` 保持一致。
- 默认胶囊保持 VEL-012 notch capsule 形态；VEL-031 follow-up 后当前设计尺寸为 `320 x 32` rotating pair，VEL-011/012 的 `(589, 0, 292, 32)` 仍作为历史 smoke 通过记录。
- 每条 lane 只在左右翼显示一对同类短值，中间覆盖刘海且不承载文字。
- 不拦截鼠标事件。
- 旧整条顶栏黑化不会重新成为默认方案。

### OverlayWindow

所属层：Overlay 引擎  
技术归属：AppKit  
当前源码对应：`OverlayHUDController`、`HUDPanel`

职责：

- 创建承载 HUD 的 `NSPanel` 或等价 AppKit 窗口。
- 将 notch capsule 定位为水平居中覆盖主屏幕刘海。
- 设置窗口透明背景、无阴影、非激活。
- 设置窗口层级和 collection behavior。
- 通过 `NSHostingView` 承载 SwiftUI `HUDView`。

输入：

- `StatusStore`
- 主屏幕 frame。
- notch 安全区域信息：`safeAreaInsets.top` 和左右 auxiliary top areas。

输出：

- 一个稳定显示的 HUD overlay。

不负责：

- 不采集数据。
- 不格式化业务指标。
- 不做复杂 hover 动画。
- 不实现设置页。
- 不提供插件挂载点。

Phase 1 成功标准：

- HUD 能稳定显示在预期位置。
- 默认不成为 key/main window。
- 不影响用户常规点击。
- 位置计算简单、可读，并与冻结的 notch capsule 基线一致。

### HUDView

所属层：Overlay 引擎的展示子层  
技术归属：SwiftUI  
当前源码对应：`StatusHUDView`

职责：

- 从 `StatusStore` 读取当前 `VeilSnapshot`。
- 从当前启用的 signal lanes 中选择一条，在左右翼渲染一对紧凑值。
- 默认公开形态优先使用本地安全信号；Mullvad、private local compact-status endpoints、active probe 等个人 workflow adapters 必须 opt in。
- 在异常或未来展开态中渲染 Swap、VPN 节点、延迟、下载速率等扩展上下文。
- 用克制的视觉表达异常状态。
- 保持固定尺寸、低信息密度、余光可读。

输入：

- `StatusStore.snapshot`

输出：

- SwiftUI View，由 AppKit 的 `NSHostingView` 承载。

不负责：

- 不创建窗口。
- 不监听屏幕变化。
- 不执行 `mullvad` 命令。
- 不读取 Mach memory stats。
- 不维护轮询计时器。
- 不做图表、Dashboard 或娱乐化 Dynamic Island 展开。

Phase 1 成功标准：

- 默认 notch capsule 只展示左右两个翼区的核心生命体征。
- 文本在固定 HUD 尺寸内稳定、不跳动。
- 异常状态有提示，但正常状态保持安静。

### StatusStore

所属层：Overlay 引擎与数据提供层之间的状态边界  
技术归属：Swift / Combine / MainActor  
当前源码对应：`StatusStore`

职责：

- 保存当前 `VeilSnapshot`。
- 作为 SwiftUI 与数据提供层之间唯一可观察状态源。
- 确保 UI 更新发生在 MainActor。

输入：

- `TelemetryService` 生成的 `VeilSnapshot`。

输出：

- `@Published snapshot` 给 `HUDView`。

不负责：

- 不直接采样内存。
- 不直接调用 Mullvad CLI。
- 不包含业务轮询策略。
- 不保存历史序列。
- 不持久化配置。

Phase 1 成功标准：

- UI 只依赖一个稳定 snapshot。
- 数据更新路径清晰。
- 后续增加字段时，能通过 `VeilSnapshot` 演进，而不是让 View 直接耦合 provider。

### MemoryProvider

所属层：数据提供层  
技术归属：Swift + Darwin / Mach APIs  
当前源码对应：`MemoryMonitor`

职责：

- 采集总内存、已用内存、Swap 使用量。
- 计算简化内存压力等级。
- 生成 `MemoryStatus`。

输入：

- `host_statistics64`
- `vm_statistics64`
- `sysctlbyname("hw.memsize")`
- `sysctlbyname("vm.swapusage")`

输出：

- `MemoryStatus`

不负责：

- 不展示 UI。
- 不管理轮询计时器。
- 不做进程级内存排行。
- 不做内存清理。
- 不保存历史曲线。

Phase 1 成功标准：

- 在低频采样下稳定返回 RAM 和 Swap。
- 压力等级足够用于 HUD 提示。
- 采样开销低，不制造新的系统压力。

### CPUProvider

所属层：数据提供层
技术归属：Swift + Darwin / Mach APIs + Foundation `ProcessInfo` + optional Foundation `Process`
当前源码对应：`CPUUsageSampler`、`ProcessInfoThermalPressureProvider`、`PowermetricsCPUTemperatureSampler`

职责：

- 使用公开 host CPU load ticks 计算 busy usage。
- 使用持续窗口和回落滞后生成 CPU usage health。
- 使用公开 `ProcessInfo.thermalState` 生成 CPU thermal pressure。
- 默认不读取真实 CPU temperature sensor。
- 在本次运行显式 CPU temperature approval 后，optional Celsius provider 可低频尝试只读 `powermetrics` 温度采样；该值不作为默认 notch lane 右值。
- 当 Celsius 采样不可用、超时或权限不足时，返回 `nil`；当 thermal pressure unknown 时，HUD 右值显示 `--`。

输入：

- `host_statistics(HOST_CPU_LOAD_INFO)`
- `ProcessInfo.thermalState`
- approval-gated `powermetrics --samplers smc`

输出：

- `CPUStatus`

不负责：

- 不做 CPU 压力测试。
- 不读取进程级 CPU 排行。
- 不要求 sudo 或持久化权限。
- 不把温度不可用视为错误状态。

Phase 1 成功标准：

- CPU usage 在低频采样下稳定返回。
- CPU thermal pressure 在默认路径稳定返回公开状态或 `--`。
- CPU Celsius temperature 默认 fail closed。
- 外部温度命令有超时、缓存和永久不可用保护。

### MullvadProvider

所属层：数据提供层  
技术归属：Swift + Foundation `Process`  
当前源码对应：`MullvadMonitor`、`ProcessRunner`

职责：

- 在本次运行获得明确 approval 后，调用 `mullvad status` 获取连接状态。
- 解析国家、城市、relay、visible location。
- 在连接状态且已 approval 的前提下进行轻量延迟探测。
- 合并当前下载速率估算到 VPN 状态。
- 生成 `VPNStatus`。

输入：

- approval-gated `mullvad status`
- approval-gated 轻量 `ping`
- 来自网络采样器的 download Mbps。

输出：

- `VPNStatus`

不负责：

- 不替代 Mullvad 官方 App。
- 不执行全节点测速。
- 不执行大规模 benchmark。
- 不自动切换节点。
- 不 reverse engineering Mullvad。
- 不持久保存 relay 列表。

Phase 1 成功标准：

- Mullvad 不存在或命令失败时，返回可解释的 unknown/error 状态。
- 已连接时能显示当前节点、延迟和下载速率估算。
- 命令调用有超时，不阻塞主线程。

### NetworkThroughputProvider

所属层：数据提供层  
技术归属：Swift + Darwin network interface APIs  
当前源码对应：`NetworkThroughputSampler`

职责：

- 读取非 loopback 网络接口计数器。
- 基于相邻采样计算下载和上传 Mbps。
- 为 MullvadProvider 和未来网络稳定性模块提供轻量速度上下文。

输入：

- `getifaddrs`
- `if_data`
- 上一次采样结果。

输出：

- `NetworkThroughput`

不负责：

- 不做 Speedtest。
- 不主动制造大流量。
- 不做 App 级流量归因。
- 不展示图表。

Phase 1 成功标准：

- 无需外部服务即可估算当前吞吐。
- 第一次采样或异常读取时返回 nil，而不是制造假数据。
- 采样开销足够低。

### TelemetryService

所属层：数据提供层协调器  
技术归属：Swift / Foundation / background queue  
当前源码对应：`TelemetryService`

职责：

- 协调 `MemoryProvider`、`CPUProvider`、`NetworkThroughputProvider`、`MullvadProvider`。
- 在后台队列执行采样。
- 组装 `VeilSnapshot`。
- 将 snapshot 回到 MainActor 后交给 `StatusStore`。

输入：

- 各 provider 的 sample 结果。
- 轮询触发信号。

输出：

- `VeilSnapshot`

不负责：

- 不创建窗口。
- 不渲染 UI。
- 不持久化历史数据。
- 不实现插件调度。
- 不处理复杂用户配置。

Phase 1 成功标准：

- 主线程不被 shell 命令或系统采样阻塞。
- 每次刷新生成一个完整 snapshot。
- provider 失败时仍能输出降级 snapshot。

## 6. 应用生命周期

Phase 1 生命周期：

1. `AppDelegate` 启动 accessory app。
2. 创建 `StatusStore`。
3. 创建 `TelemetryService`。
4. 初始化 legacy `TopFusionBarController` no-op shell；Phase 1 默认不创建整条顶栏黑化窗口。
5. 创建并显示 `OverlayWindow`，内部承载 `HUDView` 的 notch capsule。
6. 启动低频 timer。
7. timer 触发 `TelemetryService.refresh`。
8. provider 在后台采样。
9. `TelemetryService` 组装 `VeilSnapshot`。
10. 回到 MainActor 更新 `StatusStore.snapshot`。
11. `HUDView` 自动刷新。

Phase 1 轮询原则：

- 内存和吞吐可以较低频刷新。
- CPU usage 使用本地 host tick delta；CPU lane 右值使用公开 `ProcessInfo.thermalState`；CPU Celsius temperature 只在显式 approval 后走低频只读 optional path。
- Mullvad CLI 调用必须有节流和超时。
- 延迟探测频率低于 HUD 刷新频率。
- 刷新 timer 可以设置 tolerance，避免常驻模式下要求精确唤醒。
- 任何采样失败都不应该影响 HUD 存活。

## 7. 数据模型

核心模型：

- `VeilSnapshot`
- `MemoryStatus`
- `VPNStatus`
- `NetworkThroughput`
- `CPUStatus`
- `HealthLevel`
- `VPNConnectionState`

模型原则：

- View 只读模型，不推导复杂业务状态。
- provider 输出结构化状态，不输出 UI 字符串。
- UI 格式化只做最后一层的轻量展示转换。
- 未知状态使用 nil 或 unknown，不伪造健康数据。

## 8. Phase 1 文件组织建议

当前源码可以继续保持小文件结构。若后续拆分，建议按职责命名：

```text
Sources/Veil/
  AppDelegate.swift
  Models.swift
  StatusStore.swift

  Overlay/
    OverlayWindow.swift
    OverlayWindows.swift      # OverlayHUDController, HUDPanel, legacy TopFusionBarController no-op shell
    HUDPanel.swift

  Views/
    HUDView.swift

  Providers/
    MemoryProvider.swift
    CPUUsageSampler.swift
    MullvadProvider.swift
    NetworkThroughputProvider.swift
    ProcessRunner.swift

  Services/
    TelemetryService.swift
```

Phase 1 不强制立刻重构目录。只有当文件继续增长、职责混在一起时，再按上述边界拆分。

## 9. Phase 2 稳定性重点

以下能力不是 Phase 1 的主要实现目标，但必须在 Phase 1 架构中预留边界：

- fullscreen。
- 多显示器。
- click-through。
- 睡眠恢复。
- 屏幕参数变化。
- 外接显示器插拔。
- 刘海屏与非刘海屏差异。
- 低 CPU 和低 RAM 常驻运行。

Phase 2 预期处理方式：

- fullscreen 继续由 AppKit collection behavior 和窗口层级策略承担。
- 多显示器默认由 `OverlayWindow` 选择带刘海安全区的目标屏幕；整条顶栏黑化不作为默认多屏策略。
- click-through 继续保持在 AppKit window 层，不交给 SwiftUI 手势系统。
- 睡眠恢复通过应用生命周期和 workspace notification 触发窗口重建与数据刷新。

## 10. 关键约束

架构约束：

- `HUDView` 不知道 provider。
- provider 不知道 SwiftUI。
- `StatusStore` 是 UI 观察状态的唯一入口。
- `TelemetryService` 是 provider 编排入口。
- AppKit 负责窗口，SwiftUI 负责内容。

性能约束：

- 不在主线程执行 shell 命令。
- 不高频调用 Mullvad CLI。
- 不运行重型测速。
- 不绘制持续动画图表。
- 不保存长历史序列。

产品约束：

- 不做插件系统。
- 不做大型 Dashboard。
- 不做娱乐化 Dynamic Island。
- 不添加天气、新闻、股票、社交通知等非生命体征模块。

## 11. Phase 1 验收标准

架构文档验收：

- 明确三层结构：视觉基线层、Overlay 引擎、数据提供层。
- 明确 `OverlayWindow`、notch capsule visual baseline、`MemoryProvider`、`CPUProvider`、`NetworkThroughputProvider`、`MullvadProvider`、`StatusStore`、`HUDView` 的边界。
- 明确不包含复杂插件系统。
- 明确不引入 Electron、WebView 或重型依赖。
- 明确哪些部分必须 AppKit，哪些可以 SwiftUI。
- 明确 fullscreen、多显示器、click-through 是 Phase 2 稳定性重点。

实现验收参考：

- 应用启动后能创建 notch capsule HUD overlay；legacy 顶栏融合 shell 不创建整条顶栏黑化窗口。
- HUD 只通过 `StatusStore` 获取状态。
- 数据采样在后台执行，主线程只处理窗口和 UI 更新。
- provider 失败时，HUD 仍能显示 unknown 或降级状态。
- 代码结构能自然支撑 Phase 2 的稳定性工作，而不需要推翻 Phase 1。
