# 420 No-Approval Local Overlay Smoke

VEL-028 验证目标：按 VEL-027 runbook 补一条当前 `420 x 32` notch capsule 的 no-approval 本机 smoke。旧 no-Mullvad live smoke 是 `292 x 32` 时代的历史记录；本文件记录当前 420 基线的实机运行结果。

## 2026-05-09 No-Approval Local Smoke

运行前确认：

- 用户已明确批准本次 overlay smoke。
- `git status --short`：无输出，确认 smoke 前 worktree clean。
- `pgrep -x Veil`：无输出，确认 smoke 前没有残留 `Veil` 进程。
- `swift build`：通过。
- `swift test`：通过，28 个 XCTest 通过。
- `swift build -c release`：通过。

运行命令：

```sh
swift run Veil -- --deny-mullvad-readonly --no-mullvad-approval-prompt
```

运行时间：

- start time: `2026-05-09 20:15:16 CST`
- end time: `2026-05-09 20:16:40 CST`

运行记录：

- 是否出现 Mullvad approval prompt：否。`--deny-mullvad-readonly` 将本次运行固定为 denied，`--no-mullvad-approval-prompt` 关闭本次运行的 approval prompt；运行中窗口枚举只发现 1 个 `Veil` overlay window。
- 是否出现系统权限 prompt 或额外授权请求：否。运行中 prompt-like window 枚举为 `0`。
- HUD 是否维持 `420 x 32` notch capsule：是。运行中 `CGWindowList` 两次观察到 1 个 `Veil` overlay window，bounds 均为 `(x: 525, y: 0, width: 420, height: 32)`，layer `26`，alpha `1`，没有退回 full HUD / compact bar。
- 左翼是否显示 live RAM token：是。本次未传 `--mock-telemetry`，进入 live telemetry 路径；notch capsule mapping 在左翼显示实时 memory token。
- 右翼是否显示 `VPN --`：是。本次 Mullvad approval 为 denied，右翼显示 denied fallback `VPN --`。
- 是否执行 Mullvad CLI / ping / TCP timing / 网络探测：否。本次没有传 `--approve-mullvad-readonly`；denied approval 下 `MullvadMonitor.sample` 直接返回 fallback，不进入 `mullvad status` 或 `/sbin/ping` 路径。运行中采样 `pgrep -P <Veil PID>` 无输出；本次没有执行 Mullvad CLI、ping、TCP timing、公网 IP 查询、Speedtest 或其他主动网络探测。
- 是否改变 Mullvad、网络、DNS、route、proxy 或防火墙状态：否。本次只启动 overlay 并观察本地窗口、HUD 内容和停止清理状态。
- 是否进入 fullscreen、切换显示器、sleep/wake 或长时间 idle resource smoke：否。
- abort reason, if any：无。

结束确认：

- 使用 `Ctrl-C` 停止 `swift run Veil -- --deny-mullvad-readonly --no-mullvad-approval-prompt`。
- `Veil windows on screen: 0`。
- `pgrep -x Veil`：无输出，确认没有残留 `Veil` 进程。

结论：

- 当前 `420 x 32` no-approval 本机 overlay smoke 通过。
- live overlay 能启动并维持 notch capsule。
- HUD 左翼显示 live RAM token，右翼显示 `VPN --` denied fallback。
- 未触发 Mullvad approval prompt、系统权限 prompt、Mullvad CLI、ping、TCP timing 或主动网络探测。
- 结束后无 `Veil` 进程和窗口残留。
