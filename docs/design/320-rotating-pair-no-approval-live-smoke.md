# 320 Rotating Pair No-Approval Live Smoke

VEL-032 验证目标：在用户批准后启动一次 no-approval live overlay，验证当前 `320 x 32` notch capsule 的 VPN / MEM / CPU rotating pair HUD。Mullvad read-only approval 明确拒绝，不执行 Mullvad CLI、ping、TCP timing 或任何网络探测；CPU 温度保持 unavailable，不读取真实传感器。

## 2026-05-10 VEL-032 No-Approval Live CPU Usage Smoke

- approval: user replied `approve` after the explicit overlay smoke prompt.
- run command: `swift run Veil -- --deny-mullvad-readonly --no-mullvad-approval-prompt`
- start time: approximately `2026-05-10 07:56 CST`
- end time: approximately `2026-05-10 07:59 CST`
- duration: approximately `3 minutes`, including build startup, lane observation, screenshots, and cleanup.
- HUD shape: notch capsule, no fallback to full HUD or compact bar observed.
- bounds observed during run: `(x: 575, y: 0, width: 320, height: 32)`, layer `26`, alpha `1`.
- windows observed during run: `Veil windows on screen: 1`.
- rotating pair cycle observed: yes, at least one full VPN -> MEM -> CPU cycle.
- VPN lane no-approval fallback: `--` / `--`; no relay, city, latency, exit, or real Mullvad detail displayed.
- MEM lane live values: `23G` / `1.7G` observed.
- CPU lane live values: `16%` / `--` observed during the full cycle; additional CPU samples included `22%`, `23%`, and `25%`, always with temperature `--`.
- unexpected prompts: none observed.
- Mullvad / network commands executed by Veil: none observed. Run command denied Mullvad read-only approval and disabled approval prompt; runtime child-process check for the Veil PID returned no output.
- CPU temperature sensor access: none; live CPU lane kept temperature unavailable as `--`.
- fullscreen / display switching / sleep-wake: not performed.
- cleanup: stopped with `Ctrl-C`; after stop, `Veil windows on screen: 0` and `pgrep -x Veil` returned no output.

Validation status: passed.
