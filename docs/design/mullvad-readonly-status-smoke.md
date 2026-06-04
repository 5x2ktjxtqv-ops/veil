# Mullvad Read-Only Status Live Smoke

VEL-020 验证目标：按 VEL-018 计划执行一次最小 live smoke。只授权本次运行内的 Mullvad read-only status 读取，以及已 connected 时对当前 relay 或 visible endpoint 的低频短 ping；不改变 Mullvad 或系统网络状态。

## 2026-05-09 Mullvad Read-Only Status Smoke

- run command: `swift run Veil -- --approve-mullvad-readonly`
- start time: `2026-05-09 18:00:17 CST`
- end time: `2026-05-09 18:01:09 CST`
- cleanup verified: `2026-05-09 18:01:32 CST`
- approval scope: per-run read-only approval. Scope covered only `mullvad status` and, when Mullvad was already connected, a low-frequency short ping to the current relay or visible endpoint. It did not authorize connect, disconnect, reconnect, relay switching, DNS/tunnel/route/proxy/firewall changes, account/config/log/diagnostic reads, public IP checks, TCP timing, speed tests, or daemon/app/system-extension restarts.
- observed status: connected, inferred from the live HUD showing a location code plus latency. No full endpoint, relay host, account, config, log, or diagnostic detail was recorded.
- observed HUD right wing: location code `FRA` was visible in the right wing.
- observed latency: latency appeared in the right wing as an `ms` value; the observed sample was about `291ms`.
- CGWindowList bounds: one `Veil` overlay window observed during the smoke with bounds `(x: 589, y: 0, width: 292, height: 32)`.
- unexpected prompts: none observed. `--approve-mullvad-readonly` skipped Veil's approval prompt for this run, and no extra `Veil` prompt window appeared.
- whether Mullvad state changed: no observed change. No connect/disconnect/reconnect command, relay switch, or system network mutation was run.
- abort reason, if any: none.
- cleanup confirmation: stopped the foreground `swift run` with `Ctrl-C`; post-run `CGWindowList` reported `0` `Veil` windows; post-run `pgrep -x Veil` had no output; the temporary smoke screenshot was deleted.

Validation status:

- pre-smoke `git status --short`: no output.
- pre-smoke `pgrep -x Veil`: no output.
- `swift build`: passed.
- `swift test`: passed, 27 XCTest tests passed.
- `swift build -c release`: passed.

Red-line confirmation:

- Did not run `mullvad relay list`.
- Did not run TCP timing, public IP lookup, Speedtest, fast.com, or iperf.
- Did not read Mullvad account, token, key, config directory, log directory, or diagnostic bundle.
- Did not restart Mullvad App, daemon, system extension, or related services.

## 2026-05-14 Dogfood Relaunch After CPU Primary Thermal Inheritance Fix

- trigger: user observed that after `WARM` turned yellow, the CPU usage value on the left still stayed white.
- change under test: CPU primary usage value now inherits thermal warning / critical severity when thermal pressure is `WARM`, `HOT`, or `CRIT`; the thermal pressure value itself remains colored by its own state.
- superseded on 2026-05-22: CPU usage and thermal pressure colors are independent again; `WARM` remains warning yellow on the thermal value, while the usage value is colored only by usage health.
- validation before relaunch: `swift test` passed, `94` XCTest tests, `0` failures; `swift build -c release` passed.
- previous dogfood stopped: `/tmp/VeilDogfood-20260514-194034-warmcolor.app`, PID `8373`.
- relaunch bundle: `/tmp/VeilDogfood-20260514-194802-warmprimary.app`.
- relaunch args: `--approve-mullvad-readonly --no-mullvad-approval-prompt`.
- new process: PID `9893`, parent PID `1`.
- initial process sample: elapsed `00:18`, CPU `0.0%`, RSS approximately `45 MB`.
- initial window sample: owner `Veil Dogfood`, bounds `(x: 575, y: 0, width: 320, height: 32)`.
- live CPU lane screenshot: `35%` / `WARM`, with both values rendered in warning yellow.
- `pgrep -x powermetrics`: no output.
- child process check: no stuck `mullvad status`, `/sbin/ping`, or `powermetrics` child process observed.

Red-line confirmation:

