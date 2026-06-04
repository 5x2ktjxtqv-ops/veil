# Phase 1 Readiness Audit

状态：Phase 1 readiness audit, updated by CPU thermal pressure lane decision
任务：VEL-026；VEL-028；VEL-029；VEL-030；VEL-031；VEL-032；VEL-034；CPU thermal pressure 更新
日期：2026-05-10

## 1. 审计边界

本审计盘点 Phase 1 离“可反复本机试用的 v0.1”还差哪些硬门槛，并记录 VEL-030 / VEL-031 对默认 HUD 的更新，VEL-032 对 live CPU usage 的接入，VEL-034 对 memory used / cached / swap 口径的收敛，以及 CPU Celsius source 不可达后改用公开 thermal pressure 的 lane 决策。

VEL-030 / VEL-031 执行边界：

- VEL-030 已读取代码、文档、测试，更新 mock/render/tests，并导出静态 PNG render。
- VEL-031 已在用户明确批准后启动 `defaultCompact` mock overlay smoke，最终 `320 x 32` 版本观察约 `60s`。
- VEL-031 mock overlay 只使用本地 mock telemetry；未启动 live telemetry。
- 已运行 `swift build`、`swift test`、`swift build -c release`。
- 未执行 Mullvad CLI。
- 未执行 ping、TCP timing、公网 IP 查询、Speedtest 或任何网络探测。
- 未读取真实 CPU 温度传感器。
- 未切换显示器、未进入 fullscreen、未做 sleep/wake。

## 2. 总体结论

Phase 1 默认产品现在是 visual-only notch capsule + bottom-corner mask；启用 status signals 后，公开基础内容契约是 `3s` 轮换的本地同类双值 HUD：

```text
MEM lane:  18G   2.1G
CPU lane:  18%   OK
CPU lane:  18%   --    # thermal pressure unknown
NET lane:  100M  2M
VPN lane:  FRA   312M  # approved advanced/private adapter only
```

默认尺寸先从 `420 x 32` 收缩为 `292 x 32`；VEL-031 follow-up 发现 `292 x 32` 会让右侧内容吃进物理刘海区域，因此当前 baseline 改为按刘海空区和最大展示内容计算出的 `320 x 32`。

可以冻结：

- `320 x 32` notch capsule visual baseline。
- bottom-corner mask visual module，默认 auto。
- MEM / CPU / NET rotating pair content contract，位于 opt-in status signal layer。
- approved advanced/private lanes 追加在公开基础 lane 后。
- 中间 notch void 永远为空。
- no-approval safety gate：Mullvad 未授权时不得显示真实 relay、城市、延迟、出口或执行任何主动探测。
- CPU status-signal path：启用 status signals 后，telemetry 使用公开 host CPU load tick delta 计算 busy usage；左值约等于 Activity Monitor 的 `System + User`，即 `100% - Idle`。CPU Celsius temperature 在当前边界内不可达，Phase 1 不接 sudo、helper 或 private sensor path；CPU lane 右值改为公开 `ProcessInfo.thermalState` 派生的 thermal pressure：`OK` / `WARM` / `HOT` / `CRIT`，unknown 时显示 `--`。
- MEM status-signal path：启用 status signals 后，左值显示 Activity Monitor-like memory used，不含 cached files；右值显示 swap used；cached files 只作为可回收内存上下文参与 pressure 判断或 future expanded view。
- 健康颜色语义：normal 白、warning 黄、critical 红、muted 灰；CPU live usage 使用持续窗口和回落滞后，no-approval / approval denied VPN fallback 使用 muted。

仍不能宣称长期驻留稳定：fullscreen、多显示器、睡眠恢复、资源预算、packaging 尚未形成完整验收闭环。

## 3. Visual Baseline

结论：`320 x 32` notch capsule 已成为 production default，并有测试保护。

证据：

- `docs/design/visual-baseline-v0.1.md` 记录当前设计尺寸为 `320 x 32`。
- `Sources/Veil/StatusHUDView.swift` 中 `StatusHUDConfiguration.notchCapsule = 320 x 32`，`productionCompact = notchCapsule`。
- `Sources/Veil/OverlayWindows.swift` 中 `notchSideOverhang = 70`，与默认 `180px` notch width 估算合成 `320px` 外框。
- `Tests/VeilTests/StatusHUDConfigurationTests.swift` 断言 production compact 使用 notch capsule、宽 `320`、高 `32`，并保护 `screenCornerWidth: 4.5`、`screenCornerHeight: 5.5`、`screenCornerControl: 0.50`、`bottomCornerWidth: 14`、`bottomCornerHeight: 9`、`bottomCornerControl: 0.78`。
- `Tests/VeilTests/NotchCapsuleHUDMappingTests.swift` 断言 production default 没有回退到 `.compact` 或 `.expanded`。

