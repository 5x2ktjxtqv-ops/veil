# Mullvad Status Module Spec

状态：Draft  
编号：VEL-005  
日期：2026-05-20

## 1. 目标

Mullvad 状态模块用于判断当前 VPN 是否连接，以及当前节点是否足够健康，帮助用户解释 SSH、Remote Coding、GitHub、API 请求或 AI Streaming 变慢时是否可能与 VPN 有关。

本模块是只读状态采集模块，不是 VPN 控制器。

核心目标：

- 判断 Mullvad 当前是否 connected。
- 显示当前国家、城市或 relay。
- 对当前节点做轻量健康判断。
- 给出当前延迟和“我正在使用这个节点时”的轻量路径速度上下文。

非目标：

- 不管理 Mullvad。
- 不替代 Mullvad 官方 App。
- 不做全节点测速。
- 不做自动切换。
- 不做大规模 benchmark。

## 2. 权限与执行硬约束

所有 Mullvad 相关执行都必须走 approval，但 approval 的粒度分两层：

- 产品运行时：可以用一次明确的 per-run approval 覆盖本次启动周期内已说明的低频只读命令和当前节点轻量探测。
- 开发、验收或自动化执行线程：每次直接执行 Mullvad CLI、ping 或 TCP timing 前都必须单独问用户。

这里的“执行”包括：

- 执行 `mullvad` CLI。
- 执行用于 Mullvad 状态判断的 `ping`。
- 执行用于 Mullvad 状态判断的 TCP connect timing。
- 执行用于当前 VPN 路径速度估算的低频小 HTTP 探针。
- 执行任何会读取或推断当前 Mullvad/VPN 状态的外部命令。

硬性规则：

- 执行线程不得启动、停止、重启、切换 Mullvad。
- 执行线程不得运行任何会改变 VPN 状态的命令。
- 即使是只读命令，例如 `mullvad status`、`mullvad relay list`、`ping` 或 TCP 探测，也必须先处在有效 approval 范围内。
- 用户拒绝 approval 或当前环境无法请求 approval 时，模块必须返回降级状态，不得绕过权限规则。
- approval 请求必须明确列出将要执行的命令类别和目的。
- approval 不得被解释为允许写操作或状态修改操作。

默认安全立场：

- 不在后台静默执行 Mullvad CLI。
- 不在没有 approval 的情况下探测当前 relay。
- 不通过其他系统命令间接改变 VPN 状态。
- 不在失败后进入紧密重试循环。

## 3. 只读命令白名单草案

白名单只定义“可以在 approval 后执行”的候选命令，不表示可以无条件执行。

### Mullvad CLI

允许候选：

```text
mullvad status
mullvad relay list
```

用途：

- `mullvad status`：读取当前连接状态、国家、城市、relay 或 visible location。
- `mullvad relay list`：在必要时辅助解析 relay 元数据。

约束：

- 产品运行时必须先获得本次运行的 per-run approval；开发、验收或自动化执行线程仍需逐次问用户。
- `mullvad status` 是主要状态来源。
- 解析必须接受 verbose 多行输出，例如 `Connected` 后跟 `Relay:` 和 `Visible location:`。
- 解析必须接受 concise 单行输出，例如 `Connected to <exit-relay> in <city>, <country>`。
- multihop 输出如果包含 `via <entry-relay>`，当前节点健康探测只使用 exit relay；entry relay 不作为默认 ping target。
- 解析失败必须返回 structured error / unknown，不得为了补全 UI 而执行额外 Mullvad 命令。
- `mullvad relay list` 只能作为辅助数据源，不应每轮轮询都执行。
- `mullvad relay list` 结果不得用于全节点测速或节点排名。
- 命令必须设置超时。
- 命令失败时返回 fallback 状态，不触发写操作补救。

### 当前节点轻量探测

允许候选：

```text
ping <current-relay-host-or-ip>
TCP connect timing <current-relay-host-or-ip>:<current-service-port>
```

用途：

- 对当前正在使用或当前状态指向的节点进行轻量延迟探测。
- 只判断当前节点是否健康，不比较其他节点。

约束：

- 产品运行时必须先获得本次运行的 per-run approval；开发、验收或自动化执行线程仍需逐次问用户。
- 只能探测当前节点或当前状态明确指向的 endpoint。
- 不得遍历 relay list。
- 不得并发探测多个国家、城市或节点。
- 不得制造大流量。
- ping 必须限制次数和超时。
- Phase 1 approved probe 使用低频 3 包短 ping；如果 packet `time=` 样本可解析，HUD latency 使用 median，避免单个尖峰直接决定显示值；如果只拿到 summary，则回退到 avg。
- TCP 探测只做连接计时，不发送业务 payload。

