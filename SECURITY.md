# Security Policy

Veil is a local macOS HUD. Security-sensitive behavior includes system overlays,
local task-status files, process execution, VPN status reads, network probes,
CPU temperature reads, and power-management features.

## Supported Versions

Until the first tagged release, security fixes target `main`.

## Reporting

Please open a private report with:

- affected commit or release
- macOS version and hardware, when relevant
- exact launch flags or environment variables
- expected behavior and observed behavior
- whether the issue involves process execution, network traffic, persistence, or privilege escalation

Avoid posting public proof-of-concept details for issues that can change system
power settings, expose VPN/network information, or trigger unintended external
traffic.

## Security Boundaries

- Default startup must remain visual-only: no status telemetry, no task-status file reads, no power assertions, no Mullvad CLI commands, no `ping`, no active HTTP probes, no `pmset`, no `powermetrics`, and no arbitrary plugin commands.
- Public adapter examples should be local and read-only, such as CPU, memory, disk, passive network, and the narrow task-status file adapter.
- Long Run keepalive is opt-in, process-lifetime only, and must not create display-sleep assertions by default.
- Mullvad reads are opt-in and read-only.
- Active VPN path probes are opt-in and byte-limited.
- CPU temperature reads are opt-in and fail closed.
- System power policy mode is experimental, explicit, and should not be enabled by default.
- Future plugin work should prefer declarative local HTTP/file adapters before arbitrary shell execution.