- Did not run `mullvad relay list`.
- Did not run TCP timing, public IP lookup, Speedtest, fast.com, traceroute, mtr, or iperf.
- Did not read Mullvad account, token, key, config directory, log directory, or diagnostic bundle.
- Did not restart Mullvad App, daemon, system extension, or related services.

## 2026-05-14 Dogfood Relaunch After CPU WARM Color Fix

- trigger: user observed the CPU lane had displayed `WARM` for a long time while the color stayed white.
- change under test: CPU thermal pressure role mapping now renders `WARM` and `HOT` as warning, while keeping `OK` normal, `CRIT` critical, and `--` muted.
- validation before relaunch: `swift test` passed, `94` XCTest tests, `0` failures; `swift build -c release` passed.
- previous dogfood stopped: `/tmp/VeilDogfood-20260512-192403-thermalobserverfix.app`, PID `81000`, after approximately `2 days`.
- relaunch bundle: `/tmp/VeilDogfood-20260514-194034-warmcolor.app`.
- relaunch args: `--approve-mullvad-readonly --no-mullvad-approval-prompt`.
- new process: PID `8373`, parent PID `1`.
- initial process sample: elapsed `00:25`, CPU `0.7%`, RSS approximately `45 MB`.
- initial window sample: owner `Veil Dogfood`, bounds `(x: 575, y: 0, width: 320, height: 32)`.
- live CPU lane screenshot: `41%` / `WARM`, with `WARM` rendered in warning yellow.
- `pgrep -x powermetrics`: no output.
- child process check: no stuck `mullvad status`, `/sbin/ping`, or `powermetrics` child process observed.

Red-line confirmation:

- Did not run `mullvad relay list`.
- Did not run TCP timing, public IP lookup, Speedtest, fast.com, traceroute, mtr, or iperf.
- Did not read Mullvad account, token, key, config directory, log directory, or diagnostic bundle.
- Did not restart Mullvad App, daemon, system extension, or related services.

## 2026-05-12 Dogfood Relaunch After Memory Pressure Threshold Fix

- trigger: MEM lane warning was too sensitive because compressed memory alone could elevate pressure.
- validation before relaunch: `swift test` passed with `94` XCTest tests and `0` failures; `swift build -c release` passed.
- old run: PID `16323` was stopped before relaunch.
- first relaunch attempt: reusing the same overwritten bundle path hit a LaunchServices launch failure, with no leftover Veil process or window.
- relaunch command: new temporary `.app` bundle opened through LaunchServices with args `--approve-mullvad-readonly --no-mullvad-approval-prompt`.
- bundle path: `/tmp/VeilDogfood-20260512-173134-memfix.app`.
- process: PID `68541`, parent PID `1`.
- initial process sample: elapsed `00:34`, CPU `0.0%`, RSS approximately `45 MB`.
- initial window sample: owner `Veil Dogfood`, bounds `(x: 575, y: 0, width: 320, height: 32)`, layer `26`, alpha `1`.
- MEM lane check: captured `18G / 1.5G` in normal white color after the compressed-memory threshold fix.
- initial `pgrep -x powermetrics`: no output.
- stuck child check: a short current-relay `/sbin/ping` child was observed immediately after launch and was gone after `5s`; no stuck child remained.
- diagnostics: not enabled for the continued long run.
- follow-up automation: `veil-mullvad-dogfood-check-in` updated to track PID `68541`.

## 2026-05-12 Dogfood Relaunch After Thermal Notification Refresh

- trigger: CPU thermal pressure display could appear delayed because live telemetry refreshed every `5s` and the CPU lane rotates every `3s`.
- validation before relaunch: `swift test` passed with `94` XCTest tests and `0` failures; `swift build -c release` passed.
- old run: PID `68541` was stopped before relaunch.
- first relaunch: `/tmp/VeilDogfood-20260512-180549-thermalnotify.app`, PID `43897`, exited shortly after launch because the notification selector used the no-argument form.
- selector fix: changed the observer selector to `thermalStateChanged(_:)`, matching `NotificationCenter` delivery semantics.
- validation after selector fix: `swift test` passed with `94` XCTest tests and `0` failures; `swift build -c release` passed.
- final relaunch command: new temporary `.app` bundle opened through LaunchServices with args `--approve-mullvad-readonly --no-mullvad-approval-prompt`.
- bundle path: `/tmp/VeilDogfood-20260512-181151-thermalnotify2.app`.
- process: PID `66203`, parent PID `1`.
- process stability sample: elapsed `00:43`, CPU `0.0%`, RSS approximately `45 MB`.
- initial window sample: owner `Veil Dogfood`, bounds `(x: 575, y: 0, width: 320, height: 32)`, layer `26`, alpha `1`.
- thermal refresh behavior: the dogfood build observes `ProcessInfo.thermalStateDidChangeNotification` and refreshes immediately on system thermal-state changes, with a pending refresh if telemetry is already in progress.
- `pgrep -x powermetrics`: no output.
- stuck child check: no `mullvad status`, `/sbin/ping`, or `powermetrics` child process observed.
- diagnostics: not enabled for the continued long run.
- follow-up automation: `veil-mullvad-dogfood-check-in` updated to track PID `66203`.

