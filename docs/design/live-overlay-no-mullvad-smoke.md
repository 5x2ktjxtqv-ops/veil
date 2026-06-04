# Live Overlay Without Mullvad Approval Smoke

VEL-016 验证目标：第一次进入真实 live overlay，但仍不授权 Mullvad，不做任何网络主动探测。只验证 notch capsule 在真实内存和被动接口计数器数据下能安全运行，并确认右翼稳定显示 VPN fallback。

## 2026-05-09 Smoke

运行前确认：

- `pgrep -x Veil || true`：无输出，确认没有残留 `Veil` 进程。

运行命令：

```sh
swift run Veil -- --deny-mullvad-readonly --no-mullvad-approval-prompt
```

运行记录：

- 是否出现 Mullvad approval prompt：否。`--deny-mullvad-readonly` 将本次运行固定为 denied，`--no-mullvad-approval-prompt` 关闭本次运行的 approval prompt；窗口枚举只发现 1 个 `Veil` overlay window，没有额外 prompt window。
- 是否执行 Mullvad CLI / ping / TCP timing / 网络探测：否。本次没有传 `--approve-mullvad-readonly`；`MullvadMonitor.sample` 在 denied approval 下直接返回 fallback，不进入 `mullvad status` 或 `/sbin/ping` 路径；代码中没有 TCP timing 路径。本次没有执行 Mullvad CLI、ping、TCP timing、公网 IP 查询，未修改网络、DNS、路由、代理或 Mullvad 状态。
- HUD 是否维持 notch capsule：是。运行中 `CGWindowList` 观察到 `Veil windows on screen: 1`，窗口 bounds 为 `(x: 589, y: 0, width: 292, height: 32)`，与 VEL-012 frozen notch capsule bounds 一致，没有退回 full HUD / compact bar。
- 左翼 RAM 是否来自 live memory：是。本次未传 `--mock-telemetry`，进入 live telemetry 路径；左翼显示 `22G`，来自 `MemoryMonitor` 的实时内存采样。
- 右翼是否为 VPN --：是。Veil-only 窗口截图显示右翼为 `VPN --`，符合 denied Mullvad fallback。
- 被动接口计数器：live telemetry 初始化 `NetworkThroughputSampler`，只读取本机接口计数器；本次不做主动网络探测。

结束确认：

- 使用 `Ctrl-C` 停止 `swift run Veil ...`。
- `Veil windows on screen: 0`。
- `pgrep -x Veil || true`：无输出，确认没有残留 `Veil` 进程。

构建验证：

- `swift build`：通过。
- `swift test`：通过，27 个 XCTest 通过。
- `swift build -c release`：通过。

结论：

- live overlay 能启动并显示 notch capsule。
- Mullvad 保持 denied 状态。
- 未触发 Mullvad CLI、ping、TCP timing 或其他主动网络探测。
- HUD 未退回 full HUD / compact bar。
- 结束后无 `Veil` 进程和窗口残留。