### 被动吞吐估算

轻量吞吐估算优先使用系统接口计数器，例如 `getifaddrs` / `if_data` 一类原生 API。

约束：

- 吞吐估算是被动读数，不主动测速。
- 不使用 Speedtest。
- 不下载测试文件。
- 不把吞吐估算解释成运营商或 relay 的绝对带宽能力。
- 如果实现改为外部命令或主动网络探测，也必须先请求 approval。

### 当前路径小 HTTP 探针

允许候选：

```text
GET https://www.gstatic.com/generate_204
GET https://ajax.googleapis.com/ajax/libs/jquery/3.7.1/jquery.min.js
```

用途：

- 估算“用户当前通过这个 Mullvad 节点访问常见公网静态资源”的有效下载速度。
- 回答当前使用路径是否慢，而不是评价节点本身、国家线路或运营商上限。

约束：

- 产品运行时必须同时满足 Mullvad per-run approval 已通过，且本次启动显式开启 `--vpn-speed-probe` / `VEIL_VPN_SPEED_PROBE=1`。
- 默认先用 `generate_204` 做极小可达性 canary，再下载静态文件前 `128KB` 估算 Mbps。
- 默认探测间隔 `5min`，节点变化后延迟 `10s` 再探，失败退避 `1min -> 2min -> 5min`，单次超时 `5s`。
- 如果 `utun` 隧道被动吞吐已经大于阈值，应直接使用被动读数并跳过主动下载。
- 不查询公网 IP，不记录出口 IP，不绕过 VPN，不切换 relay，不并发探测多个目标。
- 不使用 Speedtest、fast.com、iperf 或任何跑满带宽的测试。
- 目标 URL 可通过 `VEIL_VPN_PROBE_URL` / `--vpn-speed-probe-url` 替换，但新增默认目标必须更新本规格和权限文档。

## 4. 禁止命令黑名单草案

黑名单原则：除白名单草案中列出的只读命令外，其他 `mullvad` 命令默认禁止。

明确禁止：

```text
mullvad connect
mullvad disconnect
mullvad reconnect
mullvad relay set ...
mullvad bridge set ...
mullvad tunnel set ...
mullvad dns set ...
mullvad lan set ...
mullvad auto-connect set ...
mullvad lockdown-mode set ...
mullvad split-tunnel ...
mullvad account login ...
mullvad account logout
mullvad factory-reset
```

也禁止任何等价的状态修改操作：

- 启动 Mullvad。
- 停止 Mullvad。
- 重启 Mullvad。
- 切换国家、城市或 relay。
- 修改 DNS、bridge、tunnel、LAN、split tunnel、auto-connect、lockdown mode。
- 登录、登出、重置账号或修改账号状态。
- 修改 Mullvad daemon、launch agent、system extension 或网络配置。
- 使用 `launchctl`、`kill`、`pkill`、`killall`、`open`、`networksetup`、`scutil` 等命令间接改变 Mullvad/VPN 状态。

实现规则：

- 黑名单优先级高于白名单。
- 如果命令无法被明确归类为只读，默认禁止。
- 如果参数中包含 `set`、`enable`、`disable`、`add`、`remove`、`delete`、`connect`、`disconnect`、`reconnect`、`login`、`logout`、`reset` 等状态修改语义，默认禁止。
- 任何“出错后尝试恢复 VPN”的行为都禁止。

## 5. 状态字段

建议模型：

```swift
struct VPNStatus {
    let connectionState: VPNConnectionState
    let country: String?
    let city: String?
    let relay: String?
    let latencyMilliseconds: Int?
    let lightweightThroughput: NetworkThroughput?
    let pathSpeed: VPNPathSpeed?
    let nodeHealth: VPNNodeHealth
    let errorReason: VPNStatusErrorReason?
    let sampledAt: Date
}

struct VPNPathSpeed {
    let downloadMbps: Double?
    let quality: VPNPathSpeedQuality
    let source: VPNPathSpeedSource
    let measuredAt: Date?
    let failureReason: VPNPathSpeedFailureReason?
}

enum VPNConnectionState {
    case connected
    case disconnected
    case connecting
    case error
}

enum VPNNodeHealth {
    case normal
    case degraded
    case unhealthy
    case unknown
}
```

