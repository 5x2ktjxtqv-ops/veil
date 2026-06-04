# Memory Vitals Module Spec

状态：Draft  
编号：VEL-004  
日期：2026-05-06

## 1. 目标

内存生命体征模块用于判断当前机器是否进入会影响工作体验的内存压力状态。

它不是完整系统监控面板，也不追求解释 macOS 内存管理的所有细节。Phase 1 只需要稳定、低成本地提供三个判断信号：

- 当前 RAM 使用量。
- 当前 Swap 使用量。
- 简化内存压力等级。

核心目标：用户能通过刘海附近的低信息密度 HUD 判断卡顿、构建变慢、编辑器无响应或 AI 流式响应变慢是否可能来自内存压力。

## 2. 范围

### 必须做

- 低频采样 RAM 使用量。
- 低频采样 Swap 使用量。
- 输出结构化 `MemoryStatus`。
- 提供 `NORMAL`、`ELEVATED`、`HIGH` 三档压力等级草案。
- 默认态只显示 RAM。
- 展开态显示 RAM、Swap 和压力等级。

### 不做

- 不设计图表。
- 不做历史曲线。
- 不做 iStat Menus 式详细面板。
- 不展示进程级内存排行。
- 不做内存清理按钮。
- 不诱导用户手动释放内存。
- 不把内存模块扩展成 Activity Monitor 替代品。

## 3. 采样 API 候选

Phase 1 优先使用 macOS 原生 API，不引入第三方依赖。

### `host_statistics64`

用途：

- 获取 Mach VM 统计。
- 读取 page 级别计数，例如 free、internal、external、purgeable、wired、compressed 等可用字段。
- 为 RAM 使用量和压力启发式提供基础数据。

使用边界：

- 只在 `MemoryProvider` 内调用。
- 不在 SwiftUI View 中直接调用。
- 采样失败时返回 unknown 或沿用上一份可解释状态，不制造假健康数据。

### `vm_statistics64`

用途：

- 作为 `host_statistics64` 返回的核心数据结构。
- 用于计算 RAM 使用量和可回收内存上下文。
- 用于观察 compressed pages、pageins、pageouts、swapins、swapouts 等压力相关信号。

使用边界：

- Phase 1 不要求完全复刻 Activity Monitor 的内存压力算法。
- 字段解释以 Darwin/Mach 实际可用字段为准，开发时需要对不同 macOS 版本做轻量兼容检查。

### `sysctl vm.swapusage`

用途：

- 获取当前 Swap 使用量。
- 输出展开态中的 `SWAP 2.1G`。
- 作为压力判定的重要输入。

使用边界：

- 通过 `sysctlbyname("vm.swapusage")` 读取。
- 读取失败时 Swap 显示为 unknown，不影响 RAM 显示。
- 不通过 shell 执行 `sysctl` 命令采样，避免额外进程开销。

### `ProcessInfo`

用途：

- 获取物理内存总量，例如 `ProcessInfo.processInfo.physicalMemory`。
- 提供系统级上下文，辅助计算 RAM 使用量和使用比例。

使用边界：

- `ProcessInfo` 可作为总内存来源的简洁首选。
- 如果后续发现兼容性或精度问题，可与 `sysctlbyname("hw.memsize")` 互相校验。

## 4. 数据模型

建议模型：

```swift
struct MemoryStatus {
    let usedBytes: UInt64?
    let totalBytes: UInt64?
    let cachedFilesBytes: UInt64?
    let swapUsedBytes: UInt64?
    let pressure: MemoryPressure
    let sampledAt: Date
}

enum MemoryPressure {
    case normal
    case elevated
    case high
    case unknown
}
```

模型原则：

- provider 输出数值和 enum，不输出 UI 字符串。
- UI 层负责把 bytes 格式化成 `18G`、`18.2G`、`2.1G`。
- unknown 是合法状态，不用 `0` 伪装未知数据。
- 不保存长历史序列；最多允许保留上一轮采样用于判断趋势。

## 5. 计算规则

### RAM 使用量

Phase 1 显示的 `RAM 18G` 表示估算已用物理内存，不包含 cached files。

当前实现采用 Activity Monitor-like 口径：

```text
app-ish memory = internal - purgeable
used = app-ish memory + wired + compressed
cached files = external + purgeable
available = free + cached files
```

边界：

- free pages 视为未使用。
- external / purgeable 视为 cached files / reclaimable，不直接计入 HUD 左侧 used。
- compressed / wired / app-ish memory 计入 HUD 左侧 used。
- 如果 `purgeable > internal`，app-ish memory 按 `0` 处理，避免下溢。
- 如果估算 used 超过物理内存总量，按 total cap 到物理内存总量。

取舍：

- Veil 不承诺与 Activity Monitor 数字逐字一致。
- Veil 只要求趋势稳定、异常可见、显示不跳动。
- 为避免一位小数频繁闪动，默认态可四舍五入到整数 GB。

### Cached Files

`cachedFilesBytes` 是可回收内存上下文，不进入 `320 x 32` MEM lane 显示。

用途：

- 参与 `available = free + cached files` 的压力判断。
- 后续 expanded view 可以展示 cached files，但不能反向改变 notch capsule 的双值契约。
- 不把 cached files 同时计入 displayed used 和 pressure available，避免显示和颜色语义互相打架。

