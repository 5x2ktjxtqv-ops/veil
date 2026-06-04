# Local Signal Adapters

状态：Public adapter direction  
日期：2026-06-04

## Public Example Rule

Veil's public adapter examples should be boring, local, and broadly useful.

Good examples:

- memory
- CPU
- disk / storage
- passive network counters
- local task status file
- Long Run keepalive state

Not good public examples:

- a specific VPN provider
- a private local model monitor
- a private build or trading system
- arbitrary shell commands
- active network probes

Those can exist as advanced/private integrations, but they should not teach new
contributors that Veil is a personal workflow monitor.

## Built-In Local Set

### `memory`

Purpose: answer whether memory pressure may affect current work.

Reads:

- memory used
- swap used
- optional pressure classification

Does not:

- list processes
- clean memory
- suggest killing apps

### `cpu`

Purpose: answer whether CPU load or system thermal pressure may affect current work.

Reads:

- public CPU usage ticks
- public thermal pressure state

Does not:

- require `powermetrics`
- read private sensors by default
- show per-process CPU usage

### `network`

Purpose: answer whether the machine currently has passive network activity.

Reads:

- local interface byte counters

Does not:

- ping anything
- query public IP
- run speed tests
- scan hosts

### `task-status-file`

Purpose: answer whether a local AI/background task is running, done, failed, or
needs attention.

Reads:

- one configured local JSON file
- compact status fields only

Does not:

- read terminal history
- inspect Claude Code, Codex, or IDE private state
- scan processes
- run hooks or shell commands

### `long-run`

Purpose: keep local background work from being interrupted by idle sleep while
leaving display sleep/black-screen behavior to macOS.

Uses:

- `PreventUserIdleSystemSleep`
- `PreventDiskIdle`
- `NetworkClientActive`

Does not:

- create display-sleep assertions
- persist power settings
- call `pmset` unless the user explicitly enables root-only system power mode

### `disk`

Purpose: answer whether storage pressure may affect current work.

Planned reads:

- filesystem capacity
- available bytes on the primary data volume
- coarse storage pressure, such as OK / LOW / FULL

Must not:

- inspect user file names
- index folders
- compute directory sizes by crawling the home folder
- upload or log paths

## Compact Contract

Each local adapter should map to the notch capsule as:

| Adapter | Left | Right | Example |
| --- | --- | --- | --- |
| `memory` | used memory | swap | `18G` / `2.1G` |
| `cpu` | busy usage | thermal pressure | `18%` / `OK` |
| `network` | passive download | passive upload | `100M` / `2M` |
| `task-status-file` | no lane | left indicator | running / done / failed |
| `long-run` | no lane | right indicator | asserted / degraded / failed |
| `disk` | available space | pressure | `42G` / `OK` |

The values should omit field labels in the capsule. The settings UI, docs, and
expanded views can explain what each lane means.

## Implementation Order

1. Keep visual modules as the default product.
2. Keep `--status-signals` as the opt-in switch for local signals.
3. Use `memory`, `cpu`, `network`, `task-status-file`, and `long-run` as the
   current public live examples.
4. Add `disk` before investing in arbitrary plugin systems.
5. Consider declarative local HTTP/file adapters only after the narrow task
   status file contract has proven useful.
