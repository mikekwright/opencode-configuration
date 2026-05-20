# Architecture

## Single wrapper design

The default package is a thin wrapper around `pkgs.opencode`.

The `opencode` wrapper:

- exports `OPENCODE_CONFIG_CONTENT`
- preserves standard OpenCode config discovery from global and project locations
- adds bundled opencode skill paths from the installed package
- adds the remote `context7` MCP declaratively
- adds the local `computer-use-mcp` server declaratively
- can add the ZSeven-W OpenPencil MCP endpoint declaratively
- prints the Rango extension reminder when computer-use is enabled

`nix/opencode.nix` builds the wrapper. `nix/config/mcp.nix` and `nix/config/skills.nix` produce the config fragments that the wrapper exports through `OPENCODE_CONFIG_CONTENT`.

OpenCode merges configuration sources instead of replacing them. The wrapper does not set `OPENCODE_CONFIG`, `OPENCODE_CONFIG_DIR`, `HOME`, or `XDG_CONFIG_HOME`, so normal discovery still applies for `~/.config/opencode/opencode.json`, project `opencode.json`, and `.opencode/`. The bundled Nix config is added as the inline `OPENCODE_CONFIG_CONTENT` layer, so standard locations are still read, but bundled keys win on conflicts.

Bundled skills live in `nix/skills/` and are packaged to `share/opencode/skills`, which keeps them out of the project-local `.opencode/` tree while still making them available to the wrapped install.

The optional OpenPencil skill is packaged separately from the upstream `ZSeven-W/openpencil-skill` repository and contributes its `skills/` contents under `share/opencode/skills` only when explicitly enabled.

## Service modules

- `nix/modules/system/darwin.nix` contains Darwin launchd behavior
- `nix/modules/system/linux.nix` contains Linux systemd behavior reused by Home Manager and NixOS
- Home Manager and NixOS services use a small launcher script that exports service environment, then execs the wrapped `opencode` package with `serve` arguments

## Platform defaults

- `nix run .` enables `computer-use-mcp`
- `nix run .` enables the ZSeven-W OpenPencil MCP endpoint and skill
- Home Manager enables `computer-use-mcp` by default on Darwin
- Home Manager disables it by default on Linux
- NixOS disables it by default because headless Linux is not a good default for desktop automation
- Home Manager enables the ZSeven-W OpenPencil MCP endpoint and skill by default
- NixOS enables the ZSeven-W OpenPencil MCP endpoint and skill by default

Linux computer use should be treated as a desktop/X11 feature, not a headless server feature.

When enabled, OpenPencil is configured as a remote MCP at `http://127.0.0.1:3100/mcp`, matching the default endpoint exposed by a running ZSeven-W OpenPencil desktop or web instance. The old standalone `@open-pencil/mcp` packaging and `OPENPENCIL_MCP_ROOT` scoping are no longer used.
