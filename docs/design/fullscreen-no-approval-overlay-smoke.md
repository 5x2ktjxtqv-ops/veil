# Fullscreen No-Approval Overlay Smoke

VEL-029 验证目标：按 VEL-027 runbook，补一条 fullscreen 场景下的 no-approval overlay smoke。只验证当前 `420 x 32` notch capsule 在一个 fullscreen App / Space 中不抢焦点、不遮挡关键交互、退出 fullscreen 后能恢复位置。

## 2026-05-09 Fullscreen No-Approval Smoke

运行前确认：

- 用户已明确批准本次 fullscreen no-approval overlay smoke。
- `git status --short --branch`：只显示 `## main`，没有 changed path。
- `pgrep -x Veil`：无输出，确认 smoke 前没有残留 `Veil` 进程。
- `swift build`：通过。
- `swift test`：通过，28 个 XCTest 通过。
- `swift build -c release`：通过。

运行命令：

```sh
swift run Veil -- --deny-mullvad-readonly --no-mullvad-approval-prompt
```

fullscreen host：

- 使用临时本地 AppKit smoke host 创建一个 `Veil Fullscreen Smoke Host` window，并对该 window 执行一次 fullscreen 进入/退出。
- 该 host 只在本机创建 window / fullscreen Space，不使用 AppleScript、Accessibility 自动化、Mullvad CLI、网络命令或显示器切换。
- host 结束后已删除临时文件和临时截图。

运行时间：

- Veil overlay start time: `2026-05-09 20:39:30 CST`
- fullscreen host start time: `2026-05-09 20:40:20 CST`
- fullscreen observe time: `2026-05-09 20:40:29 CST`
- fullscreen exit request: `2026-05-09 20:40:46 CST`
- post-fullscreen observe time: `2026-05-09 20:40:56 CST`
- host exit time: `2026-05-09 20:41:00 CST`
- Veil overlay end time: `2026-05-09 20:42:04 CST`

说明：approval 问法中预期 overlay 约 `30-60` 秒；本次因手动窗口采样和清理确认，Veil 进程实际运行约 `2m34s`。fullscreen host 的实际验证窗口约 `40s`。期间没有扩大到资源 smoke、sleep/wake、多显示器或网络探测。

运行记录：

- 是否出现 Mullvad approval prompt：否。`--deny-mullvad-readonly` 将本次运行固定为 denied，`--no-mullvad-approval-prompt` 关闭本次运行的 approval prompt。
- 是否出现系统权限 prompt 或额外授权请求：否。未使用 AppleScript、Accessibility 自动化或系统权限变更。
- 是否执行 Mullvad CLI / ping / TCP timing / 网络探测：否。本次没有传 `--approve-mullvad-readonly`；denied approval 下 `MullvadMonitor.sample` 直接返回 fallback，不进入 `mullvad status` 或 `/sbin/ping` 路径。运行中采样 `pgrep -P 397` 无输出。本次没有执行 Mullvad CLI、ping、TCP timing、公网 IP 查询、Speedtest 或其他主动网络探测。
- HUD 是否维持 `420 x 32` notch capsule：是。进入 fullscreen 前和退出 fullscreen 后，`CGWindowList` 都只观察到 1 个 `Veil` overlay window，bounds 为 `(x: 525, y: 0, width: 420, height: 32)`，layer `26`，alpha `1`，没有退回 full HUD / compact bar。
- fullscreen 中是否抢焦点：否。fullscreen host 在 `2026-05-09 20:40:29 CST` 记录 `frontmost=swift-frontend`、`key=true`、`firstResponder=NSTextView`、`fullscreen=true`、frame `0,0,1470,923`；`Veil` 没有成为 frontmost app 或 key window。
- fullscreen 中是否遮挡关键交互：未观察到。host 的文本输入控件保持 `NSTextView` first responder，fullscreen 中可更新为 `fullscreen key interaction remained active`。本次没有做合成鼠标点击，以避免引入 Accessibility 自动化或权限 prompt。
- 退出 fullscreen 后是否恢复位置：是。退出 fullscreen 后 `CGWindowList` 再次观察到 1 个 `Veil` overlay window，bounds 仍为 `(x: 525, y: 0, width: 420, height: 32)`。
- 是否切换显示器、sleep/wake 或做长时间资源测试：否。
- abort reason, if any：无。

结束确认：

- 使用 `Ctrl-C` 停止 `swift run Veil -- --deny-mullvad-readonly --no-mullvad-approval-prompt`。
- `Veil windows on screen: 0`。
- `pgrep -x Veil`：无输出，确认没有残留 `Veil` 进程。
- 临时 fullscreen host 文件和临时截图已删除。

结论：

- Fullscreen no-approval overlay smoke 通过。
- 当前 `420 x 32` notch capsule 在一个 fullscreen App / Space 中没有抢焦点。
- 关键输入控件在 fullscreen 中保持 first responder，未观察到交互阻塞。
- 退出 fullscreen 后 HUD 恢复到 notch capsule 位置。
- 未触发 Mullvad approval prompt、系统权限 prompt、Mullvad CLI、ping、TCP timing 或主动网络探测。
- 结束后无 `Veil` 进程和窗口残留。
