# vb — Agent Guide

`vb` is a Ruby CLI tool for managing isolated development workspaces for AI coding agents.
It wraps **jj workspaces** (for VCS isolation) and **vibe VMs** (for sandboxed execution).

## What this tool does

- Creates and manages a **pool of reusable jj workspaces**, each with its own vibe VM disk image
- Workspaces are **warm** (VM disk persists between uses, tools stay installed)
- Tracks workspace state in `~/.local/share/vb/{repo-id}/state.json`
- Provides `status`, `destroy`, and auto-cleanup lifecycle commands
- Detects in-use workspaces by scanning running processes
- Handles dependency freshness by comparing lockfile hashes

## Repo structure

```
exe/
  vb                        # executable entry point (binstub)
lib/
  vb.rb                     # main require file
  vb/
    cli.rb                # Thor subcommands: acquire, status, destroy, return
    pool.rb               # acquire, release, list, destroy logic
    state.rb              # read/write/lock state.json
    workspace.rb          # jj workspace add/forget, CoW copy of .vibe/
    vm.rb                 # vibe invocation, --mount/--send/--expect args
    process.rb            # in-use detection via `ps` scanning
    deps.rb               # lockfile hash comparison, install commands
    names.rb              # friendly name generation (swift-falcon etc.)
test/
  vb/
    pool_test.rb
    state_test.rb
    workspace_test.rb
    vm_test.rb
    process_test.rb
    deps_test.rb
    names_test.rb
  helper.rb
Gemfile
vb.gemspec
```

## Core workflow

```
vb [name]          →  acquire: find available warm workspace or create new one
                       reset jj to latest, check lockfiles, launch vibe
vb status          →  show all workspaces: available / in-use / dirty
vb destroy [name]  →  jj workspace forget + rm disk image + remove from state
vb destroy --all   →  destroy all workspaces for current repo
```

## Development rules (for AI agents)

### TDD — strict red-green cycle

1. **Write a failing test first.** Never write implementation code without a failing test.
2. **Run the test, confirm it fails** (for the right reason — not a syntax error).
3. **Write the minimum code to make it pass.**
4. **Run the test again, confirm it passes.**
5. **Refactor** if needed, keeping tests green.

Do not skip steps. Do not write tests after the fact. Do not write more than one test before making it pass.

**This rule applies to bug fixes too.** Before fixing any bug:
1. Write a test that fails because of the bug (reproduces the exact failure).
2. Confirm the test fails.
3. Apply the fix.
4. Confirm the test passes.

Never fix a bug without a reproducing test. A bug without a test will regress.

### Test tooling

- **TLDR** (`https://github.com/tendersearls/tldr`) for all tests
- `bundle exec tldr` to run the full suite
- `bundle exec tldr test/vb/foo_test.rb` to run a single file
- `bundle exec tldr test/vb/foo_test.rb:13` to run a test at a specific line
- Tests inherit from `TLDR` base class with Minitest-style assertions (`assert`, `assert_equal`, `refute`, etc.)
- Tests use `def test_*` method naming (not describe/it blocks)
- `setup` and `teardown` methods for per-test hooks
- Tests must not shell out to real `jj`, `vibe`, or `git` — use doubles/stubs
- Test helper: `test/helper.rb` (auto-loaded by TLDR)
- Integration tests (if any) are in `test/integration/` and clearly marked

### Code style

- Ruby stdlib only where possible — minimize gem dependencies
- No Rails, no ActiveSupport
- Use `require_relative` for internal requires
- Keep classes small and single-purpose
- Prefer keyword arguments for anything with 2+ parameters

### Commits — atomic, via jj

- This project uses **jujutsu (`jj`)** for version control, not `git`
- Every logical change must be committed atomically — one concern per commit
- After each TDD cycle (test passes + StandardRB clean), commit:
  - `jj commit -m "Add Names: friendly name generation"`
  - `jj commit -m "Add State: JSON read/write with file locking"`
- Commit messages: imperative mood, concise, no prefix conventions needed
- Do **not** use `git commit` — always `jj commit`
- `jj log` to view history, `jj status` to see working copy changes

### Linting and formatting

- Use **StandardRB** (`https://github.com/standardrb/standard`) as the single source of truth for formatting and linting
- Run `bundle exec standardrb` to check
- Run `bundle exec standardrb --fix` to auto-fix
- All code must pass StandardRB with zero offenses before committing
- Do not add a `.rubocop.yml` — StandardRB manages its own config

### External commands

- All `jj`, `vibe`, `git`, `ps` invocations go through thin wrapper methods
  (in `workspace.rb`, `vm.rb`, `process.rb`) — never shell out from business logic
- This makes the entire business logic testable without real tools

### State

- State file: `~/.local/share/vb/{sha256(repo_root)[0..5]}/state.json`
- Always read/write state inside `State.with_lock { }` to prevent races
- Heal state on every read (remove entries for missing workspace dirs)

### Naming

- Workspace names: `{adj}-{noun}` (swift-falcon) by default, or user-provided
- Workspace dirs: `{parent_of_repo}/{repo_name}-{workspace_name}/`
- Friendly names live in `names.rb` — do not hardcode them elsewhere
