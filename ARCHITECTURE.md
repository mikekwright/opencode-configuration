# Architecture

## Single wrapper design

The default package is a thin wrapper around `pkgs.opencode`.

The `opencode` wrapper:

- exports `OPENCODE_CONFIG_CONTENT`
- exports `OPENCODE_TUI_CONFIG` pointing at a bundled `tui.json`
- exports `OPENCODE_DISABLE_LSP_DOWNLOAD=true` by default
- preserves standard OpenCode config discovery from global and project locations
- restores bundled custom agents from `nix/config/agents/` through inline runtime config
- can add managed plugin paths such as Meridian declaratively through inline runtime config
- adds bundled opencode skill paths from the installed package
- adds the remote `context7` MCP declaratively
- adds the local `computer-use-mcp` server declaratively
- can add `DISPLAY` to the local `computer-use-mcp` runtime config when Linux virtual display support is enabled
- can add the ZSeven-W OpenPencil MCP endpoint declaratively
- can add the Banani MCP endpoint declaratively with an API key from `services.aiagent.extraEnvs` or `services.aiagent.opencode.extraEnv`
- attaches to `OPENCODE_SERVE_URL` with `opencode attach ... --dir "$PWD"` when requested
- prints the Rango extension reminder when computer-use is enabled

`nix/opencode.nix` builds the wrapper. `nix/config/runtime.nix` restores the runtime defaults and bundled agent set, `nix/config/tui.nix` restores the bundled TUI keybinds, and `nix/config/mcp.nix` plus `nix/config/skills.nix` produce the MCP and skills fragments that the wrapper exports through `OPENCODE_CONFIG_CONTENT`.

OpenCode merges configuration sources instead of replacing them. The wrapper does not set `OPENCODE_CONFIG`, `OPENCODE_CONFIG_DIR`, `HOME`, or `XDG_CONFIG_HOME`, so normal discovery still applies for `~/.config/opencode/opencode.json`, project `opencode.json`, and `.opencode/`. The bundled Nix config is added as the inline `OPENCODE_CONFIG_CONTENT` layer, so standard locations are still read, but bundled keys win on conflicts.

## Module shape

The public module interface is `services.aiagent`.

- `services.aiagent.opencode` manages package selection plus wrapper config such as MCP, skills, extra config, and wrapper env
- `services.aiagent.openvscode` manages package selection for `openvscode-server`
- `services.aiagent.servers.opencode` manages the `opencode serve` background service
- `services.aiagent.servers.openvscode` manages the `openvscode-server` background service
- `services.aiagent.extraEnvs` is shared service environment passed into all launchers and used as the base env for the wrapped `opencode` package
- Home Manager uses launchd on Darwin and systemd user services on Linux
- NixOS uses systemd services

This keeps package installation separate from service lifecycle while preserving the existing wrapper/config-layering architecture for OpenCode.

## Direct binding

The managed stack now binds services directly instead of generating a reverse proxy layer.

- `services.aiagent.servers.opencode.hostname` and `services.aiagent.servers.openvscode.hostname` default to loopback
- each service also supports `hostname = "tailscale"`
- the launcher resolves `tailscale ip -4` at service start
- if the `tailscale` CLI is not available in `PATH`, or no IPv4 address is returned, the service logs a message and fails to start
- enabled services must use distinct ports
- non-loopback OpenCode binds require a password source

The current design does not manage `tailscale serve`, DNS, TLS certificates, or any reverse proxy.

## Platform defaults

- `nix run .` enables `computer-use-mcp`
- `nix run .` enables the ZSeven-W OpenPencil MCP endpoint and skill
- Home Manager enables `computer-use-mcp` by default for `services.aiagent.opencode`
- NixOS enables `computer-use-mcp` by default for `services.aiagent.opencode`
- Home Manager enables the ZSeven-W OpenPencil MCP endpoint and skill by default
- NixOS enables the ZSeven-W OpenPencil MCP endpoint and skill by default

Linux computer use should be treated as a desktop/X11 feature, not a headless server feature.

The Linux virtual desktop path is intentionally lightweight: Xvfb provides the X server, Openbox provides a minimal window manager, and the optional browser wrapper loads an unpacked packaged Rango extension into Chromium. This keeps the change inside the existing wrapper and service-launcher layers instead of pushing desktop orchestration into the application package itself.