## 2026-05-12 Dogfood Relaunch After Thermal Observer MainActor Fix

- trigger: user reported the `thermalnotify2` dogfood exited.
- crash report: `~/Library/Logs/DiagnosticReports/Veil-2026-05-12-191909.ips` showed `EXC_BREAKPOINT` in `@objc AppDelegate.thermalStateChanged(_:)` on a non-main notification thread.
- root cause: `ProcessInfo.thermalStateDidChangeNotification` may be delivered off-main; selector delivery into a `@MainActor` method tripped Swift executor isolation checking.
- fix: replaced selector observing with token-based `NotificationCenter.addObserver(forName:object:queue:)` and forwards the refresh to `MainActor` via `Task`.
- validation before relaunch: `swift test` passed with `94` XCTest tests and `0` failures; `swift build -c release` passed.
- relaunch command: new temporary `.app` bundle opened through LaunchServices with args `--approve-mullvad-readonly --no-mullvad-approval-prompt`.
- bundle path: `/tmp/VeilDogfood-20260512-192403-thermalobserverfix.app`.
- process: PID `81000`, parent PID `1`.
- stability sample: elapsed `00:50`, CPU `0.0%`, RSS approximately `45 MB`.
- window sample: owner `Veil Dogfood`, bounds `(x: 575, y: 0, width: 320, height: 32)`, layer `26`, alpha `1`.
- `pgrep -x powermetrics`: no output.
- stuck child check: no `mullvad status`, `/sbin/ping`, or `powermetrics` child process observed.
- diagnostics: not enabled for the continued long run.
- follow-up automation: `veil-mullvad-dogfood-check-in` updated to track PID `81000`.

## 2026-05-10 CPU Thermal Pressure + Mullvad Read-Only Smoke

- run command: `VEIL_MULLVAD_DIAGNOSTICS=1 .build/release/Veil --approve-mullvad-readonly --no-mullvad-approval-prompt`
- duration: approximately `70s`, including window bounds check, CPU lane screenshot, Mullvad diagnostics, and cleanup.
- worktree state: non-empty; this smoke was run against the in-progress CPU thermal pressure lane decision and Mullvad read-only hardening.
- preflight: `swift test` passed with `93` XCTest tests and `0` failures; `swift build -c release` passed; static HUD renders were refreshed after the CPU thermal pressure change.
- approval scope: per-run read-only approval. Scope covered only `mullvad status` and, when connected, low-frequency 3-packet short `ping` to the current relay or visible endpoint. It did not authorize connect, disconnect, reconnect, relay switching, DNS/tunnel/route/proxy/firewall changes, account/config/log/diagnostic reads, public IP checks, TCP timing, speed tests, or daemon/app/system-extension restarts.
- CGWindowList bounds: one `Veil` overlay window observed during the smoke with bounds `(x: 575, y: 0, width: 320, height: 32)`, layer `26`, alpha `1`.
- CPU lane: captured live screenshot `docs/design/renders/cpu-thermal-pressure-live-smoke-20260510.png` showed `20%` / `OK`.
- CPU thermal source: direct public `ProcessInfo.thermalState` probe returned `nominal`, matching the HUD `OK` mapping.
- CPU Celsius / powermetrics: not approved and not executed; `pgrep -x powermetrics` had no output after cleanup.
- structured diagnostics: enabled via `VEIL_MULLVAD_DIAGNOSTICS=1`; diagnostics redacted the probe target as `relay_host`.
- observed status: `connection=connected`, `location=FRA`.
- observed median latency samples: `316.9ms`, then `291.5ms`, then `290.0ms`.
- yellow cause: first `warning=latencyGT300`, then `warning=latencyGE150`.
- node health: first `node_health=unhealthy`, then `node_health=degraded`.
- interpretation: the CPU lane decision is usable for dogfood (`usage / OK` instead of unavailable Celsius), while the current Mullvad FRA path still measures roughly `290-317ms` and remains degraded by the existing thresholds.
- whether Mullvad state changed: no observed change. No connect/disconnect/reconnect command, relay switch, or system network mutation was run.
- unexpected prompts: none observed.
- cleanup confirmation: stopped the foreground release process; post-run `pgrep -x Veil` had no output; post-run `CGWindowList` reported `0` `Veil` windows; post-run `pgrep -x powermetrics` had no output.

