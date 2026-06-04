# GitHub Launch Checklist

状态：Pre-release checklist  
日期：2026-06-04

## Repository

- [ ] Repository name and description say display-edge refinement.
- [ ] README first screen explains the visual value before status signals.
- [ ] `LICENSE`, `PRIVACY.md`, `SECURITY.md`, and `CONTRIBUTING.md` are present.
- [ ] GitHub Actions CI is enabled.
- [ ] CI runs build, tests, SwiftLint, ShellCheck, Gitleaks, Python tool syntax, and task-status wrapper smoke.
- [ ] Issue templates are enabled.
- [ ] The default branch is protected after the first public push.

## Product Defaults

- [ ] Fresh launch is visual-only.
- [ ] Fresh launch does not start status telemetry.
- [ ] Fresh launch does not read task-status files.
- [ ] Fresh launch does not create power assertions.
- [ ] Fresh launch does not run `mullvad`, `ping`, active HTTP probes, `pmset`, or `powermetrics`.
- [ ] Fresh launch does not poll private local endpoints.
- [ ] Rectangular external displays do not show a blank notch capsule when status signals are off.
- [ ] `--task-status-file` renders the left task light without extending the default MEM / CPU / NET lane rotation.
- [ ] `--long-run` renders the right keepalive light and still leaves display sleep untouched.

## Compatibility

- [ ] MacBook Air 13-inch checked.
- [ ] MacBook Air 15-inch checked.
- [ ] MacBook Pro 14-inch checked.
- [ ] MacBook Pro 16-inch checked.
- [ ] Rectangular external display no-op checked.
- [ ] Fullscreen video/game/screen-share hide behavior checked.
- [ ] Sleep/wake restoration checked.

## Release Artifact

v0.1 can start with source-only instructions, but the first user-friendly
release should add:

- [ ] `.app` bundle
- [ ] icon
- [ ] versioned zip or dmg
- [ ] checksum
- [ ] signing / notarization notes, even if the first build is unsigned

## Validation

Run before tagging:

```sh
swift build
swift test
swift build -c release
swiftlint lint --quiet
shellcheck Tools/veil-task-run Tools/veil-codex-task Tools/veil-claude-task Tests/Tools/task-status-wrapper-smoke.sh
gitleaks detect --source . --no-git --redact --verbose
python3 -m py_compile Tools/fit-apple-display-corner.py Tools/fit-apple-notch-island.py
Tests/Tools/task-status-wrapper-smoke.sh
git diff --check
```

Record the test count and macOS version in the release notes.