字段说明：

- `connected / disconnected / connecting / error`：Mullvad 当前连接状态。
- `country`：当前出口国家或状态输出中的国家信息。
- `city`：当前出口城市，可为空。
- `relay`：当前 relay 名称或可读标识，可为空。
- `latencyMilliseconds`：当前节点轻量探测延迟，可为空。
- `lightweightThroughput`：被动吞吐估算，可为空。
- `pathSpeed`：当前用户路径速度，优先来自低频小 HTTP 探针；如果隧道正忙或探针关闭，则来自被动 `utun` 计数器；可为空。
- `nodeHealth`：当前节点健康判断，不代表全网节点质量。
- `errorReason`：fallback 原因，例如 CLI 不存在、命令超时、approval 被拒绝。

模型原则：

- provider 输出结构化字段，不输出 UI 字符串。
- UI 层只做简短格式化，例如 `FRA`、`312M`、`IDLE`、`TMO`、`NET`、`HTTP`。
- unknown 或 nil 是合法状态，不伪造健康数据。
- 不持久保存 relay 列表。
- 不保存长期延迟历史。

## 6. 当前节点健康判断

Mullvad 状态模块只回答一个问题：当前节点是否健康。

它不回答：

- 哪个节点最快。
- 哪个国家最佳。
- 是否应该切换节点。
- 全部 relay 的排名。

### 输入信号

当前节点健康判断可组合：

- `connectionState`。
- 当前国家、城市或 relay 是否可解析。
- 当前节点 latency。
- 轻量吞吐估算。
- 命令超时或探测超时。

### 初始分级

`normal`：

- 状态为 `connected`。
- 当前节点可解析。
- latency 在可接受范围内。
- 没有连续探测失败。

`degraded`：

- 状态为 `connected`，但 latency 偏高。
- 当前 relay 可解析但探测偶发失败。
- throughput 读数存在但无法说明网络正在顺畅传输。

`unhealthy`：

- 状态为 `connected`，但当前节点连续探测超时。
- latency 极高并持续出现。
- status 可读但当前节点健康信号持续失败。

`unknown`：

- VPN 未连接。
- approval 被拒绝。
- Mullvad CLI 不存在。
- 命令超时或解析失败导致无法判断。

建议阈值：

| 健康等级 | 草案条件 |
| --- | --- |
| `normal` | connected，latency < 400ms；或 relay 已知但 latency 暂不可测 |
| `degraded` | connected，latency 400ms-700ms |
| `unhealthy` | connected，latency >= 700ms |
| `unknown` | 未连接、无 approval、无 CLI、状态不可解析 |

判定原则：

- latency 只针对当前节点。
- throughput 是上下文，不是测速承诺。
- 低 throughput 不能单独证明节点异常，因为用户可能没有正在产生流量。
- 连续失败比单次失败更可信。
- 不因为节点不健康而自动切换。

## 7. 采样与轮询策略

采样必须低频、只读、approval-gated。

建议策略：

- `mullvad status`：常规间隔 10-30 秒，且只在本次运行 per-run approval 有效时执行。
- `mullvad relay list`：仅在解析当前 relay 元数据必要且被 approval 范围明确覆盖时执行；结果可短期缓存；开发、验收或自动化执行线程仍需逐次问用户。
- latency 探测：常规间隔不低于 30 秒，且只在本次运行 per-run approval 有效时执行。
- 当前路径小 HTTP 探针：默认不低于 5 分钟一次，节点变化后默认等待 10 秒；只有显式 `--vpn-speed-probe` / `VEIL_VPN_SPEED_PROBE=1` 才执行。
- throughput estimate：优先使用被动接口计数器，间隔 5 秒或与全局网络采样器一致。

节流原则：

- 不高频调用 Mullvad CLI。
- 不为了 UI 数字实时跳动而提高频率。
- 不把 `relay list` 放入每轮状态刷新。
- 不对多个 relay 并发探测。
- 不在命令失败后快速重试。
- 不在主线程执行 CLI 或网络探测。

approval 原则：

- 没有 approval 就不执行。
- approval 被拒绝就返回 fallback。
- approval 只覆盖明确说明的只读命令和探测。
- approval 不覆盖任何黑名单命令。
- 产品运行时可以用清晰的 per-run approval 覆盖本次启动周期内的低频只读轮询。
- 后台长期常驻、跨启动授权或新增命令类型需要产品层另行设计用户授权模型。
- 开发、验收或自动化执行线程不得把产品 per-run approval 当作跳过逐次确认的理由。

