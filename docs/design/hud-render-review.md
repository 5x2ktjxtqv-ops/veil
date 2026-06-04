# Veil HUD Static Render Review

状态：Draft, CPU thermal pressure render baseline
编号：VEL-010 / VEL-012 / VEL-030 / CPU thermal pressure
日期：2026-05-10

## 1. 目标

本文件记录 mock HUD 的静态 PNG 导出结果，用于肉眼比较 VEL-030 的 rotating pair HUD。

本轮导出只使用 `PreviewFixtures` 中的本地静态 mock snapshots，不启动真实 overlay，不读取真实 telemetry，不接 Mullvad，不执行 ping / TCP timing / 公网 IP 查询 / Speedtest，也不读取真实 CPU 温度传感器。

## 2. VEL-030 默认态

Phase 1 默认态仍是 notch capsule / 刘海延展胶囊，但内容从固定“左 RAM / 右 VPN”改为三条同类双值 lane，每 `3s` 轮换。

视觉基线：

- 默认尺寸：`320 x 32`。
- 轮廓参数：`screenCornerWidth: 4.5`、`screenCornerHeight: 5.5`、`screenCornerControl: 0.50`、`bottomCornerWidth: 14`、`bottomCornerHeight: 9`、`bottomCornerControl: 0.78`。
- 中间 notch void 为空。
- 不显示字段名。

## 3. Render Matrix

| 文件 | 状态 | 尺寸 | 说明 |
| --- | --- | --- | --- |
| `notch-capsule.png` | Notch capsule VPN lane | 320 x 32 | 默认静态代表图 |
| `notch-capsule-vpn.png` | VPN lane | 320 x 32 | `FRA` / `312M` |
| `notch-capsule-mem.png` | MEM lane | 320 x 32 | `18G` / `2.1G` |
| `notch-capsule-cpu.png` | CPU lane | 320 x 32 | `18%` / `OK` |
| `notch-capsule-cpu-temp-unavailable.png` | CPU thermal pressure unknown | 320 x 32 | `18%` / `--` |
| `default-compact-240.png` | Default compact | 240 x 34 | 历史 compact preview，非默认 |
| `default-roomy-340.png` | Default roomy | 340 x 34 | 历史 roomy preview，用于异常态空间对照 |
| `full-expanded-420.png` | Full expanded | 420 x 54 | Future expanded reference，不是默认常驻态 |
| `vpn-off.png` | VPN off | 340 x 34 | 旧 compact 异常态对照 |
| `approval-required.png` | Mullvad approval required | 340 x 34 | 旧 compact approval 对照 |
| `memory-elevated.png` | Memory elevated | 340 x 34 | 旧 compact memory 对照 |
| `memory-high.png` | Memory high | 340 x 34 | 旧 compact memory 对照 |
| `latency-degraded.png` | Latency degraded | 340 x 34 | 旧 compact latency 对照 |
| `network-unknown.png` | Network unknown | 340 x 34 | 旧 compact unknown 对照 |

## 4. VEL-030 Render Outputs

### VPN lane

![VPN lane](renders/notch-capsule-vpn.png)

观察：

- `FRA` / `312M` 在 `320 x 32` 中不拥挤。
- 不显示 `VPN` 字段名。
- 中间区域只作为黑色覆盖，不承载任何文字。

### MEM lane

![MEM lane](renders/notch-capsule-mem.png)

观察：

- `18G` / `2.1G` 符合同类 memory pair。
- 不显示 `RAM` / `MEM` / `SWAP` 字段名。
- 左右外侧锚点保持稳定。

### CPU lane

![CPU lane](renders/notch-capsule-cpu.png)

观察：

- `18%` / `OK` 使用 mock CPU 数据。
- 不显示 `CPU` / `LOAD` 字段名。
- 本 render 不代表真实摄氏温度传感器读取。

### CPU thermal pressure unknown

![CPU temp unavailable](renders/notch-capsule-cpu-temp-unavailable.png)

观察：

- thermal pressure unknown 时右侧为 `--`。
- 左侧 usage 仍可显示 mock / optional 值 `18%`。

## 5. 历史 / 对照 Outputs

旧 compact、roomy、expanded 和异常态 render 仍保留为对照，不作为 VEL-030 默认常驻形态。

![Default compact](renders/default-compact-240.png)

![Full expanded](renders/full-expanded-420.png)

## 6. 初步结论

- 默认态：`320 x 32` notch capsule，静态代表图为 `notch-capsule.png`。
- 三条 lane 在静态 render 中都能容纳：VPN、MEM、CPU。
- `292 x 32` 初始收缩候选已因右侧显示区域不足被 superseded。
- Full expanded 继续只是 future expanded reference。
- 本轮没有启动真实 overlay；视觉 smoke 后续另开 approval 任务。

## 7. 导出文件

```text
docs/design/renders/notch-capsule.png
docs/design/renders/notch-capsule-vpn.png
docs/design/renders/notch-capsule-mem.png
docs/design/renders/notch-capsule-cpu.png
docs/design/renders/notch-capsule-cpu-temp-unavailable.png
docs/design/renders/default-compact-240.png
docs/design/renders/default-roomy-340.png
docs/design/renders/full-expanded-420.png
docs/design/renders/vpn-off.png
docs/design/renders/approval-required.png
docs/design/renders/memory-elevated.png
docs/design/renders/memory-high.png
docs/design/renders/latency-degraded.png
docs/design/renders/network-unknown.png
```
