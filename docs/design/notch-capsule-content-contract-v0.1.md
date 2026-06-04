# Notch Capsule Content Contract v0.1

状态：Updated by VPN path speed probe decision
编号：VEL-022 / VEL-030 / VEL-032 / VEL-034 / CPU temperature opt-in
日期：2026-05-20

## 1. 范围

本文件定义 Phase 1 notch capsule 的 opt-in status signal 内容契约。公开基础轮换不再使用个人 VPN 偏好，而是本地普适信号 lane 每 `3s` 轮换。

本合约使用 mock / render / tests 收敛，并允许 live path 使用公开 host CPU load tick delta 计算 CPU usage。默认路径不要求授权 Mullvad，不执行 Mullvad CLI，不做 ping / TCP timing / 公网 IP 查询 / Speedtest，也不读取真实 CPU 温度传感器，不读取 task-status 文件，不创建 power assertions。VPN path speed 小探针必须已有 Mullvad approval 且显式 `--vpn-speed-probe` 开启；否则右值只使用被动隧道计数器或 `--`。CPU 摄氏温度在 Phase 1 暂缓；CPU lane 右值改为公开 `ProcessInfo.thermalState` 派生的 thermal pressure 短状态。

## 2. 内容契约

常态 lane 顺序和文案固定为：

```text
MEM lane:  18G   2.1G
CPU lane:  18%   OK        # live path thermal pressure nominal
CPU lane:  18%   WARM      # live path thermal pressure fair
CPU lane:  18%   HOT       # live path thermal pressure serious
CPU lane:  18%   CRIT      # live path thermal pressure critical
CPU lane:  18%   --        # thermal pressure unknown
NET lane:  100M  2M        # passive download / upload counters
VPN lane:  FRA   312M      # advanced/private adapter, only after explicit approval
```

规则：

- 轮换周期：`3s`。
- 公开基础 Lane 顺序：MEM -> CPU -> NET -> MEM。
- `task-status-file` 不加入基础轮换；它只驱动左侧小灯。
- `Long Run` / power keepalive 不加入基础轮换；它只驱动右侧小灯。
- Advanced/private lane 只在显式启用后追加到公开基础 lane 之后，例如 approved Mullvad 的 VPN lane。
- 左侧是主体值，右侧是质量/压力值。
- 不显示 `VPN` / `RAM` / `MEM` / `SWAP` / `CPU` / `LOAD` / `NET` 字段名。
- 中间 notch void 永远为空，不承载文字、图标、状态点或 live data。
- CPU usage 在 live path 中来自公开 host CPU load tick delta。CPU lane 左侧显示 busy CPU，也就是 `user + system + nice`，等价于 `100% - idle`；不拆分显示 `System` / `User` / `Idle`。
- CPU 摄氏温度默认 unavailable，Phase 1 不把 sudo/private/helper 路径接入默认产品。CPU lane 右侧显示 thermal pressure，不假装显示摄氏温度。
- 如果 thermal pressure unknown，CPU lane 显示：

```text
18%   --
```

VPN lane 的稳定性 fallback 文案固定为：

```text
connected healthy:     FRA    312M
connected idle:        FRA    IDLE
connected slow:        FRA    420K   # right value warning
connected timeout:     FRA    TMO    # right value warning
connected network err: FRA    NET    # right value warning
connected HTTP err:    FRA    HTTP   # right value warning
connected degraded:    FRA    72M    # lane warning；latency / node-health degraded
disconnected:          OFF    --
flapping:              FLAP   3x
connecting transient:  ...    --
approval/no approval:  --     --
CLI unavailable/error: ERR    --
```

## 3. Lane 语义

| Lane | 左侧主体值 | 右侧质量/压力值 | 数据来源 |
| --- | --- | --- | --- |
| MEM | used memory，不含 cached files，例如 `18G` | swap used，例如 `2.1G`；未知为 `--` | `MemoryStatus` |
| CPU | busy usage，例如 `18%`，约等于 Activity Monitor 的 `System + User` | thermal pressure：`OK` / `WARM` / `HOT` / `CRIT`；unknown 为 `--` | `CPUStatus`；live usage 来自 `CPUUsageSampler`，thermal pressure 来自公开 `ProcessInfo.thermalState` |
| NET | passive download，例如 `100M` | passive upload，例如 `2M`；未知为 `--` | `NetworkThroughput`，来自本地接口计数器 |
| VPN | location，例如 `FRA` | 当前 VPN path speed，例如 `312M` / `IDLE` / `TMO` / `NET` / `HTTP`；未知为 `--` | Advanced/private adapter；`VPNStatus.pathSpeed`，来自低频小 HTTP 探针或被动 `utun` 计数器 |

