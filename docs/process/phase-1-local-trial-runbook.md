# Phase 1 Local Trial Runbook

状态：Phase 1 hardening runbook, updated by CPU thermal pressure lane decision
任务：VEL-027 / VEL-032 / VEL-034 / CPU thermal pressure
日期：2026-05-10

## 1. 目标

本 runbook 把 Phase 1 从“能跑通一次”收束成“可以在本机安全反复试用”的执行清单。

本文件只定义本机试用、smoke、停止和清理流程。创建本文件时不启动 Veil，不启动 overlay，不执行 Mullvad CLI，不执行 `ping`、TCP timing、公网 IP 查询、Speedtest 或任何网络探测。

## 2. 总原则

- 默认先走 visual-only smoke；status signal smoke 必须显式开启 `--status-signals`。
- 每次试用都从 clean worktree、无残留 `Veil` 进程、构建测试通过开始。
- 每次启动都必须可在 30-60 秒内停止；长时间 idle resource smoke 必须单独说明时长。
- Mullvad approval 只按本次启动周期授权，不持久化，不扩展到新命令类型。
- CPU lane 只在 status signals smoke 中显示 live usage 与公开 thermal pressure，不显示摄氏温度；CPU temperature approval 只按本次启动周期授权，不持久化，默认 smoke 不读取真实 CPU 温度传感器。
- 任何 fullscreen、多显示器、sleep/wake 或 read-only Mullvad smoke 都必须有明确试用范围和停止条件。
- 记录只写脱敏结果；不记录完整出口 IP、relay host、账号、配置、日志或诊断内容。

## 3. 本机试用前置检查

每次试用前依次确认：

```sh
git status --short --branch
pgrep -x Veil || true
swift build
swift test
swift build -c release
```

通过标准：

- `git status --short --branch` 只显示当前分支，没有任何 changed path；如有改动，先提交、暂存到明确位置或停下确认。
- `pgrep -x Veil` 无输出，确认没有残留 `Veil` 进程。
- `swift build` 通过。
- `swift test` 通过。
- `swift build -c release` 通过。

试用前不得执行：

- `mullvad status`、`mullvad relay list` 或任何其他 Mullvad CLI。
- `ping`、TCP timing、公网 IP 查询、Speedtest、fast.com、iperf、traceroute、mtr、端口扫描。
- 修改 Mullvad、DNS、route、proxy、防火墙、LaunchAgent、login item 或系统权限设置。

## 4. 默认 Smoke：Visual-Only

这是 Phase 1 hardening 的默认重复 smoke。它只验证 notch capsule / bottom-corner mask 的 visual module 路径，不启动真实 live telemetry，不显示 VPN / MEM / CPU lane。

执行这条 smoke 前仍需要一个明确的本机 overlay smoke 任务或用户确认；“visual-only”表示不授权 Mullvad 读取、不做网络探测、不读取内存/CPU/接口计数器。

运行命令：

```sh
swift run Veil -- --no-status-signals --no-mullvad-approval-prompt
```

观察窗口：

- 默认观察 30-60 秒。
- 只验证启动、显示、刷新、停止和清理。
- 不扩大到 fullscreen、多显示器切换、sleep/wake 或长时间资源测试。

运行中检查：

- 不出现 Mullvad approval prompt。
- 不出现系统权限 prompt 或额外授权请求。
- 有刘海内建屏时，HUD 保持 `320 x 32` notch capsule 视觉形态，不显示文字或指示点。
- 普通矩形外接屏在 status signals 关闭时不显示空胶囊。
- bottom-corner mask 只在支持的圆角/刘海内建屏上渲染；fullscreen 覆盖时应隐藏。
- 不出现 VPN / MEM / CPU 轮换 lane。
- 不执行 Mullvad CLI、`ping`、TCP timing 或任何主动网络探测。
- 不读取 memory、CPU usage、thermal pressure 或 passive network counters。
- 不改变 Mullvad、网络、DNS、route、proxy 或防火墙状态。

中止条件：

- overlay 落到错误显示器、遮挡菜单栏关键区域、抢焦点或影响当前工作。
- 出现任何非预期 prompt。
- 用户感知到 VPN、网络、DNS、route、proxy 或桌面异常。
- 用户要求停止。

记录模板：

