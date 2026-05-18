# Architecture

## Wrapper-first design

The default package is a thin wrapper around `pkgs.opencode`.

The wrapper:

- exports `OPENCODE_CONFIG_CONTENT`
- preserves the checked-in `opencode.json`
- adds bundled opencode skill paths from the installed package
- adds the remote `context7` MCP declaratively
- adds the local `computer-use-mcp` server declaratively
- prints the Rango extension reminder when computer-use is enabled

Bundled skills live in `nix/skills/` and are packaged to `share/opencode/skills`, which keeps them out of the project-local `.opencode/` tree while still making them available to the wrapped install.

## Service modules

- Home Manager uses `launchd.agents` on Darwin
- Home Manager uses `systemd.user.services` on Linux
- NixOS uses a system service running `opencode serve`

## Platform defaults

- `nix run .` enables `computer-use-mcp`
- Home Manager enables `computer-use-mcp` by default on Darwin
- Home Manager disables it by default on Linux
- NixOS disables it by default because headless Linux is not a good default for desktop automation

Linux computer use should be treated as a desktop/X11 feature, not a headless server feature.
