# Architecture

## Single wrapper design

The default package is a thin wrapper around `pkgs.opencode`.

The `opencode` wrapper:

- exports `OPENCODE_CONFIG_CONTENT`
- preserves the checked-in `opencode.json`
- adds bundled opencode skill paths from the installed package
- adds the remote `context7` MCP declaratively
- adds the local `computer-use-mcp` server declaratively
- can add the local `open-pencil-mcp` server declaratively
- prints the Rango extension reminder when computer-use is enabled

`nix/opencode.nix` builds the wrapper. `nix/config/mcp.nix` and `nix/config/skills.nix` produce the config fragments that the wrapper merges into the final runtime configuration.

Bundled skills live in `nix/skills/` and are packaged to `share/opencode/skills`, which keeps them out of the project-local `.opencode/` tree while still making them available to the wrapped install.

The optional OpenPencil skill is packaged separately from the upstream `open-pencil/skills` repository and contributes its own `share/opencode/skills/open-pencil` path only when explicitly enabled.

## Service modules

- `nix/modules/system/darwin.nix` contains Darwin launchd behavior
- `nix/modules/system/linux.nix` contains Linux systemd behavior reused by Home Manager and NixOS
- Home Manager and NixOS services run the wrapped `opencode` package directly with `serve` arguments

## Platform defaults

- `nix run .` enables `computer-use-mcp`
- `nix run .` enables OpenPencil MCP and the upstream OpenPencil skill
- Home Manager enables `computer-use-mcp` by default on Darwin
- Home Manager disables it by default on Linux
- NixOS disables it by default because headless Linux is not a good default for desktop automation
- Home Manager enables OpenPencil MCP and the upstream OpenPencil skill by default
- NixOS enables OpenPencil MCP and the upstream OpenPencil skill by default

Linux computer use should be treated as a desktop/X11 feature, not a headless server feature.

When enabled, `OPENPENCIL_MCP_ROOT` is passed through the opencode local MCP `environment` field rather than a wrapper script, which keeps the package itself reusable while still allowing per-service path scoping. Home Manager defaults that root to `${config.home.homeDirectory}/Development/designs`; the NixOS module defaults it to `/home/mikewright/Development/designs`.