```md
## YYYY-MM-DD Visual-Only Smoke

- run command: `swift run Veil -- --no-status-signals --no-mullvad-approval-prompt`
- start time:
- end time:
- HUD shape:
- text / indicators visible: none expected
- bottom-corner mask:
- rectangular external blank capsule: none expected
- bounds:
- unexpected prompts:
- network/Mullvad commands executed: none
- local telemetry counters read: none expected
- abort reason, if any:
- cleanup confirmation:
- validation status:
```

如需验证本地状态信号，单独运行 opt-in smoke：

```sh
swift run Veil -- --status-signals --deny-mullvad-readonly --no-mullvad-approval-prompt
```

该 smoke 才应观察 MEM / CPU / NET lane 轮换、live memory、CPU usage、public thermal pressure 和 passive network counters。VPN 只有在显式 approval 后才应追加进入轮换。

最新 mock overlay visual smoke 记录：`docs/design/mock-overlay-smoke.md` 中的 `2026-05-10 VEL-031 320 Calculated Width Mock Overlay Smoke`，已观察到当前 `320 x 32` bounds。历史 no-approval live overlay smoke 记录：`docs/design/320-rotating-pair-no-approval-live-smoke.md` 中的 `2026-05-10 VEL-032 No-Approval Live CPU Usage Smoke`，属于 status-signals 默认打开前的记录；新的 live smoke 必须显式传入 `--status-signals`。最新 memory-lane-only live smoke 记录：`docs/design/memory-lane-live-smoke.md` 中的 `2026-05-10 VEL-034 Memory Lane Live Data Smoke`，已确认 MEM lane `17G` / `1.7G` 来自 live memory provider，且不显示 cached files 或字段名。fullscreen 或多显示器 smoke 仍必须另开 approval 任务。

### Mock Overlay Visual Smoke

这条 smoke 用于只验证本地 mock telemetry 的 notch capsule 视觉，不启动 live telemetry。

执行前必须重新请求用户 approval。建议 approval 问法：

```text
我需要确认：这次 smoke 会启动 Veil mock notch capsule overlay 约 30-60 秒，只使用本地 mock telemetry 验证 320 x 32 和 VPN/MEM/CPU 三 lane 轮换；不会启动 live telemetry，不会执行 Mullvad CLI、ping、TCP timing、网络探测，也不会读取真实 CPU 温度。是否继续？
```

只有用户明确同意后，才可以运行：

```sh
swift run Veil -- --mock-telemetry defaultCompact --no-mullvad-approval-prompt
```

运行中检查：

- HUD 保持 `320 x 32` notch capsule。
- mock fixture 内容为 `FRA 23ms`、`18G 2.1G`、`18% OK`。
- notch capsule 按 `3s` 周期在 MEM / CPU / NET lane 间轮换；approved advanced/private lane 只在显式启用后追加。
- 不显示 `VPN` / `RAM` / `MEM` / `SWAP` / `CPU` / `LOAD` 字段名。
- CPU lane 右侧来自 thermal pressure；unknown 时显示 `--`。
- 不启动 live telemetry，不执行 Mullvad CLI、`ping`、TCP timing 或任何主动网络探测。

### CPU Temperature Read-Only Smoke

这条 smoke 不是默认流程，也不再作为 Phase 1 CPU lane 的右值来源。它只保留为 Celsius source 的失败边界记录：每次运行前都必须重新请求用户 approval，并说明会执行 Apple `powermetrics` 的 SMC sampler；该命令可能需要管理员权限或在当前 macOS 不受支持，失败时 CPU temperature 仍显示 `--`。

Phase 1 当前决策：CPU Celsius live data 暂缓。后续只读探索未找到 public、non-sudo、non-helper、non-private 的 Celsius CPU temperature 来源；CPU lane 右侧改为公开 `ProcessInfo.thermalState` 派生的 `OK` / `WARM` / `HOT` / `CRIT` / `--`，默认本机 dogfood 不应开启 `--approve-cpu-temperature-readonly`。

建议 approval 问法：

```text
我需要确认：这次 smoke 会启动 Veil live overlay 约 30-60 秒，并在本次运行内允许只读执行 Apple `powermetrics --samplers smc -n 1 -i 1000` 读取 CPU temperature；不会执行 Mullvad CLI、ping、TCP timing、网络探测，不会修改系统设置，也不会做 CPU 压力测试。是否继续？
```

