# Task Status File Adapter

状态：Implemented public local adapter  
日期：2026-06-04

## Purpose

The task status file adapter lets local AI coding runners, build wrappers, and
shell scripts drive Veil's left notch indicator without giving Veil access to
terminal history, logs, process trees, or tool-specific APIs.

This is the public adapter shape for vibe-coding task awareness. Claude Code,
Codex, local CI scripts, and custom runners should all be treated as producers
of the same tiny local JSON file.

## Enable

```sh
swift run Veil -- --task-status-file ~/.local/state/veil/task-status.json
```

Or use the default file path:

```sh
swift run Veil -- --task-status
```

Default path:

```text
~/.local/state/veil/task-status.json
```

Environment variables:

```sh
VEIL_TASK_STATUS=1 swift run Veil
VEIL_TASK_STATUS_FILE="$HOME/.local/state/veil/task-status.json" swift run Veil
VEIL_TASK_STATUS_POLL_SECONDS=2 swift run Veil
VEIL_TASK_STATUS_STALE_SECONDS=21600 swift run Veil
```

## Payload

Minimum:

```json
{
  "state": "running"
}
```

Recommended:

```json
{
  "state": "running",
  "tool": "codex",
  "message": "swift test",
  "updated_at": "2026-06-04T00:00:00Z"
}
```

Accepted field aliases:

| Canonical | Aliases |
| --- | --- |
| `state` | `status` |
| `tool` | `label` |
| `message` | `detail` |
| `updated_at` | `updatedAt`, `timestamp`, `time` |

`updated_at` can be an ISO-8601 timestamp or Unix epoch seconds.

## States

| Input examples | Normalized state | Light |
| --- | --- | --- |
| `running`, `working`, `in_progress`, `queued` | `running` | yellow pulse |
| `success`, `succeeded`, `done`, `completed`, `passed` | `succeeded` | green steady |
| `failed`, `error`, `cancelled` | `failed` | red fast pulse |
| `warning`, `blocked`, `needs_attention` | `attention` | yellow fast pulse |
| `stale`, `timeout`, `timed_out` | `stale` | yellow fast pulse |
| `idle`, `inactive`, `none`, `off` | `inactive` | no light |

If `state`/`status` is absent and `ok` is present, `ok: true` maps to
`succeeded` and `ok: false` maps to `failed`.

## Producer Pattern

Use atomic writes so Veil never reads a half-written file:

```sh
mkdir -p ~/.local/state/veil
tmp="$(mktemp ~/.local/state/veil/task-status.XXXXXX)"
printf '{"state":"running","tool":"codex","message":"swift test","updated_at":"%s"}\n' \
  "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" > "$tmp"
mv "$tmp" ~/.local/state/veil/task-status.json
```

When the task completes, write a final state:

```json
{
  "state": "succeeded",
  "tool": "codex",
  "message": "tests passed",
  "updated_at": "2026-06-04T00:05:00Z"
}
```

## Wrapper Examples

Veil includes small producer wrappers in `Tools/`. They write `running` before
starting a command, write `succeeded` or `failed` after the command exits, and
return the wrapped command's original exit code.

Generic command wrapper:

```sh
Tools/veil-task-run --tool build --message "swift test" -- swift test
```

Codex wrapper:

```sh
Tools/veil-codex-task --message "repo audit" -- exec "run tests and fix failures"
```

Claude Code wrapper:

```sh
Tools/veil-claude-task --message "docs pass" -- "update README examples"
```

Each wrapper accepts `--status-file FILE` when you do not want to use the
default status file. `--message` should be a short user-owned label; do not put
full prompts, terminal output, secrets, or paths in it.

## Privacy Boundary

Veil only reads the configured file. It does not:

- inspect terminal scrollback
- read Claude Code or Codex internal files
- scan process arguments
- run arbitrary commands
- upload task state

The payload should stay compact. Put only status words that are safe to show in
the notch area; do not write prompts, secrets, repository paths, or log output.
