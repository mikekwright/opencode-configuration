# Architecture

## Single wrapper design

The default package is a thin wrapper around `pkgs.opencode`.

The `opencode` wrapper:

- exports `OPENCODE_CONFIG_CONTENT`
- preserves the checked-in `opencode.json`
- adds bundled opencode skill paths from the installed package
- adds the remote `context7` MCP declaratively
- adds the local `computer-use-mcp` server declaratively
- prints the Rango extension reminder when computer-use is enabled

`nix/opencode.nix` builds the wrapper. `nix/config/mcp.nix` and `nix/config/skills.nix` produce the config fragments that the wrapper merges into the final runtime configuration.

Bundled skills live in `nix/skills/` and are packaged to `share/opencode/skills`, which keeps them out of the project-local `.opencode/` tree while still making them available to the wrapped install.

## Service modules

- `nix/modules/system/darwin.nix` contains Darwin launchd behavior
- `nix/modules/system/linux.nix` contains Linux systemd behavior reused by Home Manager and NixOS
- Home Manager and NixOS services run the wrapped `opencode` package directly with `serve` arguments

## Platform defaults

- `nix run .` enables `computer-use-mcp`
- Home Manager enables `computer-use-mcp` by default on Darwin
- Home Manager disables it by default on Linux
- NixOS disables it by default because headless Linux is not a good default for desktop automation

Linux computer use should be treated as a desktop/X11 feature, not a headless server feature.
