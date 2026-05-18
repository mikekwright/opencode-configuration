---
name: devenv-2
description: devenv, devenv 2, devenv.sh, devenv.nix, devenv.yaml, devenv.lock, devenv shell, devenv up, devenv test, devenv tasks, devenv processes. Use ONLY when creating, editing, migrating, or troubleshooting devenv-based developer environments.
---

# devenv 2

Use this skill when the task is specifically about `devenv.sh` or files and commands from the devenv 2 workflow.

## When to use

- The user mentions `devenv`, `devenv 2`, or `devenv.sh`.
- The repo contains `devenv.nix`, `devenv.yaml`, `devenv.lock`, or a flake using `devenv.lib.mkShell` or `devenv.flakeModule`.
- The work involves `devenv shell`, `devenv up`, `devenv test`, `devenv tasks run`, `devenv update`, or `devenv mcp`.
- The user is migrating old `process-compose` or devenv 1.x patterns to devenv 2.

## Default stance

- Prefer the dedicated devenv CLI for day-to-day developer environment work.
- Treat flake integration as an integration path for existing flake-based repos, not the default recommendation for new devenv usage.
- Preserve the repository's current architecture. If a repo is already flake-based, integrate with that pattern instead of forcing a CLI-only redesign.
- Keep changes declarative and minimal.

## Files to inspect first

- `devenv.nix`
- `devenv.yaml`
- `devenv.lock`
- `.envrc`
- `flake.nix`

## Preferred commands

- `devenv init`
- `devenv shell`
- `devenv up`
- `devenv processes wait --timeout 120`
- `devenv processes down`
- `devenv test`
- `devenv tasks run <task>`
- `devenv info`
- `devenv search <term>`
- `devenv update`
- `devenv build <attr>`
- `devenv eval <attr>`
- `devenv repl`

If the repository uses flake integration, expect `nix develop --no-pure-eval` instead of plain `devenv shell`.

## Authoring guidance

### CLI-first projects

For standard devenv projects, prefer the default file set:

- `devenv.nix`
- `devenv.yaml`
- `devenv.lock`
- optional `.envrc`

Use `devenv init` conventions unless the repo already has an established structure.

### Flake-based projects

- Use `devenv.lib.mkShell` or `devenv.flakeModule` when the repo already exposes flake outputs.
- Remember that flake mode has limitations relative to the dedicated CLI.
- With flake shells, use `nix develop --no-pure-eval` unless the project has an explicit workaround.
- Do not recommend flake integration as the first choice unless the repo already needs it.

## What to prefer in devenv 2

### Tasks

- Prefer `tasks.<namespace:task>` for repeatable workflow steps.
- Use `before = [ "devenv:enterShell" ]` for setup that must happen before interactive work.
- Use `before = [ "devenv:enterTest" ]` for test preparation.
- Use `status` to skip expensive reruns when work is already done.
- Use `execIfModified` when the task should rerun only for relevant file changes.
- Use `${config.git.root}` for monorepo-safe paths.

### Processes

- Prefer declarative `processes.*` over ad hoc shell orchestration.
- Use `after` dependencies instead of hard-coded sleeps.
- Add `ready` probes for services or servers that other processes depend on.
- Use `restart` policies intentionally.
- Use `watch` for local developer autoreload behavior when appropriate.
- Use `ports.<name>.allocate` for conflict-resistant local ports.
- Prefer built-in services when devenv already provides one.

### Services and tests

- Use `services.*` modules when available instead of hand-rolled process definitions.
- Prefer `devenv test` for environment verification.
- For process-heavy validation, pair `devenv up` with `devenv processes wait`.

## Migration notes for devenv 2

- The native process manager is the default in devenv 2.
- Old `processes.<name>.process-compose.*` settings may need translation to native `after`, `restart`, `env`, `cwd`, and `ready` fields.
- If a project still depends on process-compose behavior, use:

```nix
{
  process.manager.implementation = "process-compose";
}
```

- `git-hooks` is no longer an implicit input. Add it explicitly in `devenv.yaml` if hooks are used.
- `pre-commit` invocations should generally become `prek`.
- `devenv build` now returns JSON, so scripts may need `jq` extraction.
- `devenv container --copy <name>` became `devenv container copy <name>`.

## Flake caveats

- Flake mode is less flexible than the dedicated devenv CLI.
- `nix develop --no-pure-eval` is commonly required because pure flake evaluation restricts devenv's environment detection.
- `devenv test` inside flake workflows does not support starting processes the same way the dedicated CLI does.

## Validation checklist

Pick the smallest relevant set:

- `devenv test`
- `devenv tasks run <task>`
- `devenv up`
- `devenv processes wait --timeout 120`
- `devenv processes down`
- `devenv build <attr>`
- `devenv eval <attr>`
- `nix develop --no-pure-eval` for flake-integrated repos

## Reference reminders

- Start with the official docs at `https://devenv.sh/`.
- Prefer current devenv 2 docs over older blog posts or stale examples.
- When unsure about option names, confirm them in the devenv reference instead of guessing.