Validation status:

- CPU thermal pressure lane: passed.
- approved Mullvad read-only path: passed.
- long dogfood gate: passed.

Red-line confirmation:

- Did not run `mullvad relay list`.
- Did not run TCP timing, public IP lookup, Speedtest, fast.com, traceroute, mtr, or iperf.
- Did not read Mullvad account, token, key, config directory, log directory, or diagnostic bundle.
- Did not restart Mullvad App, daemon, system extension, or related services.

## 2026-05-10 CPU Thermal Pressure Dogfood Restart

- launch command: temporary `.app` bundle opened through LaunchServices with args `--approve-mullvad-readonly --no-mullvad-approval-prompt`.
- bundle path: `/tmp/VeilDogfood-20260510-130339.app`.
- process: PID `9947`, parent PID `1`.
- initial process sample: elapsed `00:13`, CPU `0.0%`, RSS approximately `45 MB`.
- initial window sample: owner `Veil Dogfood`, bounds `(x: 575, y: 0, width: 320, height: 32)`, layer `26`, alpha `1`.
- CPU lane decision: this dogfood uses live CPU usage plus public thermal pressure (`OK` / `WARM` / `HOT` / `CRIT` / `--`); it does not pass `--approve-cpu-temperature-readonly`.
- initial `pgrep -x powermetrics`: no output.
- approval scope: per-run read-only approval. Scope covers only `mullvad status` and, when connected, low-frequency 3-packet short `ping` to the current relay or visible endpoint. It does not authorize connect, disconnect, reconnect, relay switching, DNS/tunnel/route/proxy/firewall changes, account/config/log/diagnostic reads, public IP checks, TCP timing, speed tests, or daemon/app/system-extension restarts.
- diagnostics: not enabled for the long run; this avoids long-lived stderr logging. Follow-up checks should use local process/window/resource inspection only.
- restart behavior: not a login item or LaunchAgent; it will not automatically restart after logout/reboot/crash.
- follow-up automation: `veil-mullvad-dogfood-check-in`, every 12 hours for 6 check-ins.

## 2026-05-12 Dogfood Relaunch After Drop

- user report: program dropped; requested relaunch and continued testing.
- old run: PID `9947` was no longer present; `CGWindowList` showed `0` Veil windows.
- relaunch command: existing temporary `.app` bundle opened through LaunchServices with args `--approve-mullvad-readonly --no-mullvad-approval-prompt`.
- bundle path: `/tmp/VeilDogfood-20260510-130339.app`.
- process: PID `16323`, parent PID `1`.
- relaunch time: `2026-05-12 06:31:52 CST`.
- initial process sample: elapsed `00:03`, CPU `1.2%`, RSS approximately `47 MB`.
- initial window sample: owner `Veil Dogfood`, bounds `(x: 575, y: 0, width: 320, height: 32)`, layer `26`, alpha `1`.
- initial `pgrep -x powermetrics`: no output.
- stuck child check: no `mullvad status`, `/sbin/ping`, or `powermetrics` child process observed.
- diagnostics: not enabled for the continued long run.
- follow-up automation: `veil-mullvad-dogfood-check-in` updated to track PID `16323`.

## 2026-05-10 Mullvad Read-Only Parser-Gate Smoke

