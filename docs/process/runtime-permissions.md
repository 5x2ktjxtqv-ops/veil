# Runtime Permissions Rules

状态：Hard Rules  
版本：v0.1  
日期：2026-05-20

## 1. 目的

本文给所有后续执行线程一份运行时权限硬规则。

Veil 是一个低干扰系统生命体征 HUD。任何开发、测试、调试或自动化执行都必须保护用户当前机器、当前网络出口、当前 VPN 状态和当前桌面会话。

默认原则：

- 只读优先。
- 低频优先。
- 本地优先。
- 不改变用户网络出口。
- 不接管用户输入。
- 不把测试行为伪装成产品行为。

## 2. 权限等级

### 可以直接执行

满足以下条件时可以直接执行：

- 只读。
- 本地。
- 不改变系统设置。
- 不改变 Mullvad 状态。
- 不主动向外部服务发起网络流量，或只发起产品已经定义的低频轻量探测。
- 不遮挡用户当前工作。
- 可随时停止。

例子：

- 读取源码和文档。
- 运行 Swift 编译或单元测试。
- 读取网络接口计数器。
- 读取内存、Swap、系统 uptime 等本地指标。
- 读取公开 host CPU load ticks 计算 CPU usage。
- 创建进程生命周期内的 IOKit power assertions，以保护 Veil 明确承载的后台任务不因 idle sleep 中断，前提是不修改系统电源设置、不要求 sudo、不阻止显示器熄灭。
- 启动 Veil 做短时间本地观察，前提是不会切换 VPN、不会打开设置页、不会进入交互 overlay 模式。

### 必须先问用户

满足任一条件时必须先问用户并说明影响：

- 会改变网络出口、VPN 状态、DNS、路由、防火墙或代理。
- 会向公网服务发起探测，而目标不是产品已定义的低频轻量探测。
- 会启动持续运行的后台进程或长时间常驻 App。
- 会覆盖、遮挡或抢占用户当前桌面、全屏应用、菜单栏或输入焦点。
- 会运行可能消耗明显 CPU、内存、网络或电量的命令。
- 会安装、升级、删除、授权或启动系统级组件。
- 会触发 macOS 权限弹窗。
- 会持久修改 macOS 电源策略，例如 `pmset`。
- 会读取或暴露公网 IP、VPN 出口 IP、真实地理出口或账号相关信息。
- 执行任何 Mullvad 状态读取或当前 relay 探测，包括 `mullvad status`、`mullvad relay list`、当前 relay `ping` 或 TCP timing。
- 执行任何真实 CPU temperature sensor 读取，包括 `powermetrics` SMC / thermal sampler 或其他 sensor API。

### 绝对禁止

以下操作无论是否方便调试，都禁止执行：

- 未经用户明确要求，断开、重连、切换或配置 Mullvad。
- 绕过 Mullvad 或主动寻找非 VPN 出口。
- 修改系统网络设置、DNS、路由表、防火墙、代理或 hosts。
- 跑满带宽或执行 Speedtest 类重型测速。
- 高频 ping、mtr、traceroute、端口扫描或批量节点测速。
- reverse engineering Mullvad。
- 读取、导出、打印或上传 Mullvad 账号、token、密钥、配置文件或日志中的敏感内容。
- 为了 overlay 测试强行抢占输入焦点、遮挡用户工作、关闭用户窗口或改变 Space。
- 使用私有框架或系统注入手段作为常规测试路径。
- 把天气、新闻、股票、社交通知、娱乐化 Dynamic Island 或大 Dashboard 引入运行测试范围。

## 3. Mullvad 红线

Veil 只观察 Mullvad 当前状态，不管理 Mullvad。

本节里的“必须先问用户”首先约束开发、测试、验收和自动化执行线程：这些线程每次直接执行 `mullvad`、当前 relay `ping` 或 TCP timing 前都必须单独确认。

产品运行时可以使用一次明确的 per-run approval，覆盖本次启动周期内已说明的低频只读状态读取和当前节点轻量探测。只有用户在 Veil approval prompt 中明确选择 remember 时，才允许持久化这一个 read-only approval；该持久化授权不得扩展到新命令类型，也不得被执行线程用来跳过逐次确认。