只有用户明确同意后，才可以运行：

```sh
swift run Veil -- --deny-mullvad-readonly --no-mullvad-approval-prompt --approve-cpu-temperature-readonly
```

运行中检查：

- HUD 保持 `320 x 32` notch capsule。
- CPU lane 左侧显示 live busy CPU usage，约等于 Activity Monitor 的 `System + User`，即 `100% - Idle`。
- CPU Celsius 字段若 `powermetrics` 可用且有权限，可被 optional provider 填充；默认 notch CPU lane 右侧仍显示 thermal pressure，而不是摄氏温度。
- 温度采样低频缓存，不按每次 HUD refresh 反复执行 `powermetrics`。
- 如果 `powermetrics` 返回 `unrecognized sampler`、权限错误或其他永久不可用信号，本次 Veil 进程应停止重复尝试，并保持 CPU temperature 为 `--`。
- 不执行 Mullvad CLI、`ping`、TCP timing 或任何主动网络探测。
- 不做 CPU stress / health pressure test。

2026-05-10 CPU temperature opt-in smoke 记录：`docs/design/cpu-temperature-live-smoke.md`。本机观察到 Celsius path fail closed。直接诊断 `/usr/bin/powermetrics --samplers smc -n 1 -i 1000` 返回 `powermetrics: unrecognized sampler: smc`，因此真实 CPU temperature 未通过当前实现接入。后续来源探索确认 Phase 1 不硬接 sudo/private/helper 路径，默认 CPU lane 改用 thermal pressure。

## 5. Mullvad Read-Only Smoke

这条 smoke 不是默认流程。每次运行前都必须重新请求用户 approval，并引用 `docs/process/runtime-permissions.md` 和 `docs/process/mullvad-readonly-status-smoke-plan.md` 的红线。

建议 approval 问法：

```text
我需要先确认：这个 smoke 会启动 Veil notch capsule overlay 约 30-60 秒，并在本次运行内允许只读执行 `mullvad status`，若 Mullvad 已 connected，会对当前 relay 或 visible endpoint 做低频 3 包短 ping，并显示 packet median latency；不会 connect/disconnect/reconnect、不会切 relay、不会改 DNS/tunnel/route/proxy。是否继续？
```

只有用户明确同意后，才可以运行：

```sh
VEIL_MULLVAD_DIAGNOSTICS=1 swift run Veil -- --approve-mullvad-readonly --no-mullvad-approval-prompt
```

approval 范围：

- 只覆盖本次启动周期。
- 只覆盖 `mullvad status`。
- 若 Mullvad 已 connected，只覆盖对当前 relay 或 visible endpoint 的低频 3 包短 `ping`；HUD latency 使用 packet median。
- 不跨启动持久化。
- 不覆盖任何新命令类型。

红线：

- 不执行 `mullvad connect`、`disconnect`、`reconnect`。
- 不切换 relay。
- 不修改 DNS、tunnel、route、proxy、防火墙或系统网络设置。
- 不执行 `mullvad relay list`，除非另开 approval 任务。
- 不做 TCP timing。
- 不查询公网 IP，不请求 IP echo 服务。
- 不做 Speedtest、fast.com、iperf 或吞吐压力测试。
- 不读取 Mullvad 账号、token、密钥、配置目录、日志目录或诊断包。
- 不重启 Mullvad App、daemon、system extension 或相关服务。

运行中只记录：

- 结构化状态，例如 connected / disconnected / error / unknown。
- HUD VPN lane 的短 location code，例如 `FRA`。
- latency 是否出现和值域；不记录完整 relay host 或 visible IP。
- 是否出现非预期 prompt。
- 是否观察到 Mullvad 状态变化。
- 停止和清理结果。

### Mullvad Read-Only Long Dogfood Gate

几天级本机试跑必须先通过一轮短 Mullvad read-only smoke，再启动 release dogfood。不要把“第一次 approved 运行”直接拉长到几天。

长跑前必须确认：

- 本次用户明确批准几天级 read-only dogfood。
- `swift build`、`swift test`、`swift build -c release` 通过。
- `pgrep -x Veil` 无输出。
- 短 smoke 已观察到 VPN lane 不再是 no-approval `--   --`，而是 approved path 的结构化状态，例如 `FRA   23ms`、`OFF   --`、`ERR   --` 或 `...   --`。
- 短 smoke 中没有非预期 prompt，没有 Mullvad 状态变化，没有网络/DNS/route/proxy 异常。