历史说明：VEL-031 已补一条 `320 x 32` mock overlay visual smoke。VEL-028 / VEL-029 的 no-approval live / fullscreen overlay smoke 仍是 `420 x 32` 时代记录；新的 live overlay 或 fullscreen smoke 仍必须另开 approval 任务。

## 4. Content Contract

结论：rotating pair HUD 已由 mapping tests 保护。

证据：

- `docs/design/notch-capsule-content-contract-v0.1.md` 冻结 VEL-030 内容契约。
- `StatusHUDMapping.notchCapsuleLaneRotationInterval = 3`。
- `StatusHUDMapping.notchCapsuleLane(at:)` 公开基础顺序为 MEM -> CPU -> NET。
- VPN lane 测试断言 `FRA` / 当前被动吞吐，例如 `312M`。
- MEM lane 测试断言 `18G` / `2.1G`。
- VEL-034 后，MEM lane 左侧来自 `MemoryStatus.usedBytes`，不包含 `cachedFilesBytes`；右侧来自 `swapUsedBytes`。
- CPU lane 测试断言 `18%` / `OK`。
- CPU thermal pressure unknown 测试断言 `18%` / `--`。
- CPU thermal pressure 测试覆盖 `OK` / `WARM` / `HOT` / `CRIT` / `--` 映射；`WARM` / `HOT` 为 warning，`CRIT` 为 critical。
- CPU temperature opt-in 测试仍覆盖 runtime flag、`powermetrics --samplers smc` 调用参数、低频缓存、永久不可用失败保护和 CPU temperature parser；该 Celsius path 不再作为默认 notch lane 右值。
- CPU usage health 测试断言 warning / critical role；CPU usage sampler 测试断言 busy usage = `user + system + nice` = `100% - idle`；CPU usage tracker 测试断言 `15s` 持续窗口和回落滞后。
- MEM pressure 测试断言 elevated / high role；`MemoryMonitorTests` 保护 displayed used 使用 Activity Monitor-like buckets 并排除 cached files，并保护 24GB 本机试用阈值：swap `>= 2GB` 或 available / total `< 15%` 为 elevated，swap `>= 4GB` 或 available / total `< 8%` 为 high。compressed memory 不再单独触发 warning/high，只在 compressed 很高且 available 也偏低时作为佐证信号。
- VPN approval required / denied notch fallback 均为 muted；公开默认态不把未启用个人 VPN adapter 当作 warning。
- 所有 notch lane 测试都断言 metric label 为空、value 不包含字段名、`notchVoid` 为空。

CPU usage 当前已由 `CPUUsageSampler` 接入 status-signal live telemetry；CPU lane 右值改为 `ProcessInfo.thermalState` 的公开热压力状态，不假装显示摄氏温度。CPU temperature 仍是 optional 数据模型，默认 visual-only 路径不读取 CPU usage、thermal pressure 或真实传感器。用户显式 opt in 后，`PowermetricsCPUTemperatureSampler` 仍会低频执行 Apple `powermetrics` SMC sampler 并 fail closed，但 2026-05-10 本机 opt-in smoke 与后续只读探索确认：当前边界内没有适合 Phase 1 默认产品的 public / non-sudo / non-helper / non-private Celsius source。

## 5. Safety Gates

结论：Phase 1 必要 safety gates 仍然完整；默认路径现在只启动 visual modules，不进入 live telemetry，不读取 memory / CPU / passive network counters，不读取 task-status 文件，不创建 power assertions，也不扩大 Mullvad、网络探测或 CPU 温度读取权限。CPU lane 右侧 thermal pressure 来自公开 `ProcessInfo.thermalState`，但只有 status signals 启用后才进入该路径；CPU Celsius 读取仍是显式 per-run opt-in 且不作为默认 HUD 前提。

证据：