小灯语义：

| Indicator | 来源 | 状态 | 颜色 |
| --- | --- | --- | --- |
| Left | task-status file | running | yellow pulse |
| Left | task-status file | succeeded | green steady |
| Left | task-status file | failed | red fast pulse |
| Left | task-status file | attention / stale / unknown | yellow fast pulse |
| Right | Long Run keepalive | asserted / verified | green steady |
| Right | Long Run keepalive | degraded | yellow pulse |
| Right | Long Run keepalive | failed | red fast pulse |

异常或受限状态也不得重新引入字段名。例如 Mullvad approval denied / required 时，VPN lane 使用短 fallback 值 `--   --`，而不是 `VPN --`。

VPN lane 不再只按 connected/off 二分，而是读取 `VPNStatus.stability`：

- `connectedHealthy`：左侧显示城市/国家短码，右侧显示当前 VPN path speed。
- `connectedDegraded`：仍显示城市/国家短码和当前 VPN path speed，但 lane severity 为 warning；latency 继续作为内部 node-health 信号。
- `pathSpeed.idle`：右侧显示 `IDLE`，muted，表示当前还在节点变化后的初始等待期或没有足够样本。
- `pathSpeed.slow`：右侧显示速度值，例如 `420K`，warning。
- `pathSpeed.failed`：右侧按失败原因显示 `TMO` / `NET` / `HTTP`，warning；该状态只表示小探针失败，不表示 Mullvad 已断线。
- `connectingTransient`：显示 `...   --`，不伪造成已连接。
- `disconnected`：显示 `OFF   --`，critical。
- `approvalRequired` / `approvalDenied`：显示 `--   --`，不得显示真实 relay、城市、延迟或出口。
- `cliUnavailableOrError`：显示 `ERR   --`。
- `flapping`：显示 `FLAP   Nx`，其中 `N` 是 rolling window 内的连接状态 transition 次数。

MEM lane 只显示 `usedBytes` / `swapUsedBytes`。`cachedFilesBytes` 是可回收内存上下文，只用于 pressure 判断或 future expanded view；不得作为第三个 notch 值显示，也不得混入左侧 used。

## 4. 健康状态颜色

notch capsule 的数值必须同时携带健康语义：

- 白色 / normal：当前状态正常，可以忽略。
- 黄色 / warning：持续偏高、性能退化或需要用户处理。
- 红色 / critical：明确异常或高风险状态。
- 灰色 / muted：值不可用、未知，或用户明确选择的受限路径。

Lane 规则：

| Lane | 白色 | 黄色 | 红色 | 灰色 |
| --- | --- | --- | --- | --- |
| MEM | memory pressure normal | memory pressure elevated | memory pressure high | unknown value |
| CPU | usage health normal；thermal `OK` | usage sustained high；thermal `WARM` / `HOT` | usage sustained critical；thermal `CRIT` | usage unavailable；thermal unknown |
| NET | passive counters available | reserved | reserved | unknown value |
| VPN | connected 且 path speed 正常 | latency degraded、node degraded、flapping、path speed slow、path speed failed、CLI unavailable/error | disconnected | approval required / approval denied / no-approval expected fallback、unknown value、path speed idle |

CPU live health 使用持续窗口和回落滞后，避免瞬时尖峰导致 HUD 频繁变色：

- warning enter：usage `>= 80%` 持续 `15s`。
- warning exit：usage `<= 65%`。
- critical enter：usage `>= 95%` 持续 `15s`。
- critical exit：usage `<= 85%`，先回到 warning；`<= 65%` 后回到 normal。
- CPU lane 左侧 usage 是 primary CPU value，只按 CPU usage health 上色。右侧 thermal pressure 独立按自身状态上色：`WARM` / `HOT` 为 warning，`CRIT` 为 critical，`OK` 为 normal。Lane severity 仍取 usage 与 thermal pressure 的较高严重度。`WARM` 来自公开 `ProcessInfo.thermalState == .fair`，不由左侧 CPU usage 百分比直接触发。

