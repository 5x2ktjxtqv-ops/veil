# Veil Signal Architecture

状态：OSS product direction  
日期：2026-06-04

## Product Shape

Veil should be a small local display-edge refinement product, not a bundle of
one person's monitors.

The product has four layers:

1. Visual Modules: notch blending, bottom-corner correction, display geometry, and per-display capability detection.
2. HUD Core: window placement, rendering, refresh scheduling, and severity mapping when status signals are enabled.
3. Signal Adapters: small modules that read one status source and produce compact values.
4. User Configuration: a way to enable, disable, order, and approve modules/adapters.

Public adapter examples must be broadly useful and local-first. CPU, memory,
disk, passive network, task status files, and Long Run keepalive state are good
examples. Mullvad, model-growth, and other workflow-specific integrations are
advanced private integrations, not the extension model Veil should present to
new users.

Visual modules are not signal adapters. They should be able to run without
starting live telemetry, polling status providers, or requiring the user to care
about any private workflow integration.

## Adapter Contract

Each signal adapter should declare:

| Field | Purpose |
| --- | --- |
| `id` | Stable identifier, such as `memory`, `cpu`, `disk`, `network`, or `private.local-status`. |
| `displayName` | Human-readable name for future settings UI. |
| `defaultEnabled` | Whether a fresh install runs it. Personal or networked adapters should default to `false`. |
| `permission` | `none`, `local-read`, `process-read`, `network-read`, `privileged`, or a combination. |
| `pollInterval` | Minimum refresh interval. |
| `failureMode` | How it fails closed without blocking the HUD. |
| `compactMapping` | One left value, one right value, optional severity and indicator. |

Adapters should not own windowing, visual layout, or global product policy.

## Adapter Tiers

### Tier 1: Public Local Signals

These are the public examples and first-class signal adapters. They are local
and read-only, but a fresh open-source install should still keep them behind the
status-signal toggle:

- memory and swap
- CPU usage and public thermal pressure
- passive network interface counters
- local task status file for AI/background runners
- Long Run keepalive state
- disk capacity / storage pressure

Even these should stay low-frequency and cheap.

`task-status-file` is intentionally narrower than a general plugin system. Veil
reads one local JSON file and maps normalized states to the left notch
indicator. Producers such as Claude Code wrappers, Codex wrappers, build
scripts, or local CI should write the file themselves.

`long-run` is not a monitoring adapter. It is a local session mode that holds
process-lifetime IOKit assertions and reports its health to the right notch
indicator. It must leave display sleep untouched so the screen can still black
out while background tasks continue.

### Tier 2: Advanced Private Integrations

These reflect a user's workflow. They can exist for dogfood and advanced users,
but they should not define the public extension story:

- Mullvad read-only status
- local compact-status endpoint for private services
- active VPN path speed probe
- CPU temperature sensor attempts

They must be explicitly enabled and documented in `PRIVACY.md`.

### Tier 3: Future External Local Adapters

The first public extension point should be declarative and local-first:

```json
{
  "id": "local.build",
  "displayName": "Build Status",
  "kind": "http-json",
  "url": "http://127.0.0.1:9876/compact-status",
  "pollIntervalSeconds": 30,
  "leftPath": "$.left",
  "rightPath": "$.right",
  "severityPath": "$.severity"
}
```

Arbitrary shell plugins should come later, only with clear approval UX,
timeouts, output limits, and no default enablement. They are powerful but much
harder to trust.

## v0.1 OSS Decision

For the first open-source cut:

- Default startup should be visual-only, quiet, and local.
- Public adapter examples are memory, CPU, passive network, task status files,
  Long Run keepalive state, and planned disk/storage.
- Mullvad is opt-in and private/advanced.
- Local compact-status integrations are opt-in and private/advanced.
- Long Run keepalive is opt-in and uses process-lifetime IOKit assertions.
- Active network probes are opt-in.
- Local memory / CPU / passive network status signals are opt-in through
  `--status-signals` / `VEIL_STATUS_SIGNALS=1`.
- Task status files are opt-in through `--task-status-file` /
  `VEIL_TASK_STATUS_FILE`.
- `--long-run` is the public alias for local AI/background task keepalive.
- Disk / storage should join the public local signal set before arbitrary plugin work.
- Visual modules can run without status signals.
- The public settings story can remain CLI/env based, but the language should
  describe them as signal adapters rather than hard-coded product identity.

Future work can add a settings UI that writes a small local config file and lets
users pick adapter order, enablement, and approval scope.
