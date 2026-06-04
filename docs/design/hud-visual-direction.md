# Veil HUD Visual Direction

状态：Phase 1 visual baseline, updated by VEL-031
编号：VEL-008 / VEL-012 / VEL-030 / VEL-031 referenced
日期：2026-05-10

## 1. 目标

本文件记录 Veil Phase 1 HUD 的当前视觉方向和状态表达规则，用于指导 SwiftUI mock preview、静态 render、mock overlay smoke 和后续本机试用。

VEL-031 同步 VEL-030 后，默认 HUD 不再是固定“左内存 / 右 VPN”的静态双翼布局，而是 `320 x 32` notch capsule 内的 rotating pair HUD。

本文件只定义视觉和状态表达。真实 telemetry、Mullvad approval、网络探测和 CPU 温度读取的权限边界以 `docs/process/runtime-permissions.md` 和本机 smoke runbook 为准。

## 2. 默认视觉原则

Veil HUD 应像一层原生系统生命体征，而不是一个贴在屏幕上的 App 面板。

默认原则：

- 黑色：与刘海、菜单栏和顶栏融合，避免彩色块成为第一视觉焦点。
- 悬浮胶囊：覆盖刘海本体，但不吃掉整条屏幕顶部。
- 哑光：使用纯黑或接近纯黑背景，不使用玻璃拟态。
- 克制：正常状态不制造警报感，不用动画吸引注意力。
- 原生：字体、圆角、阴影、间距都靠近 macOS 顶栏语气。
- 低信息密度：同一时刻只显示一条同类双值 lane。
- 余光可读：用户不需要停下工作细读，也能捕捉异常。

产品气质关键词：

```text
quiet / matte / native / infrastructural / glanceable
```

## 3. Phase 1 默认形态

推荐默认方向：`320 x 32` notch capsule / 刘海延展胶囊。

默认内容是三条 lane 按固定顺序轮换：

```text
FRA   312M
18G   2.1G
18%   OK
```

语义：

| Lane | 左值 | 右值 |
| --- | --- | --- |
| VPN | location/state | current throughput/quality |
| MEM | used memory | swap used |
| CPU | usage | thermal pressure |

轮换规则：

- 公开基础顺序为 MEM -> CPU -> NET；approved advanced/private lane 追加在基础 lane 后。
- 每条 lane 显示 `3s`。
- 任一时刻只显示一条 lane。
- 中间 notch void 永远为空，不放文字、图标、状态点或 live data。

字段名规则：

- 默认 notch capsule 不显示 `VPN` / `RAM` / `MEM` / `SWAP` / `CPU` / `LOAD` 字段名。
- 正常 mock fixture 的期望值为 `FRA 312M`、`18G 2.1G`、`18% OK`。
- 不可用值使用 `--`，不通过补字段名解释。
- 异常状态可通过颜色或短值提升，但不回到解释性字段堆叠。

CPU thermal pressure 边界：

- Phase 1 不显示摄氏 CPU temperature；摄氏温度在当前 MacBook Air / macOS 环境下没有 public、non-sudo、non-helper、non-private 来源。
- CPU lane 右值来自公开 `ProcessInfo.thermalState`，映射为 `OK` / `WARM` / `HOT` / `CRIT`。
- thermal pressure unknown 时显示 `--`。

## 4. 形态比较

| 形态 | 示例 | 推荐归属 |
| --- | --- | --- |
| 刘海胶囊默认态 | `FRA 312M` -> `18G 2.1G` -> `18% OK` | Phase 1 默认态 |
| 单行 compact | `RAM 18G   VPN FRA` | 历史 preview / 非默认 |
| 双行完整态 | `RAM 18G SWAP 2.1G / VPN FRA 312M 23ms` | mock preview 和未来展开态 |
| 异常提升态 | `-- --`、`OFF --`、`18G --`、`18% HOT`、`18% CRIT` | 默认态内的短值替换 |

结论：

