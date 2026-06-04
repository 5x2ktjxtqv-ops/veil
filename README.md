# Veil

Veil is a small local macOS display-edge refinement tool. It makes rounded
MacBook display corners and the notch area feel visually intentional, then lets
users opt into compact status signals if they want them.

The open-source shape is deliberately small:

- visual modules for notch blending and bottom-corner correction
- an optional, quiet notch/status HUD shell
- opt-in local signal adapters for common system health
- opt-in Long Run keepalive for local AI/background tasks
- a local task-status light for AI coding runners and scripts
- no dashboard, notification feed, theme system, or automatic system changes

## Run

```sh
swift run Veil
```

Default startup is visual-first. It can render the notch blend and bottom-corner
mask on supported built-in displays, but it does not start status telemetry or
execute `mullvad`, `ping`, active HTTP probes, `powermetrics`, `pmset`, or local
private integration endpoints. It also does not read task-status files or create
power assertions unless the user enables those modes.

## Visual Modules

Veil separates display-edge fit from monitoring:

| Module | Default | Behavior |
| --- | --- | --- |
| Notch capsule | Auto | Blends the physical notch into a matte black capsule on notched MacBook displays. |
| Bottom-corner mask | Auto | Adds matching black masks to the lower display corners on supported rounded-corner built-in displays. |
| Status signal HUD | Off | Renders compact text/indicators inside the capsule only when enabled. |

Visual module architecture notes live in
[docs/architecture/visual-modules.md](docs/architecture/visual-modules.md).
Display fit notes live in [docs/specs/display-edge-fit.md](docs/specs/display-edge-fit.md).

## Signals

Veil treats monitor sources as optional signal adapters. Public examples should
be boring, local, and broadly useful: memory, CPU, passive network, task-status
files, Long Run keepalive state, and planned disk/storage health. A signal
adapter reads one source and maps it into the compact HUD contract: one left
value, one right value, optional severity, and optional indicator.

Public local adapters:

| Signal | Default | Behavior |
| --- | --- | --- |
| Memory / swap | Off | Local read-only memory counters used only when the signal HUD is enabled. |
| CPU / thermal pressure | Off | Public CPU usage and thermal pressure state, used only when the signal HUD is enabled. |
| Passive network counters | Off | Local interface byte counters; no active network probe. |
| Task status light | Off | Reads one small local JSON file and maps it to the left notch indicator. |
| Long Run keepalive | Off | Process-lifetime IOKit assertions for local background tasks; maps health to the right notch indicator. |
| Disk / storage | Planned | Local capacity and pressure signal; should not inspect user files. |

Advanced private integrations:

| Signal | Default | Behavior |
| --- | --- | --- |
| Mullvad read-only status | Off | Private workflow adapter; can run `mullvad status` and short current-relay `ping` only after explicit approval. |
| Local compact-status endpoint | Off | Private workflow adapter for local services; polls a configured localhost endpoint when enabled. |
| VPN active path speed probe | Off | Byte-limited HTTP probe, only when explicitly enabled after VPN read approval. |
| CPU temperature | Off | Optional `powermetrics` path; the regular CPU signal uses public thermal pressure when status signals are enabled. |

Architecture notes live in [docs/architecture/signals.md](docs/architecture/signals.md).
Privacy boundaries live in [PRIVACY.md](PRIVACY.md).
Local adapter notes live in [docs/adapters/local-signals.md](docs/adapters/local-signals.md).
Roadmap lives in [docs/roadmap.md](docs/roadmap.md).

## Opt-In Examples

Enable local memory / CPU / passive network status signals:

```sh
swift run Veil -- --status-signals
VEIL_STATUS_SIGNALS=1 swift run Veil
```

Prompt for Mullvad read-only approval:

```sh
swift run Veil -- --prompt-mullvad-approval
```

Approve Mullvad read-only checks for this run:

```sh
swift run Veil -- --approve-mullvad-readonly
```

Enable a private local compact-status endpoint:

```sh
swift run Veil -- --model-growth-monitor
VEIL_MODEL_GROWTH_MONITOR=1 swift run Veil
```

Enable Long Run keepalive:

```sh
swift run Veil -- --long-run
VEIL_LONG_RUN=1 swift run Veil
```

`--long-run` uses process-lifetime IOKit assertions. It keeps system idle sleep,
disk idle sleep, and network-client idle sleep from interrupting local work, but
it does not keep the display awake.

Enable a local AI/background task status light:

```sh
swift run Veil -- --task-status-file ~/.local/state/veil/task-status.json
```

Example producer payload:

```json
{
  "state": "running",
  "tool": "codex",
  "message": "swift test",
  "updated_at": "2026-06-04T00:00:00Z"
}
```

Supported states include `running`, `succeeded`, `failed`, `attention`,
`stale`, and `inactive`. The task light is intentionally tool-neutral: Claude
Code, Codex, CI wrappers, or shell scripts can all write the same file.

Wrapper examples:

```sh
Tools/veil-task-run --tool build --message "swift test" -- swift test
Tools/veil-codex-task --message "repo audit" -- exec "run tests and fix failures"
Tools/veil-claude-task --message "docs pass" -- "update README examples"
```

The wrappers write only the compact `--message` value, not terminal output or
full prompts.

Technical power keep-alive alias:

```sh
swift run Veil -- --power-keepalive
```

Experimental root-only system power mode:

```sh
sudo swift run Veil -- --system-power-keepalive
```

Useful development toggles:

```sh
VEIL_CLICK_THROUGH=0 swift run Veil
swift run Veil -- --no-status-signals
VEIL_BOTTOM_CORNER_MASK=0 swift run Veil
VEIL_BOTTOM_CORNER_RADIUS=24 swift run Veil
swift run Veil -- --no-bottom-corner-mask
swift run Veil -- --no-power-keepalive
swift run Veil -- --approve-cpu-temperature-readonly
```

## Development

```sh
swift build
swift test
swift build -c release
```

Veil uses AI-assisted development, including agentic coding sessions, but the
project is human-maintained. AI-authored changes should be reviewed, tested, and
kept inside the same privacy and default-off boundaries as any other
contribution.

The project is currently a Swift Package executable that starts an accessory
AppKit application. App bundle packaging, signing, notarization, and a settings
UI are still future product work.

## Phase 1 Scope

- Native Swift/AppKit/SwiftUI
- Default display-edge visual baseline: notch capsule and bottom-corner mask
- Optional memory / CPU / passive network counters behind `--status-signals`
- Optional task status light through a local JSON file
- Optional Long Run keepalive for AI/background tasks
- Planned local disk / storage signal
- Advanced opt-in private integrations kept out of the public example path

Deferred on purpose:

- settings UI
- login item / launch at startup
- third-party plugin runtime
- hover expansion
- node benchmark tooling
- automatic VPN switching
- heavyweight speed tests