- `RuntimeConfiguration` 默认 `statusSignals.isEnabled = false`、`mullvadApproval = .notRequested`。
- `RuntimeConfiguration` 支持 per-run `--approve-mullvad-readonly`、`--deny-mullvad-readonly`、`--no-mullvad-approval-prompt`。
- `Tests/VeilTests/RuntimeConfigurationTests.swift` 覆盖默认 status signals 关闭、显式 status signals、显式 approval、显式 denial、mock telemetry 跳过 live、mock/live 互斥、未知 mock fixture fail-closed。
- `TelemetryServiceSafetyGateTests` 覆盖 no approval / denied 时仍生成 fallback snapshot，且 `ProcessRunner` 没有记录任何 Mullvad 或 ping 调用。
- VEL-032 添加 `CPUUsageSampler`，只读取公开 host CPU load ticks 计算 usage；默认 `CPUStatus.temperatureCelsius` 在 live path 仍保持 `nil`，`CPUStatus.thermalPressure` 由公开 `ProcessInfo.thermalState` 填充。
- CPU temperature opt-in 添加 `--approve-cpu-temperature-readonly` / `--deny-cpu-temperature-readonly`；默认 `.notRequested`，未授权时不执行 `powermetrics`；已知永久失败输出不会被高频重试。
- `docs/process/runtime-permissions.md` 已更新 no-approval VPN lane 的受限表达。

## 6. Static Render Review

VEL-030 已导出静态 PNG：

```text
docs/design/renders/notch-capsule.png
docs/design/renders/notch-capsule-vpn.png
docs/design/renders/notch-capsule-mem.png
docs/design/renders/notch-capsule-cpu.png
docs/design/renders/notch-capsule-cpu-temp-unavailable.png
```

检查结果：

- 关键 notch renders 均为 `320 x 32`。
- MEM / CPU / NET 三条公开基础 lane 肉眼检查不拥挤。
- CPU thermal pressure unknown render 右侧显示 `--`。
- VEL-031 已补 `320 x 32` mock overlay visual smoke；本审计仍未补新的 live overlay 或 fullscreen smoke。

## 7. Current Verification

当前验证结果：

```text
swift build             passed
swift test              passed, 194 XCTest tests
swift build -c release  passed
static PNG export       refreshed after CPU thermal pressure lane decision
no-approval live smoke  passed, 320 x 32 bounds observed
memory-lane live smoke  passed, 320 x 32 bounds observed
cpu-temperature smoke   failed real Celsius data, safe fallback observed; Celsius deferred
cpu-thermal smoke       passed by unit/provider path; live dogfood uses thermal pressure lane
```

说明：

- 构建、测试和 release build 均通过。
- 静态 render 本轮未重导出，沿用 VEL-030 / VEL-031 已验证的 `320 x 32` render。
- VEL-031 mock overlay smoke 使用本地 mock telemetry，未启动 live telemetry。
- VEL-032 no-approval live overlay smoke 已记录到 `docs/design/320-rotating-pair-no-approval-live-smoke.md`。
- VEL-032 smoke 观察到 `320 x 32` bounds、VPN `--` / `--` fallback、MEM `23G` / `1.7G` live values、CPU `16%` / `--` live values，并在停止后确认 `Veil windows on screen: 0` 和 `pgrep -x Veil` 无输出。
- VEL-034 memory-lane live smoke 已记录到 `docs/design/memory-lane-live-smoke.md`，只观察 MEM lane，确认 `320 x 32` bounds、MEM `17G` / `1.7G` live values、无 `MEM` / `RAM` / `SWAP` 字段名，并在停止后确认 `Veil windows on screen: 0` 和 `pgrep -x Veil` 无输出。
- CPU temperature opt-in smoke 已记录到 `docs/design/cpu-temperature-live-smoke.md`，确认 Celsius path fail closed；后续来源探索未找到适合 Phase 1 的 public / non-sudo / non-helper / non-private Celsius CPU temperature path。
- CPU thermal pressure lane 改用 `ProcessInfo.thermalState`，在 default / live path 中显示 `OK` / `WARM` / `HOT` / `CRIT` / `--`。
- 本次没有执行真实 Mullvad CLI、ping、TCP timing 或网络探测。CPU temperature opt-in smoke 只在用户批准范围内执行了 Apple `powermetrics` 只读诊断。

2026-05-10 后续 hardening 更新：

- `ProcessRunner` 增加结构化 `ProcessRunResult`，显式区分 timeout / failed-to-start / exited，并用异步 pipe drain 降低外部命令卡住 telemetry queue 的风险。
- `OverlayHUDController` 会把真实 resolved panel size 传入 SwiftUI HUD，避免宽刘海或更高 safe area 下 panel 扩大但内容仍按 `320 x 32` 绘制。
- CPU lane 右值从 Celsius temperature fallback 改为公开 thermal pressure 短状态，避免把不可达的摄氏温度硬接进默认产品。
- Mullvad latency cache 绑定到具体 relay / visible endpoint target；target 变化时清空缓存并重新探测。
- 被动吞吐估算改为按接口保留计数，并选择当前窗口最繁忙的单一接口，避免 VPN 与物理接口同时计数时简单求和造成高估。
- live refresh timer 设置 tolerance，减少常驻运行中对精确唤醒的要求。