- run command: `VEIL_MULLVAD_DIAGNOSTICS=1 swift run Veil -- --approve-mullvad-readonly --no-mullvad-approval-prompt`
- start time: approximately `2026-05-10 12:00 CST`
- end time / cleanup verified: `2026-05-10 12:01:37 CST`
- worktree state: non-empty; this smoke was run against in-progress Mullvad read-only parser hardening.
- approval scope: per-run read-only approval. Scope covered only `mullvad status` and, when connected, low-frequency short `ping` to the current relay or visible endpoint. It did not authorize connect, disconnect, reconnect, relay switching, DNS/tunnel/route/proxy/firewall changes, account/config/log/diagnostic reads, public IP checks, TCP timing, speed tests, or daemon/app/system-extension restarts.
- preflight: `pgrep -x Veil` had no output; `swift build`, `swift test`, and `swift build -c release` passed. `swift test` executed `89` XCTest tests with `0` failures.
- CGWindowList bounds: one `Veil` overlay window observed during the smoke with bounds `(x: 575, y: 0, width: 320, height: 32)`.
- structured diagnostics: enabled via `VEIL_MULLVAD_DIAGNOSTICS=1`; diagnostics redacted the probe target as `relay_host`.
- observed status: `connection=connected`, `location=FRA`.
- observed read-only commands from Veil diagnostics: `mullvad status` attempts and short current-relay `ping` attempts only.
- observed latency samples: `290.7ms`, `452.9ms`, then `294.6ms`.
- yellow cause: first `warning=latencyGE150`, then `warning=latencyGT300`, then back to `warning=latencyGE150`.
- node health: degraded, briefly unhealthy, then degraded.
- whether Mullvad state changed: no observed change. No connect/disconnect/reconnect command, relay switch, or system network mutation was run.
- unexpected prompts: none observed.
- cleanup confirmation: stopped the foreground run with `Ctrl-C`; post-run `pgrep -x Veil` had no output; post-run `CGWindowList` reported `0` `Veil` windows; post-run process check found no `mullvad status`, `/sbin/ping`, `swift run Veil`, or `.build/.../Veil` process.

Validation status:

- approved read-only path: passed.
- VPN lane gate for long dogfood: passed; approved path produced structured Mullvad status instead of no-approval `--   --`.
- latency health result: degraded on this network during the smoke.

Red-line confirmation:

- Did not run `mullvad relay list`.
- Did not run TCP timing, public IP lookup, Speedtest, fast.com, traceroute, mtr, or iperf.
- Did not read Mullvad account, token, key, config directory, log directory, or diagnostic bundle.
- Did not restart Mullvad App, daemon, system extension, or related services.

## 2026-05-10 Mullvad Read-Only Release Dogfood Start

- launch command: temporary `.app` bundle opened through LaunchServices with args `--approve-mullvad-readonly --no-mullvad-approval-prompt`.
- bundle path: `/tmp/VeilDogfood-20260510-121349.app`.
- process: PID `72741`, parent PID `1`.
- initial process sample: elapsed `00:30`, CPU `0.0%`, RSS approximately `45 MB`.
- initial window sample: owner `Veil Dogfood`, bounds `(x: 575, y: 0, width: 320, height: 32)`.
- approval scope: per-run read-only approval. Scope covers only `mullvad status` and, when connected, low-frequency 3-packet short `ping` to the current relay or visible endpoint. It does not authorize connect, disconnect, reconnect, relay switching, DNS/tunnel/route/proxy/firewall changes, account/config/log/diagnostic reads, public IP checks, TCP timing, speed tests, or daemon/app/system-extension restarts.
- diagnostics: not enabled for the long run; this avoids long-lived stderr logging. Follow-up checks should use local process/window/resource inspection only.
- restart behavior: not a login item or LaunchAgent; it will not automatically restart after logout/reboot/crash.

## 2026-05-10 Mullvad Read-Only Median Latency Smoke