## 8. Fallback 策略

fallback 的目标是让 HUD 存活，并清楚表达“无法判断”，而不是通过写操作修复 VPN。

### Mullvad CLI 不存在

处理：

- 不尝试安装 Mullvad。
- 不启动 Mullvad 官方 App。
- 不执行替代管理命令。
- 返回 `connectionState = .error`。
- 设置 `errorReason = .cliMissing`。
- country、city、relay、latency 为空。
- nodeHealth 为 `unknown`。

显示建议：

```text
VPN --
```

或在展开态显示：

```text
VPN ERROR / CLI MISSING
```

### VPN 未连接

处理：

- 返回 `connectionState = .disconnected`。
- country、city、relay、latency 为空。
- nodeHealth 为 `unknown`。
- 不执行 `mullvad connect`。
- 不提示自动连接。

显示建议：

```text
VPN OFF
```

### 连接中

处理：

- 返回 `connectionState = .connecting`。
- country、city、relay 可为空或使用 status 中已有的部分信息。
- latency 为空。
- nodeHealth 为 `unknown`。
- 不催促、不重启、不重连。

显示建议：

```text
VPN ...
```

### 命令超时

处理：

- 停止等待当前只读子进程。
- 不重启 Mullvad。
- 不杀 Mullvad daemon 或官方 App。
- 返回 `connectionState = .error`。
- 设置 `errorReason = .timeout`。
- 如有上一份状态，可在内部标记 stale，但 UI 不应伪装成新鲜健康状态。

显示建议：

```text
VPN --
```

展开态可显示：

```text
VPN ERROR / TIMEOUT
```

### 无权限或用户拒绝 approval

处理：

- 不执行 `mullvad status`。
- 不执行 `mullvad relay list`。
- 不执行 ping。
- 不执行 TCP 探测。
- 返回 `connectionState = .error`。
- 设置 `errorReason = .approvalDenied` 或 `.approvalUnavailable`。
- nodeHealth 为 `unknown`。
- 不进入重试循环。

显示建议：

```text
VPN --
```

展开态可显示：

```text
VPN APPROVAL REQUIRED
```

### 解析失败

处理：

- 返回 `connectionState = .error`。
- 设置 `errorReason = .parseFailed`。
- 保留原始输出只用于本地调试日志，不进入 UI。
- 不通过 relay list 或其他命令无限补救。

### Relay list 不可用

处理：

- 不影响 `mullvad status` 的基本连接状态。
- 如果 status 已包含国家、城市或 relay，就使用 status 字段。
- 如果无法解析 relay 元数据，relay 为空，nodeHealth 根据已有信号降级为 `unknown` 或 `degraded`。
- 不为了补全 relay 信息做大规模命令调用。

## 9. UI 显示格式

默认态示例：

```text
VPN FRA
```

或带延迟：

```text
VPN FRA 312M
```

展开态示例：

```text
VPN FRA-WG / 23ms / 312M / HEALTH NORMAL
```

显示原则：

- 默认态优先显示连接状态和当前出口位置。
- latency 只在已获得 approval 并成功探测后显示。
- throughput estimate 是轻量上下文，不显示成 speedtest 结果。
- error 状态要可解释，但不抢夺过多 HUD 空间。
- 不显示 relay 列表。
- 不显示节点排名。
- 不显示国家选择器。
- 不显示切换按钮。

## 10. 验收标准

文档验收：

- 明确 CLI 只读命令白名单草案。
- 明确禁止命令黑名单草案。
- 明确状态字段：`connected`、`disconnected`、`connecting`、`error`、country、city / relay、latency、lightweight throughput estimate。
- 明确 fallback 策略：Mullvad CLI 不存在、VPN 未连接、命令超时、无权限或用户拒绝 approval。
- 明确目标是判断“当前节点是否健康”，不是全节点测速。
- 明确不做自动切换。
- 明确不做大规模 benchmark。
- 明确所有 Mullvad 相关执行都走 approval。

实现验收：

- 没有 approval 时不执行任何 Mullvad CLI、ping 或 TCP 探测。
- 任何黑名单命令都不能由 `MullvadProvider` 或执行线程发起。
- `MullvadProvider` 只输出结构化 `VPNStatus`。
- 当前节点异常只影响状态表达，不触发切换或修复。
- 命令失败、超时或解析失败不影响 HUD 存活。
- 采样和探测不阻塞主线程。
