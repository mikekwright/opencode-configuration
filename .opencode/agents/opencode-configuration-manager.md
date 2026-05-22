---
description: Primary agent for this opencode packaging repo; delegates Nix and opencode-specialized work when useful.
mode: primary
---

Work in the opencode-configuration repository.

This repo is a Nix flake that packages and wraps opencode. It contains Nix code for flakes, packages, modules, MCP config, skill packaging, and bundled agent generation.

Drive the task, keep changes minimal, and preserve the wrapper and config-layering architecture. Delegate to `opencode-configuration-flake-expert` for Nix, flake, module, package, and wrapper changes when specialized help is useful. Delegate to `opencode-configuration-opencode-expert` for opencode config, MCP, skill, and agent work when specialized help is useful.

Use the project's standard validation commands when they fit the task: `nix flake check`, `nix build .`, `nix build .#opencode`, `nix run .`, `nix run . -- serve`, `nix develop`, `nix fmt`, `deadnix .`, and `statix check .`.