## 5. 几何

VEL-030 曾将默认 notch capsule 从 `420 x 32` 收缩到 `292 x 32`。VEL-031 follow-up 发现 `292 x 32` 的右侧展示区会吃进物理刘海区域，因此当前 baseline 改为按内容展示需求计算出的 `320 x 32`。

代码锚点：

- `StatusHUDConfiguration.notchCapsule = 320 x 32`。
- `StatusHUDConfiguration.productionCompact = .notchCapsule`。
- `OverlayHUDController.notchSideOverhang = 70`，与 `180px` 默认 notch width 估算合成 `320px` 外框。
- 左右内容仍使用外侧视觉锚点：轮廓侧边 inset 为 `30px`，最小视觉边距为 `34px`。
- 布局先测量 MEM / CPU / NET 和已启用 advanced lane 的参考值与降级值的最大单侧展示宽度，并加入 `10px` 渲染安全余量；两侧使用同一展示宽度，左值贴左边距，右值贴右边距。
- 内部 `notchVoid` 映射必须为空；布局层保留最小空白缓冲，不靠把文本塞进中间区域解决拥挤。

## 6. 测试要求

测试必须覆盖：

- VPN lane：`FRA` / `312M`。
- VPN connected idle：`FRA` / `IDLE`。
- VPN path speed slow：`FRA` / `420K`，右值 warning。
- VPN path speed failed：`FRA` / `TMO`、`FRA` / `NET` 或 `FRA` / `HTTP`，右值 warning。
- VPN connected degraded：location / path speed 保持可读，lane 为 warning。
- VPN disconnected：`OFF` / `--`。
- VPN flapping：`FLAP` / `3x`。
- VPN connecting transient：`...` / `--`。
- VPN approval denied / no approval：`--` / `--`。
- VPN CLI unavailable/error：`ERR` / `--`。
- Mullvad stability classifier 覆盖 connected healthy、connected degraded、connecting transient、disconnected、approval/no approval、CLI unavailable/error、flapping。
- Mullvad flap detector 使用 rolling window 计算 transition count，并用 enter / exit hysteresis 防止单次恢复就立刻清除 flapping。
- MEM lane：`18G` / `2.1G`。
- MEM lane 左侧来自 `usedBytes`，不包含 cached files；右侧来自 `swapUsedBytes`。
- CPU lane：`18%` / `OK`。
- CPU thermal pressure：`OK` / `WARM` / `HOT` / `CRIT` / `--`。
- CPU usage 左值是 busy CPU：`user + system + nice` / total，等价于 `100% - idle`。
- CPU thermal pressure unknown：`18%` / `--`。
- live telemetry 可注入 CPU provider；status-signal live provider 填充 usage 和 thermal pressure，不填充 Celsius temperature。
- approved CPU temperature provider 执行 `powermetrics --samplers smc`，有超时、低频缓存、永久不可用失败保护和 parser 测试；测试不得执行真实传感器命令。
- CPU usage health：normal / warning / critical / muted role 映射。
- CPU sustained high / critical 阈值和回落滞后。
- MEM pressure elevated / high role 映射。
- VPN approval required / denied 都使用 muted fallback；未启用个人 VPN adapter 不应在公开默认态制造 warning。
- 所有 notch lane metric label 为空，且 value 不包含字段名。
- `notchVoid` 始终为空。
- production default 使用 `320 x 32` notch capsule，不回退到 compact / expanded。
- rotation interval 为 `3s`，公开基础 lane 顺序为 MEM -> CPU -> NET。
- task-status file 只驱动左侧 indicator，不扩展 lane rotation。
- Long Run keepalive 只驱动右侧 indicator，不扩展 lane rotation。
- task-status failed 进入整体 critical severity；attention / stale / unknown 进入 warning severity。
- Long Run degraded / failed 进入整体 warning / critical severity。

## 7. 保留项

以下内容仍不进入 Phase 1 常驻 notch capsule：

- download throughput 之外的额外测速解释。
- relay name。
- 长地名。
- 解释性文案。
- 绿色常亮状态点。
- 私有 SMC/IOKit 温度读取。

Full HUD / expanded preview 可以继续展示完整字段，用作 future expanded reference；它不反向改变本契约。