- 默认态：`320 x 32` 刘海胶囊 rotating pair。
- 完整态：非默认，用于未来展开态。
- 异常态：在默认 HUD 内用短值和局部状态色提升，不打开大型解释 UI。

## 5. 内容规则

VPN lane：

- connected 且 location 可解析：左值显示 city code，例如 `FRA`。
- passive download throughput 可用：右值显示 `312M`。
- 右侧 throughput 是被动当前流量，不是健康度。已知值使用 normal 色，包括 `0K`；unknown 使用 muted 灰色。
- no approval、unknown 或不可判断：使用 `--`，不得显示真实 relay、出口、完整位置、未授权 latency 或其他 Mullvad 细节。
- disconnected：使用短状态值，例如 `OFF`，不得提供控制按钮。

MEM lane：

- 左值显示 used memory，例如 `18G`。
- 右值显示 swap used，例如 `2.1G`。
- 不显示 `RAM`、`MEM`、`SWAP` 标签。
- memory elevated/high 可通过 warning/critical 色提升，但不扩展 HUD。

CPU lane：

- 左值显示 usage，例如 `18%`。
- 右值显示 thermal pressure，例如 `OK`、`WARM`、`HOT`、`CRIT`。
- `WARM` 和 `HOT` 使用 warning 色；`CRIT` 使用 critical 色。
- thermal pressure unknown 时显示 `--`。
- Phase 1 live path 不读取真实 CPU 摄氏温度；thermal pressure 来自公开 `ProcessInfo.thermalState`。

展开态可以显示：

- RAM。
- Swap。
- VPN location 或 state。
- Latency。
- Lightweight download estimate。
- 必要时显示 relay 简写。

默认不显示：

- Relay name。
- Download throughput。
- Pressure 文案。
- Health normal、connected normal 等解释性文案。
- 正常状态绿色常亮。

## 6. 状态优先级

当多个状态同时出现时，HUD 不应该堆满所有信息。优先级从高到低：

1. VPN off / Mullvad approval required。
2. Memory high。
3. Latency degraded。
4. Memory elevated。
5. Network unknown。
6. VPN connected normal。
7. Idle。

显示原则：

- 高优先级状态可替换低优先级数值。
- 同一时刻最多保留两个可见值。
- 异常状态优先显示判断结果，再显示最小必要数值。
- 正常状态不显示 `NORMAL`、`OK`、`CONNECTED` 这类解释词。

## 7. 基础视觉规格

### 尺寸

| 参数 | 值 |
| --- | --- |
| `productionCompact` | `StatusHUDConfiguration.notchCapsule` |
| `current design size` | `320 x 32` |
| `screenInsetWidth` | `30` |
| `screenCornerWidth` | `4.5` |
| `screenCornerHeight` | `5.5` |
| `screenCornerControl` | `0.50` |
| `bottomCornerWidth` | `14` |
| `bottomCornerHeight` | `9` |
| `bottomCornerControl` | `0.78` |
| `minimumVisualMargin` | `34` |
| `referenceWingSafetyPadding` | `2` |
| `referenceNotchVoidWidth` | `180` |
| `notchSideOverhang` | `70` per side |
| `VEL-031 initial mock smoke bounds observed` | `(589, 0, 292, 32)` |

运行时尺寸规则：

- notch capsule 优先使用带 `safeAreaInsets.top` 和 auxiliary top area 的刘海屏。
- 宽度为 `max(notch width + side overhang * 2, 320)`。
- 高度为 `max(safeAreaInsets.top, 32)`。
- 当前待验证 mock overlay 目标为 `320 x 32`。

### 字体

建议：

- 使用 SwiftUI `.system`，优先 macOS 原生系统字体。
- 数值使用 monospaced digit 或 monospaced design，减少刷新跳动。
- notch capsule 默认字号 `11pt`。
- 不依赖动态缩放解决默认布局。

### 字重

建议：

- 默认值：semibold，白色 86%-90% opacity。
- 不显示 label；因此 label 字重不参与默认 notch capsule。
- 异常值：semibold，不升到 bold。
- 不使用 heavy、black 或大标题字重。

### 间距

