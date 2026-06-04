# Roadmap

状态：GitHub launch roadmap  
日期：2026-06-04

## Product Position

Veil is a free, open-source MacBook display-edge refinement tool with an
optional local long-task awareness layer.

The public pitch:

> Make modern MacBook display corners feel finished.

Secondary pitch:

> Keep local AI/background work visible at the edge of the screen without
> turning it into a dashboard.

Status signals are optional. Public examples should be CPU, memory, passive
network, the narrow task-status file, Long Run keepalive state, and planned
disk/storage, not private workflow integrations.

Development transparency: Veil uses AI-assisted development, but it should be
presented as human-maintained open source. The product promise is reviewed,
tested, privacy-bounded local software, not raw generated output.

## v0.1 GitHub Launch

Must have:

- README that leads with display-edge refinement
- MIT license, privacy policy, security policy, contributing guide
- visual-only default startup
- notch capsule auto behavior on supported notched MacBook displays
- bottom-corner mask auto behavior on supported rounded-corner built-in displays
- status signals off by default
- `--status-signals` opt-in for memory / CPU / passive network
- `--long-run` opt-in for process-lifetime keepalive
- `--task-status-file` opt-in for the left AI/background task status light
- GitHub Actions CI for Swift build and test
- issue templates for bugs, compatibility reports, and feature requests

Should have:

- screenshot or short GIF of the corner fit
- compatibility table for MacBook Air 13/15 and MacBook Pro 14/16
- release checklist for unsigned developer builds
- task-status file adapter docs and producer examples

Deferred:

- settings UI
- notarized app distribution
- Homebrew Cask
- arbitrary shell plugins
- public plugin marketplace

## v0.2

Focus: make the product easier to install and tune for long-running local AI
work.

- app bundle packaging
- minimal settings window
- visual module toggles: notch capsule auto/off, bottom-corner mask auto/off
- bottom-corner radius slider
- Long Run controls: off, timed session, until stopped
- task-status light controls: file path, stale timeout, reset
- launch-at-login plan, still off by default
- first public `disk` signal adapter

## v0.3

Focus: local adapter configuration beyond the narrow task-status file.

- local JSON config file
- adapter ordering
- adapter enable/disable controls
- declarative localhost HTTP/file adapter prototype
- no arbitrary shell execution yet

## Private Integrations Policy

Mullvad, local compact-status endpoints, active VPN probes, CPU temperature
sensor attempts, and root-only system power policy mode are advanced/private
integrations.

They can remain in the repo if they stay:

- off by default
- clearly documented in `PRIVACY.md`
- permission-gated
- absent from the public example adapter story
