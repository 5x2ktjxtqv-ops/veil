# Veil Visual Baseline v0.1

状态：Frozen for Phase 1, updated after CPU thermal pressure lane decision
编号：VEL-012 / VEL-020 / VEL-030 / VEL-031 follow-up / VEL-032 / CPU thermal pressure
日期：2026-05-10

## 1. 冻结结论

Phase 1 默认视觉方案仍是 `notch capsule` / 刘海延展胶囊。VEL-030 将内容模型改为三 lane rotating pair HUD；VEL-031 follow-up 又将默认宽度从 `292 x 32` 调整到按刘海空区和最大展示内容计算出的 `320 x 32`。

代码锚点：

- `StatusHUDConfiguration.productionCompact = StatusHUDConfiguration.notchCapsule`。
- `StatusHUDConfiguration.notchCapsule` 设计尺寸为 `320 x 32`。
- `OverlayHUDController.notchSideOverhang = 70`，与默认 `180px` notch width 估算合成 `320px` 外框。
- `NotchIslandStyle.nativeSoft` 仍是 Phase 1 默认刘海轮廓参数。
- 左右翼内容契约由 `notch-capsule-content-contract-v0.1.md` 冻结。

最终轮廓参数：

```text
screenCornerWidth: 4.5
screenCornerHeight: 5.5
screenCornerControl: 0.50
bottomCornerWidth: 14
bottomCornerHeight: 9
bottomCornerControl: 0.78
screenInsetWidth: 30
hardwareBlack: sRGB #000000
notchEdgeCoverageOpacity: 0.18
minimumVisualMargin: 34
referenceWingSafetyPadding: 2
current design size: 320 x 32
```

2026-05-20 official-image refinement: `docs/design/notch-island-apple-fit.md`
uses Apple's M4 MacBook Air product image plus the local `179pt` runtime notch
gap to tighten the visible four corners. The change reduces the lower
capsule-like curve without changing layout, data lanes, or indicator slots.

历史记录：

- VEL-012 smoke 观察 bounds 为 `(589, 0, 292, 32)`。
- VEL-020 曾按 location + latency 空间把默认宽度扩到 `420 x 32`。
- VEL-030 因内容改为同类双值 lane，恢复 `292 x 32` 作为默认候选。
- VEL-031 follow-up 发现 `292 x 32` 会让右侧内容吃进物理刘海区域，改为按 `180px` 刘海空区、`34px` 最小视觉边距和最大测量内容宽度计算 `320 x 32`。

## 2. 默认信息策略

notch capsule 每次只显示一条同类双值 lane：

```text
VPN lane:  FRA   312M
VPN lane:  FRA   IDLE  # path speed initial wait / no sample
VPN lane:  FRA   TMO   # path speed probe timeout
VPN lane:  FRA   NET   # path speed network error
VPN lane:  FRA   HTTP  # path speed HTTP status error
MEM lane:  18G   2.1G
CPU lane:  18%   OK
CPU lane:  18%   --    # thermal pressure unknown
```

轮换规则：

- 每 `3s` 切换一次。
- 公开基础顺序为 MEM -> CPU -> NET；approved advanced/private lane 追加在基础 lane 后。
- 左侧是主体值，右侧是质量/压力值。
- 不显示 `VPN` / `RAM` / `MEM` / `SWAP` / `CPU` / `LOAD` 字段名。
- CPU usage 在 live path 中由公开 host CPU load tick delta 提供；CPU 右值显示公开 `ProcessInfo.thermalState` 派生的 thermal pressure。摄氏温度只走 optional 数据模型，live default 不读取真实传感器。
- 数值颜色承载健康语义：normal 白色、warning 黄色、critical 红色、muted 灰色。
- CPU live usage 只有持续高负载才升级颜色：`>= 80%` 持续 `15s` 进入 warning，`>= 95%` 持续 `15s` 进入 critical；回落到 `<= 65%` 后恢复 normal。

中间刘海覆盖区始终保持纯黑视觉覆盖，不承载文字、图标、状态点或 live data。

## 3. 外侧锚点

VEL-031 后的边距 follow-up 保持外侧视觉锚点，但不再使用固定 `48px` padding 硬挤内容：