长跑允许范围：

- 只运行 release binary / 临时 `.app` bundle。
- 只使用本次运行参数 `--approve-mullvad-readonly --no-mullvad-approval-prompt`。
- 可选开启 `VEIL_MULLVAD_DIAGNOSTICS=1`，但记录必须保持脱敏：relay host 只能写 `relay_host`，visible IP 只能写 `visible_ipv4`。
- 只允许 `mullvad status` 和 connected 时当前 relay / visible endpoint 的低频 3 包短 `ping`；HUD latency 使用 packet median。
- 不允许 `mullvad relay list`，除非另开 approval。
- 不允许 TCP timing、公网 IP 查询、Speedtest、fast.com、iperf、traceroute、mtr 或其他新增网络探测。

长跑观察项：

- 进程 uptime、CPU、RSS。
- Veil 子进程是否只出现短生命周期 `mullvad status` 或 `/sbin/ping`。
- VPN lane 是否稳定显示短状态，不显示完整 relay host、visible IP、账号、配置、日志或诊断内容。
- 是否出现 `ERR`、`FLAP`、持续高 latency、CPU/RSS 漂移或窗口残留。
- 用户是否感知到网络、VPN、DNS、route、proxy 或桌面异常。

长跑停止条件：

- 用户要求停止。
- HUD 遮挡工作、抢焦点、位置异常或窗口残留。
- 出现任何未说明的系统 prompt。
- 观察到任何 Mullvad 状态变化、网络出口变化或疑似 mutating command。
- CPU、RSS 或子进程行为超过当前资源预算草案。

## 6. Fullscreen Smoke Checklist

Fullscreen smoke 必须是单独 approval 任务，不能夹在默认 no-approval smoke 里顺手做。

前置条件：

- 第 3 节前置检查全部通过。
- 用户确认当前可以进入 fullscreen App / Space。
- 本次只测试一个 fullscreen App 和一次进入/退出，不做完整矩阵。

最小步骤：

- 启动 no-approval smoke。
- 进入一个 fullscreen App。
- 观察 HUD 是否可见、是否抢焦点、是否遮挡关键 UI。
- 切回普通桌面。
- 退出 fullscreen。
- 停止 Veil 并完成清理。

通过标准：

- HUD 不抢焦点。
- HUD 不阻塞 fullscreen App 的关键交互。
- 退出 fullscreen 后 HUD 回到 notch capsule 位置。
- 停止后无 `Veil` 进程或窗口残留。

不在 Phase 1 fullscreen smoke 里做：

- 多 App / 多 Space 矩阵。
- 自动隐藏菜单栏矩阵。
- 外接显示器 fullscreen 矩阵。
- 修改 Space、Mission Control 或用户窗口布局。

## 7. 多显示器 Smoke Checklist

多显示器 smoke 必须是单独 approval 任务，不能夹在默认 no-approval smoke 里顺手做。

前置条件：

- 第 3 节前置检查全部通过。
- 用户确认当前可以连接、断开或切换外接显示器。
- 本次只验证目标屏定位和无残留窗口，不决定 Phase 2 的完整产品策略。

最小步骤：

- 启动 no-approval smoke。
- 确认 HUD 优先显示在有 notch / safe area 的目标屏。
- 在用户允许的情况下连接、断开或切换一次显示器配置。
- 等待一次屏幕参数变化恢复。
- 确认旧位置没有残留窗口，新位置合理。
- 停止 Veil 并完成清理。

通过标准：

- 同一时间只出现预期的 `Veil` HUD。
- HUD 不落到错误显示器的危险位置。
- 显示器变化后没有残留旧窗口。
- 停止后无 `Veil` 进程或窗口残留。

不在 Phase 1 多显示器 smoke 里做：

- selected screen 设置。
- show on all displays。
- 非刘海屏完整 fallback 设计。
- 外接显示器 fullscreen 矩阵。

## 8. Sleep/Wake 策略

Phase 1 local trial 采用 alpha 手动重启策略。

理由：

