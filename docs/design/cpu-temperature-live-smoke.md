# CPU Temperature Live Smoke

VEL CPU temperature 验证目标：在用户明确批准后，只验证 CPU lane 的 live busy usage 和 approved temperature read-only 路径。Mullvad read-only 明确拒绝；不执行 Mullvad CLI、ping、TCP timing、公网 IP 查询、Speedtest 或其他网络探测；不做 CPU 压力测试。

## 2026-05-10 CPU Thermal Pressure Decision

- Celsius conclusion: unavailable for Phase 1 under the current MacBook Air / macOS 26.5 / arm64 boundary without sudo, helper install, or private API.
- Product decision: default CPU lane remains live busy usage on the left, and uses public `ProcessInfo.thermalState` on the right.
- Right value mapping: `nominal -> OK`, `fair -> WARM`, `serious -> HOT`, `critical -> CRIT`, unknown -> `--`.
- Safety boundary: default dogfood does not pass `--approve-cpu-temperature-readonly` and does not execute `powermetrics`.

## 2026-05-10 CPU Temperature Opt-In Smoke

- approval: user replied `继续` after the explicit CPU temperature overlay smoke prompt.
- run command: `swift run Veil -- --deny-mullvad-readonly --no-mullvad-approval-prompt --approve-cpu-temperature-readonly`
- smoke 前 `git status --short`: non-empty. This run was executed against the in-progress CPU temperature opt-in implementation.
- smoke 前 `pgrep -x Veil`: no output.
- smoke 前 `pgrep -x powermetrics`: no output.
- pre-smoke time: `2026-05-10 09:31:11 CST`.
- observed overlay time: `2026-05-10 09:31:26 CST` onward.
- duration: approximately `60s`, including build startup, CPU lane capture, direct `powermetrics` diagnostic, and cleanup confirmation.

## Observations

- HUD shape: notch capsule.
- bounds: `(x: 575, y: 0, width: 320, height: 32)`.
- observed lane scope: CPU lane.
- CPU lane left value: `19%`.
- CPU lane left source: live `CPUUsageSampler`, using public host CPU load tick delta. Semantics are busy CPU, equivalent to Activity Monitor `System + User` / `100% - Idle`.
- CPU lane right value: `--`.
- CPU lane right source: temperature unavailable fallback.
- field names: absent. The captured CPU frame showed `19%` and `--`; it did not show `CPU`, `LOAD`, or `TEMP`.

## Temperature Path Result

- approved temperature provider: attempted through the product path by passing `--approve-cpu-temperature-readonly`.
- direct diagnostic command: `/usr/bin/powermetrics --samplers smc -n 1 -i 1000`
- direct diagnostic result: `powermetrics: unrecognized sampler: smc`.
- conclusion: real CPU temperature is not connected on this machine through the current `powermetrics --samplers smc` implementation. The HUD correctly failed closed and displayed `--`.
- follow-up code guard: unsupported sampler / permission-denied outputs are treated as permanently unavailable for the current Veil process, so the approved path does not repeatedly retry the same known-failing command.

## Safety Boundary

- Mullvad approval prompt: absent.
- system permission prompt: absent.
- Mullvad CLI executed: no.
- `ping` / TCP timing / network probing executed: no.
- public IP query / Speedtest executed: no.
- CPU stress / health pressure test executed: no.
- fullscreen / display switching / sleep-wake: not performed.
- `pgrep -x powermetrics` polling during the overlay observation: no long-running process observed.

## Cleanup

- stopped the foreground `swift run` with `Ctrl-C`.
- after stop `Veil windows on screen`: `0`.
- after stop `pgrep -x Veil`: no output.
- after stop `pgrep -x powermetrics`: no output.

## Verdict

- CPU live busy usage display: passed.
- CPU temperature real data display: not passed.
- Failure mode: safe fallback, right value remains `--`.
- Phase 1 decision: do not display Celsius in the default CPU lane on this MacBook Air / macOS 26.5 class environment; display public thermal pressure instead.
- Reason: follow-up read-only exploration found no public, non-sudo, non-helper, non-private Celsius CPU temperature source suitable for Veil. `powermetrics --samplers thermal` and `cpu_power` require superuser and do not provide an appropriate default product path; `ProcessInfo.thermalState` is public but reports pressure states rather than Celsius temperature; sysctl / Mach / public IOKit did not provide a stable CPU Celsius source.
- Follow-up boundary: do not hard-wire private IOKit/SMC/IOReport paths or sudo-dependent `powermetrics` into Phase 1. Revisit only as a separate, explicitly approved task if a public low-disruption source becomes available.

## 2026-05-12 Thermal Notification Refresh Follow-Up

