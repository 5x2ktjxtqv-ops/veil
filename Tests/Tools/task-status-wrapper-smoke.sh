#!/bin/sh
set -eu

repo_root="$(CDPATH='' cd "$(dirname "$0")/../.." && pwd)"
wrapper="$repo_root/Tools/veil-task-run"
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/veil-task-status.XXXXXX")"
status_file="$tmp_dir/task-status.json"

cleanup() {
    rm -rf "$tmp_dir"
}
trap cleanup EXIT INT TERM

"$wrapper" --status-file "$status_file" --tool test --message "success" -- /bin/sh -c 'exit 0'

if ! grep -q '"state":"succeeded"' "$status_file"; then
    echo "expected succeeded status" >&2
    cat "$status_file" >&2
    exit 1
fi

if ! grep -q '"tool":"test"' "$status_file"; then
    echo "expected test tool label" >&2
    cat "$status_file" >&2
    exit 1
fi

set +e
"$wrapper" --status-file "$status_file" --tool test --message "failure" -- /bin/sh -c 'exit 7'
exit_code="$?"
set -e

if [ "$exit_code" -ne 7 ]; then
    echo "expected wrapped exit code 7, got $exit_code" >&2
    exit 1
fi

if ! grep -q '"state":"failed"' "$status_file"; then
    echo "expected failed status" >&2
    cat "$status_file" >&2
    exit 1
fi

if ! grep -q '"message":"exit 7"' "$status_file"; then
    echo "expected failed exit detail" >&2
    cat "$status_file" >&2
    exit 1
fi