### Approval 后允许

获得明确 approval 后才可以执行：

- `mullvad status`
- 在代码中通过受控 `Process` 调用 `mullvad status`。
- 解析连接状态、国家、城市、relay、visible location。
- 在命令失败时返回 unknown/error。

谨慎允许：

- `mullvad relay list` 只可用于 approval 后的只读开发验证；如果输出过大、耗时或涉及额外网络请求，应再次问用户。

### 必须先问用户

以下操作必须先问用户：

- 运行任何可能改变 Mullvad 状态的命令。
- 查询、展示或记录可能暴露出口 IP、城市、账号状态或设备标识的信息。
- 重启 Mullvad App、daemon 或相关服务。
- 读取 Mullvad 配置目录、日志目录或诊断包。
- 增加对 Mullvad CLI 的新调用类型。

### 绝对禁止

以下操作禁止：

- `mullvad connect`
- `mullvad disconnect`
- `mullvad reconnect`
- `mullvad relay set ...`
- `mullvad tunnel set ...`
- `mullvad dns set ...`
- `mullvad lan set ...`
- `mullvad lockdown-mode set ...`
- `mullvad auto-connect set ...`
- `mullvad account ...`
- `mullvad logout`
- 删除或修改 Mullvad 配置、缓存、日志或 daemon 状态。
- 杀死、重启或替换 Mullvad daemon。
- 通过非官方接口、私有文件或内存检查 reverse engineering Mullvad。

判断规则：如果命令可能让用户的 VPN 从“当前状态”变成“另一个状态”，就不能执行。

## 3.1 Live Mode Safety Gate

VEL-014 固化 live mode 进入条件。进入真实 telemetry 前必须同时满足：

- 启动配置没有 `startupError`。
- `statusSignals.isEnabled == true`，即用户显式开启 `--status-signals` / `VEIL_STATUS_SIGNALS=1`，或启用了某个需要信号层的 adapter / approval。
- 当前不是 debug mock telemetry 路径。
- mock fixture 解析成功；未知 fixture 必须失败关闭并退出，不得回落到 live provider。
- `mullvadApproval` 的默认值必须是 `.notRequested`；默认启动不得弹出 Mullvad approval prompt。只有用户显式传入 `--prompt-mullvad-approval` / `VEIL_PROMPT_MULLVAD_APPROVAL=1`，或显式传入 approval / denial flag，才进入交互或已决策状态。只有用户在 Veil 的 approval prompt 中明确选择记住只读授权后，才可以持久化 approved 状态。持久化授权仍只覆盖已说明的 `mullvad status` 和当前 relay 低频短 `ping`，不得扩展到新命令类型；显式启动 denial 必须优先。当前路径速度小探针还必须额外通过 `--vpn-speed-probe` / `VEIL_VPN_SPEED_PROBE=1` 显式开启。

默认启动只进入 visual module 路径，不进入 live telemetry 编排，也不得进入 Mullvad read path、private local endpoint polling、active HTTP probe、CPU temperature sensor read 或 power keep-alive。也就是说，在用户明确 opt in 前：