- trigger: user observed the MacBook feeling hot while the CPU lane appeared to lag behind.
- diagnosis: `ProcessInfo.thermalState` is a system thermal pressure level and may lag physical chassis temperature. Veil also sampled live telemetry on a `5s` timer with `1s` tolerance, while the CPU lane appears once per `3s` rotation.
- code change: `AppDelegate` now observes `ProcessInfo.thermalStateDidChangeNotification` after live telemetry starts and calls `refreshNow(queueIfBusy: true)` immediately on thermal-state changes.
- concurrency behavior: if a telemetry refresh is already in progress, thermal notifications mark a pending refresh so the new state is sampled immediately after the current refresh completes.
- non-goal: this does not remove macOS's own thermal-state hysteresis and does not read Celsius temperature.
- validation: `swift test` passed, `94` XCTest tests, `0` failures.
- release build: `swift build -c release` passed.
- first dogfood relaunch: `/tmp/VeilDogfood-20260512-180549-thermalnotify.app`, PID `43897`; this exited shortly after launch because the notification selector used the no-argument form.
- selector fix: changed the observer selector to `thermalStateChanged(_:)`, matching `NotificationCenter` delivery semantics.
- final validation: `swift test` passed again, `94` XCTest tests, `0` failures; `swift build -c release` passed again.
- final dogfood relaunch: `/tmp/VeilDogfood-20260512-181151-thermalnotify2.app`, PID `66203`.
- smoke observation: process remained alive past `40s`, exactly one `320 x 32` `Veil Dogfood` window was present, `powermetrics` was absent, and no stuck Mullvad/ping child process was observed.

## 2026-05-12 Thermal Observer MainActor Fix

- trigger: user reported the `thermalnotify2` dogfood exited.
- crash report: `Veil-2026-05-12-191909.ips` showed `EXC_BREAKPOINT` on a non-main notification thread in `@objc AppDelegate.thermalStateChanged(_:)`, with `_swift_task_checkIsolatedSwift` / MainActor executor checking in the stack.
- root cause: `ProcessInfo.thermalStateDidChangeNotification` may be posted off the main thread. A selector method on the `@MainActor` `AppDelegate` can therefore trip Swift's executor isolation check.
- fix: replaced selector-based observing with token-based `NotificationCenter.addObserver(forName:object:queue:)` and dispatches the refresh through `Task { @MainActor ... }`.
- validation: `swift test` passed, `94` XCTest tests, `0` failures.
- release build: `swift build -c release` passed.
- dogfood relaunch: `/tmp/VeilDogfood-20260512-192403-thermalobserverfix.app`, PID `81000`.
- smoke observation: process remained alive past `50s`, exactly one `320 x 32` `Veil Dogfood` window was present, `powermetrics` was absent, and no stuck Mullvad/ping child process was observed.

## 2026-05-14 CPU WARM Warning Color Follow-Up

- trigger: user observed that the CPU lane had displayed `WARM` for a long time while the color stayed white.
- root cause: `.fair` thermal pressure, displayed as `WARM`, was still mapped to the normal role.
- fix: CPU thermal role mapping now treats `.nominal` / `OK` as normal, `.fair` / `WARM` and `.serious` / `HOT` as warning, `.critical` / `CRIT` as critical, and `.unknown` / `--` as muted.
- validation: `swift test` passed, `94` XCTest tests, `0` failures.
- release build: `swift build -c release` passed.
- live thermal state before relaunch: `WARM`.
- dogfood relaunch: `/tmp/VeilDogfood-20260514-194034-warmcolor.app`, PID `8373`.
- smoke observation: process remained alive, exactly one `320 x 32` `Veil Dogfood` window was present at `(x: 575, y: 0)`, `powermetrics` was absent, and no stuck Mullvad/ping child process was observed.
- screenshot verification: `/tmp/veil-warmcolor-smoke-20260514.png` showed CPU lane `41%` / `WARM`, with `WARM` rendered in warning yellow.

## 2026-05-14 CPU Primary Value Thermal Inheritance Follow-Up

- trigger: user observed that after `WARM` turned yellow, the CPU usage value on the left still stayed white.
- root cause: CPU usage and CPU thermal pressure were colored independently. The left value only followed CPU usage health, so a normal usage value such as `35%` remained normal even when thermal pressure was `WARM`.
- fix: CPU primary usage value now inherits thermal warning / critical severity when thermal pressure is `WARM`, `HOT`, or `CRIT`. The thermal pressure value itself remains colored by its own state, so `OK` does not become yellow merely because usage is high.
- validation: `swift test` passed, `94` XCTest tests, `0` failures.
- release build: `swift build -c release` passed.
- live thermal state before relaunch: `WARM`.
- dogfood relaunch: `/tmp/VeilDogfood-20260514-194802-warmprimary.app`, PID `9893`.
- smoke observation: process remained alive, exactly one `320 x 32` `Veil Dogfood` window was present at `(x: 575, y: 0)`, `powermetrics` was absent, and no stuck Mullvad/ping child process was observed.
- screenshot verification: `/tmp/veil-warmprimary-smoke-20260514.png` showed CPU lane `35%` / `WARM`, with both values rendered in warning yellow.

## 2026-05-22 CPU WARM Source And Independent Color Follow-Up

- trigger: user observed `19%` / `WARM` rendering as warning yellow and clarified that, if `WARM` is correctly detected, yellow is the intended color.
- diagnosis: `WARM` comes from public `ProcessInfo.thermalState == .fair`, not from the instantaneous CPU usage percentage. `.fair` can reflect system thermal pressure even when current CPU load is low.
- decision: keep `.fair` / `WARM` as warning yellow on the thermal-pressure value, while coloring the CPU usage value independently by usage health. A low usage value such as `19%` can remain normal while `WARM` is warning yellow.