建议：

- notch capsule 最小视觉边距：`34px`。
- 同一 lane 左右各一个值，中间 notch void 至少 `120px`。
- 左右展示宽度由 MEM / CPU / NET 和已启用 advanced lane 的参考值与降级值最大测量宽度加 `10px` 安全余量决定，两侧使用同一宽度。
- 左值贴左侧最小视觉边距，右值贴右侧最小视觉边距。
- lane 内值之间不强行凑成解释性短语。
- 固定高度，不因状态变化跳动。
- 异常态优先替换文本，不临时扩展 HUD。

### 状态色

状态色只用于异常和降级，不用于正常状态常亮。

| 语义 | 用途 | 草案色 |
| --- | --- | --- |
| Neutral | 默认文本、unknown | white opacity / gray |
| Amber | elevated、latency degraded、adapter warning | `#D99F2E` |
| Red | memory high、VPN off | `#E13D31` |

使用规则：

- 正常 connected 不显示绿色。
- 颜色只用于局部文字或 2px 顶部细线。
- 不使用大面积色块。
- 不闪烁，不脉冲，不呼吸动画。
- unknown 使用灰色，不默认当作故障。

### 背景、圆角、阴影

建议：

- 背景：`#000000`。
- 质感：哑光，无玻璃高光。
- 上角：接近直角，只保留轻微过渡弧。
- 下沿：克制外圆角。
- 默认阴影：无，或极轻 1 层黑色阴影用于避免浅色背景边缘发虚。
- 边框：默认无；如必须区分边界，使用 white opacity 0.06 的 1px 内描边。

## 8. Mock Preview 与 Smoke

SwiftUI mock preview 应至少覆盖：

- Notch capsule VPN lane：`FRA 312M`。
- Notch capsule MEM lane：`18G 2.1G`。
- Notch capsule CPU lane：`18% OK`。
- CPU thermal pressure unknown：`18% --`。
- VPN off。
- Approval required。
- Memory elevated。
- Memory high。
- Latency degraded。
- Network unknown。
- Full expanded：未来展开态对照。

Preview 和 smoke 应验证：

- notch capsule 默认尺寸为 `320 x 32`。
- 三条 lane 按 `3s` 周期轮换。
- 任一 notch lane 都不显示字段名。
- notch void 为空。
- 状态切换不改变默认 HUD 高度。
- 状态色足够可见，但不抢占屏幕注意力。
- Full HUD 明确看起来像展开态，而不是默认常驻态。

## 9. 明确不做什么

本视觉方向明确不做：

- 不做霓虹。
- 不做复杂渐变。
- 不做玻璃拟态。
- 不做图表。
- 不做 Dynamic Island 展开动画。
- 不做解释性文案 UI。
- 不做大面积彩色状态块。
- 不做正常状态绿色常亮。
- 不做按钮、切换器、国家选择器或 VPN 控制 UI。
- 不做 relay 列表、节点排名或测速面板。
- 不在默认 notch capsule 内显示字段名。
- 不读取真实 CPU 温度传感器。

Relay 列表、节点排行和测速面板仍不进入默认 notch capsule。后续版本可以把它们设计成用户点击后从刘海向下展开的诊断面板：常驻态只保留当前节点健康摘要，展开态再显示候选国家/城市、endpoint latency、jitter/loss、只读/会修改状态的测试边界和少量推荐节点。

## 10. 结论

VEL-031 follow-up 后，Veil Phase 1 默认视觉冻结为黑色、哑光、低信息密度的 `320 x 32` notch capsule rotating pair：

```text
FRA   312M
18G   2.1G
18%   OK
```

Full HUD 不作为默认态。它只作为 mock preview 对照形态，以及未来 hover/展开态候选。

异常状态在默认 HUD 内进行克制提升：只显示最关键判断和必要数值，不弹窗、不展开 Dashboard、不用动画解释。

整条黑色顶栏融合、顶部中心 compact HUD、右侧辅助状态项和固定 RAM/VPN 双翼均为历史方案 / 非默认方案。