- 胶囊轮廓侧边 inset 保持 `30px`，避免形状和文字贴边。
- 最小视觉边距为 `34px`。
- 布局先测量 MEM / CPU / NET 和已启用 advanced lane 的参考值与降级值的最大单侧展示宽度，再加 `10px` 渲染安全余量。
- 左值贴左侧最小视觉边距，右值贴右侧最小视觉边距。
- 左右两侧使用同一个最大展示宽度，保证最长内容完整显示，较短内容边距视觉一致。
- 文本向中间增长，但不能占用 `notchVoid`。
- 当前 `320 x 32` render 目标是让 `FRA / 312M`、`FRA / IDLE`、`18G / 2.1G`、`18% / WARM` 等内容都不拥挤，且左右内容不进入物理刘海区域。

## 4. Full HUD 归属

Full HUD 仍然是 future expanded reference，不是默认常驻态。

它只用于：

- 静态 preview 对照。
- 未来 hover / 展开态候选。
- 验证 RAM、Swap、VPN、latency、download 等完整字段的排版上限。

它不用于 Phase 1 默认驻留视觉，不应反向影响 notch capsule 的低信息密度策略。

## 5. Smoke 结论

既有 overlay smoke 均为历史记录；VEL-032 已补当前 `320 x 32` no-approval live overlay smoke。

历史通过记录：

- VEL-011 / VEL-012 mock overlay smoke 通过，观察到 `292 x 32` bounds。
- VEL-028 no-approval local overlay smoke 通过，当时基线为 `420 x 32`。
- VEL-029 fullscreen no-approval smoke 通过，当时基线为 `420 x 32`。
- VEL-031 mock overlay visual smoke 通过，观察到 `320 x 32` bounds。
- VEL-032 no-approval live overlay smoke 通过，观察到 `320 x 32` bounds、live MEM lane、live CPU usage lane 和 VPN restricted fallback。

新的 fullscreen、多显示器或 sleep/wake smoke 仍必须另开 approval 任务。

## 6. Live Data 接入指导

后续 live data 接入应保持视觉基线不变，只替换数据源：

- `VPNStatus` 驱动 VPN lane；右值是当前 VPN path speed，来自低频小 HTTP 探针或被动 `utun` 计数器。小探针必须已有 Mullvad approval 且显式 `--vpn-speed-probe` 开启。
- `MemoryStatus` 驱动 MEM lane。
- `CPUStatus` 驱动 CPU lane；status-signal live path 由 `CPUUsageSampler` 填充 usage，并由公开 `ProcessInfo.thermalState` 填充 thermal pressure。摄氏温度字段暂时只允许 optional path，不读取真实传感器。
- 未知值用 `--`，不得扩展成解释性文案。
- 中间刘海覆盖区始终保持空。
- no-approval / approval required / approval denied 都是受限或未启用路径，notch VPN fallback 使用 muted 灰色；公开默认态不把未启用个人 VPN adapter 当作 warning。

实现判断规则：如果一个新增状态需要挤占中间刘海区，或需要回到整条顶栏黑化才能成立，它不属于 Phase 1 默认视觉基线。

## 7. Live-Like Mapping

notch capsule 的 live-like snapshot 映射必须先经过纯映射层，再交给 SwiftUI 渲染。当前代码锚点为 `StatusHUDMapping.notchCapsuleMetrics(for:lane:)` 和 `StatusHUDMapping.notchCapsuleLane(at:)`。

映射规则：

| Lane | 左侧 | 中间刘海覆盖区 | 右侧 | 示例 |
| --- | --- | --- | --- | --- |
| VPN | location/state | 空 | path speed / quality | `FRA` / `312M` |
| MEM | memory used | 空 | swap used | `18G` / `2.1G` |
| CPU | usage | 空 | thermal pressure | `18%` / `OK` |

约束：

- `notchVoid` 必须始终是空 metric 集合。
- 每条 lane 总 metric 数保持为 `2`。
- 所有 notch lane metric label 为空。
- notch lane value 不包含字段名。
- metric role 映射健康颜色，raw number 不是唯一表达。
- 测试必须防止 production 默认回退到 full HUD 或 compact bar。
