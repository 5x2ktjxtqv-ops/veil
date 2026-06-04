# Contributing

Thanks for helping make Veil useful beyond one person's workflow.

## Product Direction

Veil is a quiet macOS display-edge refinement tool. The core product should
stay small:

- render notch and bottom-corner visual modules
- keep status telemetry off by default
- expose local status as opt-in signal adapters
- support local AI/background task awareness through narrow, user-owned files
- support opt-in Long Run keepalive without persistent system changes
- avoid dashboards, notification feeds, and automatic system changes

Good public adapter examples are CPU, memory, disk, passive network, local task
status files, and Long Run keepalive state. VPN tools, private local services,
active probes, and arbitrary process execution are advanced/private
integrations; they should not define the product or appear as the default
extension pattern.

## Development

```sh
swift build
swift test
swift build -c release
```

## AI-Assisted Contributions

AI-assisted work is welcome, including vibe-coding sessions with tools such as
Codex or Claude Code. Treat generated code as a draft from a fast pair
programmer: review it, simplify it, test it, and make sure a maintainer can
explain and support it.

Do not merge AI-generated changes that widen privacy boundaries, add hidden
network/process behavior, or introduce system mutations without explicit review
and documentation.

Before adding a signal adapter, document:

- what it reads
- whether it executes a process
- whether it sends network traffic
- whether it needs approval or persistence
- how it fails closed

## Pull Request Checklist

- Keep default startup visual-only and quiet.
- Prefer local, read-only, broadly useful adapters for public examples.
- Keep task-status adapters file-based and producer-owned; do not scan terminal
  history, private AI tool state, or process trees.
- Add focused tests for parsing, permission gates, and failure behavior.
- Update `PRIVACY.md` when data collection, process execution, or network behavior changes.
- Update `docs/architecture/signals.md` when adding or changing signal adapter shape.
- Do not add mutating VPN, network, power, or system-setting behavior.