- 可以读取屏幕几何和必要的可见窗口 bounds，用于定位 overlay、底部圆角补偿和 fullscreen hide。
- 不得读取内存、Swap、本地网络接口计数器或公开 host CPU load ticks。
- 不得读取 task-status 文件。
- 只有用户显式启用 status signals 后，`TelemetryService.refresh` 才可以生成 local system snapshot 和 fallback VPN 状态。
- fallback VPN 状态必须保持 `approvalRequired` / `approvalDenied` 语义。
- notch capsule 的 no-approval VPN lane 只能显示受限短值，例如 `--   --`，不得显示 relay、城市、延迟、出口或任何真实 Mullvad 信息。
- VEL-034 Mullvad stability / flap detector 可以用 mock status、parser fixture 或注入的 `ProcessRunning` fake 做单元测试；这些测试不得 shell out 到真实 `mullvad`、`ping`、TCP timing、公网 IP 查询或其他网络探测。
- VPN lane 只允许从已授权读路径或 mock/parser 数据得出稳定性表达：healthy `FRA   312M`、idle probe `FRA   IDLE`、probe timeout `FRA   TMO`、probe network error `FRA   NET`、probe HTTP error `FRA   HTTP`、disconnected `OFF   --`、flapping `FLAP   3x`、connecting `...   --`、restricted `--   --`、CLI/error `ERR   --`。
- 不得执行 `mullvad status`、`mullvad relay list`、`ping`、TCP timing 或其他主动网络探测。
- 不得执行 `powermetrics` 或其他真实 CPU temperature sensor 读取，除非本次启动显式 `--approve-cpu-temperature-readonly`。
- 如果 approved CPU temperature provider 发现当前系统不支持目标 sampler、权限不可用或命令失败，必须显示 `--` 并在本次进程内停止重复尝试已知永久失败路径。
- 只有用户显式启用 `--task-status-file` / `VEIL_TASK_STATUS_FILE` / `--task-status` 后，才可以读取一个已配置的本地 JSON task-status 文件。该路径只允许读取紧凑状态字段，不得扫描 terminal scrollback、Claude Code / Codex 内部文件、进程树、命令行参数、仓库路径或日志输出。
- 只有用户显式启用 `--long-run` / `VEIL_LONG_RUN=1` / `--power-keepalive` / `VEIL_POWER_KEEPALIVE=1` 后，才可以在 App 生命周期内持有 `PreventUserIdleSystemSleep`、`PreventDiskIdle`、`NetworkClientActive` power assertions，保护后台模型任务、磁盘读写和网络/VPN 依赖会话。不得为此创建 `PreventUserIdleDisplaySleep` / display sleep assertion；屏幕可以熄灭。
- 默认 Power keep-alive 不得调用 `pmset`、`caffeinate` 子进程、sudo/helper、LaunchDaemon 或任何会持久修改系统电源策略的路径。
- 只有用户明确要求系统级模式后，才可以通过 `--system-power-keepalive` / `VEIL_SYSTEM_POWER_KEEPALIVE=1` 进入 root-only `pmset` 路径。该路径必须先快照现有设置，必须保持 `displaysleep` 不变，必须定期验证并修复检测到的策略漂移，必须在正常退出时尽力恢复，不得修改 Mullvad、DNS、路由、防火墙或代理。
- 即使系统级模式开启，macOS 仍可能因低电量、热压力、硬件/固件限制或用户强制操作进入睡眠；产品文档必须保持这个边界。

debug mock telemetry 与 live telemetry 互斥：只要 `--mock-telemetry` 解析到有效 fixture，App 可以展示 mock snapshot，但不得启动 live refresh timer，也不得初始化真实 provider 路径。未知 fixture 必须报错退出，用于防止拼写错误悄悄跑进真实 telemetry。

## 4. 网络探测 Approval 规则

Veil 的网络探测目标是判断当前网络是否稳定，不是测速、诊断互联网或验证用户隐私。

### 可以直接执行

以下探测可以直接执行：

- 读取本地网络接口计数器。
- 基于相邻接口计数器计算轻量下载/上传估算。

获得明确 approval 后才可以执行：

- 产品代码内置的低频、单点、短超时延迟探测。
- 对当前 Mullvad relay host 的低频 ping，前提是只用于当前节点健康判断。
- 当前 Mullvad 已连接、且本次启动显式开启 `--vpn-speed-probe` / `VEIL_VPN_SPEED_PROBE=1` 后，产品代码内置的低频当前路径小 HTTP 探针：默认先请求 `https://www.gstatic.com/generate_204` 做可达性 canary，再请求 `https://ajax.googleapis.com/ajax/libs/jquery/3.7.1/jquery.min.js` 的前 `128KB` 估算当前用户路径下载速度。该探针默认 `5min` 间隔、`5s` 超时、失败退避 `1min -> 2min -> 5min`，不查询公网 IP，不并发扫目标，不跑满带宽，不切换 relay。

默认限制：

- 单次探测必须有超时。
- 探测频率必须低。
- 不允许并发扫多个目标。
- 不允许产生明显吞吐。
- 当前路径小 HTTP 探针必须有下载字节上限，默认不超过 `128KB`；如果检测到 VPN 隧道已有明显被动流量，应优先使用被动 `utun` 计数器而跳过主动下载。
- 失败时降级为 unknown，不反复重试。