- run command: `VEIL_MULLVAD_DIAGNOSTICS=1 swift run Veil -- --approve-mullvad-readonly --no-mullvad-approval-prompt`
- duration: approximately `70s`, including three latency probe windows and cleanup confirmation.
- worktree state: non-empty; this smoke was run against in-progress median latency probe hardening.
- approval scope: per-run read-only approval. Scope covered only `mullvad status` and, when connected, low-frequency 3-packet short `ping` to the current relay or visible endpoint. It did not authorize connect, disconnect, reconnect, relay switching, DNS/tunnel/route/proxy/firewall changes, account/config/log/diagnostic reads, public IP checks, TCP timing, speed tests, or daemon/app/system-extension restarts.
- preflight: `pgrep -x Veil` had no output; `swift build`, `swift test`, and `swift build -c release` passed. `swift test` executed `90` XCTest tests with `0` failures.
- CGWindowList bounds: one `Veil` overlay window observed during the smoke with bounds `(x: 575, y: 0, width: 320, height: 32)`.
- structured diagnostics: enabled via `VEIL_MULLVAD_DIAGNOSTICS=1`; diagnostics showed `veil_mullvad_command name=ping target=relay_host timeout=4.2`, confirming the 3-packet probe path.
- observed status: `connection=connected`, `location=FRA`.
- observed median latency samples: `327.2ms`, `312.8ms`, then `290.8ms`.
- yellow cause: first two samples `warning=latencyGT300`, third sample `warning=latencyGE150`.
- node health: unhealthy for the first two samples, degraded for the third.
- interpretation: median probe reduced single-packet spike sensitivity, but the current FRA path still measured roughly `290-330ms`, so the high latency appears real for this node/path during the smoke rather than a formatting or parser precision artifact.
- whether Mullvad state changed: no observed change. No connect/disconnect/reconnect command, relay switch, or system network mutation was run.
- unexpected prompts: none observed.
- cleanup confirmation: stopped the foreground run with `Ctrl-C`; post-run `pgrep -x Veil` had no output; post-run `CGWindowList` reported `0` `Veil` windows; post-run process check found no `mullvad status`, `/sbin/ping`, `swift run Veil`, or `.build/.../Veil` process.

Validation status:

- approved read-only path: passed.
- median latency path: passed.
- long dogfood gate: passed.

Red-line confirmation:

- Did not run `mullvad relay list`.
- Did not run TCP timing, public IP lookup, Speedtest, fast.com, traceroute, mtr, or iperf.
- Did not read Mullvad account, token, key, config directory, log directory, or diagnostic bundle.
- Did not restart Mullvad App, daemon, system extension, or related services.

## 2026-05-10 Mullvad Read-Only Diagnostics Smoke

- run command: `VEIL_MULLVAD_DIAGNOSTICS=1 swift run Veil -- --approve-mullvad-readonly --no-mullvad-approval-prompt`
- duration: approximately `53s`, including startup, window bounds check, live sampling, and cleanup.
- approval scope: per-run read-only approval. Scope covered only `mullvad status` and, when connected, a low-frequency short `ping` to the current relay or visible endpoint. It did not authorize connect, disconnect, reconnect, relay switching, DNS/tunnel/route/proxy/firewall changes, account/config/log/diagnostic reads, public IP checks, TCP timing, speed tests, or daemon/app/system-extension restarts.
- CGWindowList bounds: one `Veil` overlay window observed during the smoke with bounds `(x: 575, y: 0, width: 320, height: 32)`, layer `26`, alpha `1`.
- structured diagnostics: enabled via `VEIL_MULLVAD_DIAGNOSTICS=1`; diagnostics redact relay host and visible IP as `relay_host` / `visible_ipv4`.
- observed status: `connection=connected`, `location=FRA`.
- observed read-only commands from Veil diagnostics: `mullvad status` attempts and short current-relay `ping` attempts only.
- observed latency samples: `290.4ms` then `367.4ms`.
- yellow cause: first `warning=latencyGE150`, later `warning=latencyGT300`; no `approvalRequired`, `cliUnavailableOrError`, or `flapping` cause was observed.
- node health: first `node_health=degraded`, later `node_health=unhealthy`.
- whether Mullvad state changed: no observed change. No connect/disconnect/reconnect command, relay switch, or system network mutation was run.
- cleanup confirmation: after stop, process check found no `Veil`, `swift run Veil`, `.build/.../Veil`, `/sbin/ping`, `mullvad status`, or Mullvad mutating command process.

Validation status:

- `swift build`: passed.
- `swift test`: passed, 75 XCTest tests passed.
- `swift build -c release`: passed.

Red-line confirmation:

- Did not run `mullvad relay list`.
- Did not run TCP timing, public IP lookup, Speedtest, fast.com, or iperf.
- Did not read Mullvad account, token, key, config directory, log directory, or diagnostic bundle.
- Did not restart Mullvad App, daemon, system extension, or related services.
