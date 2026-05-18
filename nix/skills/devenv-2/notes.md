# Source notes

This skill was based on the current devenv.sh docs, especially:

- `https://devenv.sh/`
- `https://devenv.sh/getting-started/`
- `https://devenv.sh/guides/using-with-flakes/`
- `https://devenv.sh/guides/migrating-to-2.0/`
- `https://devenv.sh/tasks/`
- `https://devenv.sh/processes/`

Key takeaways reflected in the skill:

- Prefer the dedicated devenv CLI for normal workflow.
- Use flake integration when the repository already needs flake-based outputs.
- Treat tasks and processes as first-class devenv 2 workflow primitives.
- Remember the devenv 2 migration points: native process manager, `prek`, JSON `devenv build`, and explicit `git-hooks` input.