### 必须先问用户

以下操作必须先问用户：

- 对公网 IP 回显服务发请求，例如查询当前出口 IP。
- 对 GitHub、OpenAI、API 服务、SSH host 或用户工作相关服务做 TCP timing。
- 对任意第三方域名执行 ping、curl、nc、dig、traceroute、mtr。
- 执行 packet loss 测试超过短窗口。
- 增加新的默认探测目标。
- 将探测结果写入文件、日志或 issue。
- 在用户主网络出口之外测试直连路径。

提问时必须说明：

- 探测目标。
- 探测方式。
- 预计持续时间。
- 是否会暴露出口 IP。
- 是否会产生可见网络流量。

### 绝对禁止

以下操作禁止：

- Speedtest、fast.com、iperf 或任何跑满带宽的吞吐测试。
- 批量 ping 多国家、多节点、多 relay。
- 端口扫描。
- 持续 traceroute/mtr。
- 高频探测以换取更平滑 UI。
- 绕过 VPN 直连测试。
- 向未说明的第三方服务发送探测。
- 把用户网络环境数据上传到外部服务。

## 5. 用户主网络出口保护原则

Veil 必须保护用户当前主网络出口。

硬规则：

- 不改变用户当前 VPN 连接状态。
- 不改变用户当前出口路径。
- 不绕过当前 Mullvad tunnel。
- 不为了调试打开直连网络。
- 不把真实 IP、VPN 出口 IP 或地理出口写进公开日志。
- 不用外部 IP echo 服务作为默认健康检查。
- 不把“网络慢”解释为需要切换节点或断开 VPN。

实现原则：

- 当前出口是什么，Veil 就观察什么。
- 网络异常只显示状态，不替用户做网络决策。
- 任何会改变出口的操作都属于用户决策，不属于 Veil 自动行为。

## 6. 本地进程启动规则

### 可以直接启动

以下本地进程可以直接启动：

- `swift build`
- `swift test`
- 短时间运行 `swift run Veil` 做手动验证。
- 只读 shell 命令，例如 `sysctl`、`vm_stat`、`ifconfig`、`netstat` 的只读用法。

限制：

- 必须能停止。
- 不得静默常驻。
- 不得抢占输入焦点。
- 不得改变系统设置。
- 不得改变 VPN、网络、DNS、代理或防火墙。

### 必须先问用户

以下本地进程必须先问用户：

- 长时间运行 Veil。
- 执行 `mullvad status`、`mullvad relay list`、当前 relay `ping` 或 TCP timing。
- 设置开机启动。
- 安装 LaunchAgent、daemon、helper、privileged helper。
- 启动会触发权限弹窗的测试。
- 启动会持续发送网络探测的测试。
- 启动会覆盖多个 Space、多个显示器或全屏 App 的 overlay 测试。
- 启动任何第三方 App、VPN App、系统设置 App 或自动化 UI 控制。

### 绝对禁止

以下操作禁止：

- 未经用户要求创建后台常驻进程。
- 未经用户要求写入 LaunchAgents、LaunchDaemons。
- 未经用户要求提升权限、sudo、安装 helper。
- 杀死用户工作进程。
- 关闭用户窗口、退出用户 App、切换用户 Space。
- 为了测试清空系统缓存、重启系统服务或重启机器。

## 7. Fullscreen / Overlay 测试规则

Overlay 测试容易干扰用户当前桌面，必须保守。

### 可以直接测试

以下测试可以直接执行：

- 编译 overlay 相关代码。
- 启动短时间 Veil，观察 HUD 是否出现。
- 读取窗口定位、屏幕参数和日志。
- 在当前桌面验证 click-through，前提是不抢占焦点、不改变用户窗口。

### 必须先问用户

以下测试必须先问用户：

- 进入或退出 fullscreen。
- 打开全屏视频、全屏 IDE、全屏浏览器或全屏游戏。
- 改变显示器排列、主显示器、缩放、菜单栏设置。
- 插拔、启用、禁用外接显示器。
- 在所有显示器上显示 overlay。
- 临时关闭 click-through。
- 打开 hover 展开或可交互 overlay。
- 改变 overlay window level 到更高层级。