## 8. Known Gaps

### Fullscreen

已存在一条 VEL-029 fullscreen no-approval smoke，但它属于 `420 x 32` 时代。`320 x 32` current baseline 尚未做新的 fullscreen smoke。

### 多显示器

尚未有外接显示器插拔、主屏切换、非刘海屏 fallback、多显示器 fullscreen 的系统 smoke。

### 睡眠恢复

当前代码监听屏幕参数变化，但没有完整 sleep/wake 恢复矩阵。Phase 1 alpha 仍按 runbook 记录为手动重启策略。

### 低资源占用

timer 刷新、Mullvad status 节流和 latency probe 节流仍在，但尚未形成 CPU、RAM、电量、唤醒频率的量化验收和 idle smoke。

### Packaging

项目仍是 Swift Package executable；`swift build -c release` 通过，但尚未有 `.app` bundle、签名、notarization、DMG/pkg 或版本化 release artifact。

## 9. Next Cut Recommendation

下一阶段应该只做 Phase 1 hardening：

- `320 x 32` mock visual smoke 已记录；后续 live overlay / fullscreen / 多显示器等更大范围仍另开 approval 任务。
- 保持 rotating pair HUD，不顺手加字段。
- 把无 Mullvad approval smoke 更新到 VEL-030 runbook 预期。
- 补多显示器最小 smoke checklist。
- 决定睡眠恢复的 Phase 1 策略：实现最小 wake restore，或继续明确 alpha 需要手动重启。
- 定义低资源预算，补一次短 idle resource smoke。
- 补 packaging plan。

推迟到 Phase 2：

- 完整 fullscreen / Space 矩阵。
- 完整多显示器策略。
- 完整睡眠、锁屏、显示器唤醒恢复矩阵。
- login item / launch at startup。
- app bundle、签名/notarization、DMG/pkg。
- hover / expanded state。
- packet loss、网络抖动、TCP timing 等更完整网络稳定性模块。

## 10. Readiness Checklist

- [x] Visual baseline updated: `320 x 32` notch capsule.
- [x] Visual baseline protected by tests.
- [x] Content contract updated: MEM / CPU / NET rotating pair lanes.
- [x] Rotation period protected by tests: `3s`.
- [x] Notch void empty protected by tests.
- [x] Field labels absent from notch lanes protected by tests.
- [x] CPU thermal pressure unknown fallback protected by tests.
- [x] CPU live usage provider added with public host CPU load tick delta.
- [x] CPU usage health thresholds and hysteresis protected by tests.
- [x] CPU thermal pressure live provider added with public `ProcessInfo.thermalState`.
- [x] CPU temperature Celsius remains unavailable by default and optional by approval only.
- [x] CPU temperature approved failure path fails closed as `--`.
- [x] CPU real temperature live data deferred for Phase 1 after source exploration.
- [x] VPN approval denied notch fallback uses muted role.
- [x] Mullvad default approval is `.notRequested`.
- [x] Deny/no approval path returns fallback without Mullvad commands.
- [x] Mock telemetry and live telemetry are mutually exclusive.
- [x] Unknown mock fixture fails closed.
- [x] Current VEL-032 `swift build` passed.
- [x] Current VEL-032 `swift test` passed.
- [x] Current VEL-032 `swift build -c release` passed.
- [x] ProcessRunner timeout handling protected by tests.
- [x] Overlay resolved-size handoff protected by tests.
- [x] Mullvad relay-change latency cache invalidation protected by tests.
- [x] Network throughput single-interface selection protected by tests.
- [x] Static render export passed.
- [x] VEL-031 mock overlay visual smoke recorded.
- [x] VEL-032 no-approval live overlay smoke recorded.
- [x] VEL-034 memory-lane live smoke recorded.
- [x] CPU temperature opt-in smoke recorded; real Celsius data not connected.
- [ ] VEL-030 fullscreen smoke recorded.
- [ ] Multi-display smoke recorded.
- [x] Sleep/wake Phase 1 strategy documented: alpha manual restart.
- [ ] Sleep/wake smoke recorded.
- [x] Low-resource budget draft documented.
- [ ] Low-resource smoke recorded.
- [x] Minimal local trial checklist documented.
- [ ] Packaging plan.