### Swap 使用量

`SWAP 2.1G` 来自 `vm.swapusage` 的 used 值。

格式规则：

- 小于 10GB 时保留一位小数，例如 `2.1G`。
- 大于等于 10GB 时默认显示整数，例如 `12G`。
- unknown 时展开态可显示 `SWAP --`。
- 默认态不显示 Swap，除非后续产品规则决定异常时提升展示优先级。

## 6. Pressure 判定策略草案

Phase 1 使用启发式压力等级，不复刻 macOS 私有内存压力算法。

### 输入信号

压力判定可组合以下信号：

- RAM 使用比例。
- Swap 使用量。
- Swap 增长趋势。
- compressed memory 比例。
- pageout 或 swapout 是否在相邻采样间增加。

### 初始分级

`NORMAL`：

- Swap 使用量接近 0，或长期稳定在很小范围。
- RAM 使用比例未接近物理上限。
- 相邻采样中 pageout / swapout 没有明显增加。

`ELEVATED`：

- RAM 使用比例较高。
- Swap 已经出现，或 compressed memory 明显增加。
- 相邻采样中 pageout / swapout 有增长，但未持续恶化。

`HIGH`：

- Swap 使用量较高，或短时间内持续增长。
- pageout / swapout 在连续采样中增加。
- RAM 使用比例接近物理上限，并伴随明显压缩或换页信号。

`UNKNOWN`：

- 关键采样 API 失败。
- 数据不完整，无法可靠判断压力。

### 建议阈值

VEL-034 后，Phase 1 先按 24GB MacBook Air 本机试用口径固定以下启发式阈值。它不复刻 macOS 私有 memory pressure 算法，只用于 HUD normal / elevated / high 映射：

| 等级 | 草案条件 |
| --- | --- |
| `NORMAL` | swap used < 2GB，available / total >= 15%，且没有 compressed + low-available corroboration |
| `ELEVATED` | swap used >= 2GB，或 available / total < 15%，或 compressed / total >= 25% 且 available / total < 25% |
| `HIGH` | swap used >= 4GB，或 available / total < 8%，或 compressed / total >= 30% 且 available / total < 15% |

判定原则：

- 多信号共同出现时向更高压力等级升级。
- 当前实现先做单次采样阈值判断；持续窗口和回落滞后可在资源 smoke 后追加。
- 阈值是产品启发式，不是系统真理，允许在 Phase 1 实测后调整。

## 7. 显示格式

### 默认态

默认只显示 RAM：

```text
RAM 18G
```

默认态原则：

- 一眼可读。
- 不显示图表。
- 不显示解释性文案。
- 正常状态保持安静。

### 展开态

展开态显示 RAM、Swap 和压力等级：

```text
RAM 18G / SWAP 2.1G / PRESSURE NORMAL
```

展开态原则：

- 只补充诊断信息。
- 不加入进程列表、图表、历史曲线或详细分页。
- Phase 1 不要求实现 hover 展开，但数据模型和格式应为后续展开态预留。

### 异常提示

当压力为 `HIGH` 时，UI 可以提升内存模块可见度，但仍保持克制。

允许：

- 文本状态从 `RAM 18G` 切换为更明确的异常表达，例如后续设计中的 `MEM HIGH`。
- 使用少量状态色。

不允许：

- 大面积动画。
- 弹窗警告。
- 图表面板。
- 强制展开详细视图。

## 8. 轮询策略

内存模块必须低频轮询，避免监控本身造成高 CPU 或电量负担。

建议策略：

- 常规采样间隔：5 秒。
- HUD 渲染只在 snapshot 变化时更新。
- App 启动后立即采样一次，随后进入 timer。
- 从睡眠唤醒、屏幕恢复或网络状态恢复时允许额外采样一次。
- 采样必须在后台队列执行，回到 MainActor 后只提交 `MemoryStatus`。

节流原则：

- 不使用亚秒级内存采样。
- 不为了数字实时跳动而提高频率。
- 不在主线程执行 Mach/sysctl 读取。
- 不为每次 UI 刷新重新采样。
- 采样失败时记录降级状态，不进入紧密重试循环。

目标：

- 常驻时 CPU 影响接近不可感知。
- 内存模块自身不成为新的系统压力来源。
- 用户看到的是稳定生命体征，不是抖动的仪表盘数字。

## 9. 验收标准

文档验收：

- 明确列出采样 API 候选：`host_statistics64`、`vm_statistics64`、`sysctl vm.swapusage`、`ProcessInfo`。
- 明确默认显示格式：`RAM 18G`。
- 明确展开显示格式：`RAM 18G / SWAP 2.1G / PRESSURE NORMAL`。
- 包含 pressure 判定策略草案。
- 明确不设计图表。
- 明确不做 iStat Menus 式详细面板。
- 明确低频轮询策略，避免高 CPU。

实现验收：

- `MemoryProvider` 能在低频采样下输出 RAM、Swap 和 pressure。
- UI 默认态只展示低信息密度 RAM 文本。
- 展开态的数据格式已有清晰规则，即使 Phase 1 暂不实现展开交互。
- 采样失败不影响 HUD 存活。
- 内存采样不阻塞主线程。