### 绝对禁止

以下操作禁止：

- 强行切换用户当前 Space。
- 强行退出用户 fullscreen App。
- 强行遮挡用户正在使用的菜单栏、会议、屏幕共享或录屏。
- 模拟大量鼠标/键盘事件控制用户桌面。
- 使用私有窗口空间管理作为默认测试路径。
- 让 overlay 成为 key/main window，除非用户明确要求测试交互模式。

## 8. 日志与输出规则

可以记录：

- provider 成功/失败状态。
- 采样耗时。
- unknown/error 降级原因。
- 本地窗口数量、屏幕数量、HUD 是否显示。

必须脱敏：

- IP 地址。
- relay 完整名称，如果它能唯一标识用户偏好。
- 真实地理出口。
- 用户主机名。
- 本地用户名。
- 网络接口硬件地址。

禁止记录：

- Mullvad 账号、token、密钥。
- 原始配置文件。
- 完整诊断包。
- 可公开识别用户网络出口的日志。
- 用户网络请求内容。

## 9. 执行线程提问模板

当必须先问用户时，执行线程应使用简短、具体的问题：

```text
我需要先确认：这个测试会对 <目标> 执行 <方式>，持续约 <时间>，可能产生 <影响>。是否继续？
```

例子：

```text
我需要先确认：这个测试会对 1.1.1.1 执行 20 秒 ping，用来观察 packet loss，可能暴露当前 VPN 出口并产生少量网络流量。是否继续？
```

```text
我需要先确认：这个测试会临时关闭 click-through，让 HUD 接收鼠标 hover，可能短暂影响菜单栏附近点击。是否继续？
```

## 10. 违规处理

如果执行线程发现自己即将违反本文规则：

1. 立即停止该动作。
2. 不尝试绕过限制。
3. 向用户说明需要确认的原因。
4. 等待用户明确同意后再继续。

如果已经发生可能影响用户网络或桌面的行为：

1. 立即停止新动作。
2. 说明发生了什么。
3. 说明是否改变了 Mullvad、网络出口、系统设置或 overlay 状态。
4. 不自行执行进一步修复，除非修复动作是只读或用户明确要求。

## 11. 快速判定表

| 操作 | 结论 |
| --- | --- |
| `mullvad status` | 必须先问；approval 后只读执行 |
| `mullvad relay list` | 必须先问；approval 后谨慎只读验证 |
| `mullvad connect/disconnect/reconnect` | 绝对禁止 |
| 切换 Mullvad relay | 绝对禁止 |
| Mullvad parser / flap detector mock tests | 可以直接执行；不得 shell out |
| 读取接口计数器 | 可以直接执行 |
| 单点低频 relay ping | 必须先问；approval 后只读探测 |
| ping 第三方服务 | 必须先问 |
| 当前路径小 HTTP 探针 | 必须已有 Mullvad approval，且显式 `--vpn-speed-probe`；默认 5min、128KB 上限 |
| Speedtest / iperf | 绝对禁止 |
| 查询公网出口 IP | 必须先问 |
| 修改 DNS / 路由 / 代理 | 绝对禁止 |
| `swift build` / `swift test` | 可以直接执行 |
| 短时间运行 Veil | 可以直接执行 |
| 长时间常驻 Veil | 必须先问 |
| 设置开机启动 | 必须先问 |
| 安装 daemon/helper | 必须先问；若需提权则默认不做 |
| 普通 overlay 显示测试 | 可以直接执行 |
| fullscreen overlay 测试 | 必须先问 |
| 临时关闭 click-through | 必须先问 |
| 强行切换 Space 或退出用户 App | 绝对禁止 |

## 12. 最终原则

Veil 可以观察系统生命体征，但不能替用户操纵系统生命线。

Mullvad、网络出口、桌面焦点和全屏工作流都属于用户控制面。Veil 的执行线程只能在明确边界内低扰动观察；一旦可能改变状态、暴露出口或打扰当前工作，就必须先问。
