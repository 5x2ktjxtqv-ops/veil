# Privacy

Veil runs locally on macOS. It is designed to refine display edges and, when the
user opts in, show compact status signals without uploading user data.

## Default Startup

By default, Veil may read local display state needed for visual fit, such as:

- screen geometry used to position the overlay
- visible window/display bounds used to hide corner masks under fullscreen cover

Default startup does not:

- start status telemetry
- read memory or swap counters
- read CPU usage ticks or thermal pressure
- read passive network interface byte counters
- run `mullvad`
- run `ping`
- run active HTTP speed probes
- run `powermetrics`
- run `pmset`
- read task-status files
- create power assertions
- poll private local compact-status endpoints
- install login items, agents, daemons, or helpers
- upload telemetry

## Optional Built-In Adapters

Local status signals are opt-in. When enabled with `--status-signals` or
`VEIL_STATUS_SIGNALS=1`, Veil can read local memory and swap counters, CPU usage
ticks, public thermal pressure, and passive network interface byte counters.

Task status files are opt-in. When enabled with `--task-status-file`,
`VEIL_TASK_STATUS_FILE`, or `--task-status`, Veil reads one configured local JSON
file and maps compact states to the left notch indicator. Veil does not inspect
terminal history, AI tool internals, process arguments, repository paths, or log
output.

Long Run keepalive is opt-in. When enabled with `--long-run` or
`VEIL_LONG_RUN=1`, Veil uses process-lifetime IOKit assertions to reduce idle
sleep interruptions for local background work. It does not keep the display
awake, and it does not persist power settings.

Mullvad status is opt-in. When explicitly approved, Veil can run read-only
`mullvad status` checks and short low-frequency `ping` probes to the current
relay or visible VPN endpoint. It does not connect, disconnect, switch relays,
change DNS, or modify Mullvad settings.

Private local compact-status integrations are opt-in. When enabled, Veil polls
the configured localhost endpoint. They are intended for advanced users and
should not be treated as public default adapters.

Active VPN path speed probes are opt-in. When enabled, they use a short canary
request and a byte-limited download probe. They do not query public IP echo
services.

CPU temperature reads are opt-in. The default HUD uses public thermal pressure
instead of private or privileged temperature sensors.

Technical power keep-alive flags are opt-in aliases for Long Run. Experimental
system power mode can invoke `pmset` and should be treated as an advanced local
feature.

## Persistence

Veil can remember Mullvad read-only approval only when the user chooses the
remember option in the approval dialog. The stored value means "approved"; it
does not store Mullvad account data, relay data, IP addresses, or credentials.

To clear remembered approval, reset the app defaults for Veil or use the
development helper in tests as a reference: `MullvadReadApprovalPersistence.clear`.

## Logs

Normal operation does not write detailed telemetry logs. Diagnostic paths should
redact relay hosts and visible IP addresses before recording them.
