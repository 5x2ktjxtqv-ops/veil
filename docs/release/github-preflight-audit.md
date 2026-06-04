# GitHub Preflight Audit

状态：Local audit complete; GitHub repo private at audit time  
日期：2026-06-04

## Scope

This audit covers the current local Veil working tree and the private GitHub
repository `5x2ktjxtqv-ops/veil`.

The GitHub repository was private at audit time. The safe release remote is
configured as fetch-only from the development working tree, and local `main`
should not be pushed directly because it contains old history and a large dirty
worktree. Public launch should continue through a regenerated clean release
copy.

## Tooling

Installed and ran:

- `gitleaks 8.30.1`
- `shellcheck 0.11.0`
- `swiftlint 0.63.3`
- Swift Package Manager build and test
- Python bytecode syntax check for helper tools
- Ruby YAML parse check for the GitHub Actions workflow
- `rg` keyword scans for personal traces and secret-like strings
- `git diff --check`

## Results

Passed:

- `swift test` passed 213 XCTest tests.
- `swift build -c release` passed.
- `gitleaks detect --source . --no-git --redact --verbose` found no leaks.
- `shellcheck` passed for task wrapper scripts.
- Python helper scripts compile with `py_compile`.
- `Tests/Tools/task-status-wrapper-smoke.sh` passed.
- `.github/workflows/ci.yml` parses as YAML.
- `git diff --check` passed.
- Personal trace scan for historical project/user names and local user paths
  returned no hits.
- Dangerous local file scan found no `.env`, key, certificate, provisioning,
  log, or `.DS_Store` files outside ignored build/git directories.

Warnings:

- `swiftlint lint --quiet` exits 0 but reports advisory warnings for long lines,
  large files/types, and a few style rules. These are quality debt, not release
  blockers.
- GitHub Actions CI must be confirmed on the private repository before flipping
  repository visibility to public.

## Fixes Applied

- Added `.swiftlint.yml` to define a realistic local lint boundary and exclude
  generated build output.
- Fixed ShellCheck `SC1007` in task wrapper path resolution.
- Removed unused model-growth token parsing and configuration. The
  compact-status client remains unauthenticated, local, and opt-in.
- Added CI draft steps for Gitleaks, SwiftLint, ShellCheck, Python syntax,
  task-status wrapper smoke, Swift build/test, release build, and diff check.
- Updated the launch checklist to include the new quality gates.

## Release Decision

The codebase is close to public-ready from a local quality, privacy, and secret
scan perspective.

Do not flip the GitHub repository to public until:

1. The clean release copy is regenerated from this audited tree.
2. The clean copy is pushed to the private GitHub repo.
3. The GitHub Actions workflow is present and passing on the private repository,
   or CI is intentionally deferred and documented.
4. A final `gitleaks` scan is run on the exact clean release copy to be made
   public.