- 当前代码已监听屏幕参数变化并调用 `reposition()`。
- 当前代码还没有显式 `NSWorkspace` sleep/wake notification 恢复逻辑。
- 在没有实机 smoke 和恢复实现前，承诺自动 wake restore 风险过大。

Phase 1 alpha 操作规则：

- 试用期间如果机器 sleep、锁屏、合盖或显示器休眠，唤醒后先停止 Veil。
- 确认无残留 `Veil` 进程和窗口。
- 重新走第 3 节前置检查中的 `pgrep -x Veil` 和必要构建验证。
- 重新启动相同 smoke。

后续若要做最小 wake restore，应另开实现和 smoke 任务，范围只包含：

- 监听 wake / screen wake notification。
- wake 后执行 `hudController.reposition()`。
- wake 后触发一次 `refreshNow()`。
- 无 Mullvad approval 时仍不得执行 Mullvad CLI、`ping` 或主动网络探测。

## 9. 低资源预算草案

Phase 1 资源目标先作为 hardening 草案，后续用 no-approval idle smoke 校准。

预算：

- Idle CPU：release build、no-approval idle 5 分钟内，Veil 平均 CPU 目标不高于 `1%`，短峰值不高于 `5%`。
- RAM：RSS 目标不高于 `100 MB`；若 SwiftUI/AppKit 基线超过该值，记录实际基线并要求后续任务解释。
- HUD refresh：当前默认约 `5s` 一次，不为动画平滑提高刷新频率。
- Memory sample：跟随 HUD refresh，读取本机 VM / sysctl 指标。
- Network throughput sample：跟随 HUD refresh，只读取本机接口计数器，不主动制造流量。
- Mullvad status：只有 read-only approval 后才允许，当前节流约 `15s`。
- Latency probe：只有 read-only approval 且 connected 后才允许，当前节流约 `30s`，单点、短超时。
- 默认 no-approval smoke：禁止主动网络流量；不得执行 Mullvad CLI、`ping`、TCP timing 或公网请求。

资源 smoke 记录项：

- build mode: debug / release
- duration:
- CPU average / peak:
- RSS average / peak:
- refresh interval observed:
- active network probes: none for no-approval smoke
- cleanup confirmation:

## 10. 停止与清理流程

标准停止：

- 前台运行时使用 `Ctrl-C` 停止 `swift run`。
- 等待进程退出。
- 只做本地清理确认，不补跑 Mullvad CLI、`ping`、TCP timing 或网络探测。

清理确认：

```sh
pgrep -x Veil || true
```

通过标准：

- `pgrep -x Veil` 无输出。
- 若本次记录窗口状态，结束后 `CGWindowList` 中 `Veil` window 数为 `0`。

异常清理：

- 只终止本次 smoke 启动的已知 `Veil` PID。
- 不使用 `sudo`。
- 不杀死无关用户进程。
- 不重启 Mullvad、系统网络服务、WindowServer、Dock 或 Finder。

若无法确认残留进程是否属于本次 smoke，停止并询问用户。

## 11. 必须另开 Approval 任务的动作

以下动作不能夹在默认 smoke 或文档任务里顺手执行：

- 启动任何真实 overlay smoke，包括 no-approval overlay smoke。
- 执行 Mullvad read-only smoke。
- 直接运行 `mullvad status`、`mullvad relay list` 或任何 Mullvad CLI。
- 执行 `ping`、TCP timing、公网 IP 查询、Speedtest、fast.com、iperf、traceroute、mtr、端口扫描或任何新增网络探测。
- 进入 fullscreen、切换 Space、测试自动隐藏菜单栏或覆盖当前 fullscreen App。
- 连接、断开、切换外接显示器或改变主显示器。
- sleep/wake、锁屏、合盖、显示器休眠恢复 smoke。
- 长于 5 分钟的 idle resource smoke 或任何可能明显消耗 CPU、内存、电量的测试。
- 设置 login item、LaunchAgent、daemon、helper、开机启动、签名、notarization、安装包或系统权限。
- 任何可能改变 Mullvad、DNS、route、proxy、防火墙、VPN 出口或系统网络设置的动作。

## 12. 本任务非执行确认

VEL-027 编写本 runbook 时只读取代码、文档、测试并运行构建验证。未启动 Veil，未启动 overlay，未执行 Mullvad CLI，未执行 `ping`、TCP timing、公网 IP 查询、Speedtest 或任何网络探测。
