# Memory Lane Live Smoke

VEL-034 验证目标：只验证 rotating HUD 中 MEM lane 的真实数据接入和显示。Mullvad read-only 明确拒绝；不评价 VPN lane，不评价 CPU lane，不做健康色压力测试。

## 2026-05-10 VEL-034 Memory Lane Live Data Smoke

- approval: user replied `继续` after the explicit overlay smoke prompt.
- run command: `swift run Veil -- --deny-mullvad-readonly --no-mullvad-approval-prompt`
- smoke 前 `git status --short`: empty.
- smoke 前 `pgrep -x Veil`: no output.
- pre-smoke time: `2026-05-10 09:09:10 CST`.
- start time: approximately `2026-05-10 09:09:48 CST`.
- end time: approximately `2026-05-10 09:10:39 CST`.
- duration: approximately `51s`, including build startup, MEM lane capture, and cleanup confirmation.
- HUD shape: notch capsule, no fallback to full HUD or compact bar observed.
- bounds observed during run: `(x: 575, y: 0, width: 320, height: 32)`, layer `26`, alpha `1`.
- windows observed during run: `Veil windows on screen: 1`.
- observed lane scope: MEM lane only.
- MEM lane left value: `17G`.
- MEM lane right value: `1.7G`.
- field names: absent. Local OCR over the captured MEM frame returned only `17G` and `1.7G`; it did not return `MEM`, `RAM`, or `SWAP`.
- live memory provider: yes. This run did not pass `--mock-telemetry`, so `TelemetryService` used the default `MemoryMonitor`.
- Activity Monitor-like baseline before smoke: `memory_used=16.90G`, `cached_files=6.13G`, `swap_used=1.68G`, `hud_expected=17G / 1.7G`.
- cached files display: not shown in the MEM lane. Pre-smoke baseline recorded `cached_files=6.13G`, but the lane displayed only used memory and swap used.
- current health mapping reasonableness: reasonable for the observed idle baseline. On this 24GB MacBook Air baseline, `available_ratio=27.4%`, `compressed_ratio=14.5%`, and `swap_used=1.68G`, which maps to `normal` under the VEL-034 thresholds. No elevated/high pressure stress test was performed.
- unexpected prompts: none observed.
- Mullvad approval prompt: none observed. The run used `--deny-mullvad-readonly` and `--no-mullvad-approval-prompt`.
- system permission prompt: none observed.
- Mullvad / network commands executed by Veil: none observed. Runtime child-process check for the Veil PID returned no output.
- commands intentionally not performed: no Mullvad CLI, no `ping`, no TCP timing, no public IP query, no Speedtest, no network probe.
- CPU lane: not evaluated.
- VPN lane: not evaluated.
- CPU temperature sensor access: not performed.
- fullscreen / display switching / sleep-wake: not performed.
- cleanup: stopped with `Ctrl-C`; after stop, `Veil windows on screen: 0` and `pgrep -x Veil` returned no output.

Validation status: passed.

## 2026-05-12 Memory Pressure Threshold Follow-Up

- trigger: during dogfood, MEM lane showed warning color even though Veil RSS was only about `41 MB` and system memory did not appear critically constrained.
- observed before fix: live MEM lane captured as `17G / 1.6G` in warning color.
- measured provider inputs before fix: `used=17.77G`, `cached=5.58G`, `swap=1.55G`, `available=6.17G`, `available_ratio=25.7%`, `compressed=5.14G`, `compressed_ratio=21.4%`.
- root cause: the VEL-034 thresholds treated compressed memory as an independent pressure signal. macOS can retain a high compressed-page count without current memory pressure, so this was too sensitive for the compact HUD.
- code change: `MemoryMonitor.pressureLevel` now lets available memory and swap remain the primary hard signals. Compressed memory only upgrades pressure when it is high and available memory is also low.
- new rule: elevated if swap `>= 2GB`, or available / total `< 15%`, or compressed / total `>= 25%` with available / total `< 25%`.
- new rule: high if swap `>= 4GB`, or available / total `< 8%`, or compressed / total `>= 30%` with available / total `< 15%`.
- validation: `swift test` passed, `94` XCTest tests, `0` failures.
- release build: `swift build -c release` passed.
- observed after fix: relaunched dogfood MEM lane captured as `18G / 1.5G` in normal white color.
- continued dogfood: relaunched from `/tmp/VeilDogfood-20260512-173134-memfix.app` as PID `68541`.
