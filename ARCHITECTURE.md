# Architecture

## Single wrapper design

The default package is a thin wrapper around `pkgs.opencode`.

The `opencode` wrapper:

- exports `OPENCODE_CONFIG_CONTENT`
- exports `OPENCODE_TUI_CONFIG` pointing at a bundled `tui.json`
- exports `OPENCODE_DISABLE_LSP_DOWNLOAD=true` by default
- preserves standard OpenCode config discovery from global and project locations
- restores bundled custom agents from `nix/config/agents/` through inline runtime config
- adds bundled opencode skill paths from the installed package
- adds the remote `context7` MCP declaratively
- adds the local `computer-use-mcp` server declaratively
- can add `DISPLAY` to the local `computer-use-mcp` runtime config when Linux virtual display support is enabled
- can add the ZSeven-W OpenPencil MCP endpoint declaratively
- can add the Banani MCP endpoint declaratively with an API key from `extraEnv.BANANI_API_KEY`
- attaches to `OPENCODE_SERVE_URL` with `opencode attach ... --dir "$PWD"` when requested
- prints the Rango extension reminder when computer-use is enabled

`nix/opencode.nix` builds the wrapper. `nix/config/runtime.nix` restores the runtime defaults and bundled agent set, `nix/config/tui.nix` restores the bundled TUI keybinds, and `nix/config/mcp.nix` plus `nix/config/skills.nix` produce the MCP and skills fragments that the wrapper exports through `OPENCODE_CONFIG_CONTENT`.

OpenCode merges configuration sources instead of replacing them. The wrapper does not set `OPENCODE_CONFIG`, `OPENCODE_CONFIG_DIR`, `HOME`, or `XDG_CONFIG_HOME`, so normal discovery still applies for `~/.config/opencode/opencode.json`, project `opencode.json`, and `.opencode/`. The bundled Nix config is added as the inline `OPENCODE_CONFIG_CONTENT` layer, so standard locations are still read, but bundled keys win on conflicts.

## Service modules

The public module interface is `services.aiagent`.

- `services.aiagent.opencode` manages the wrapped `opencode serve` service
- `services.aiagent.openvscode` manages `openvscode-server`
- `services.aiagent.nginx` manages a reverse proxy that routes by `Host` header
- Home Manager uses launchd on Darwin and systemd user services on Linux
- NixOS uses systemd services

The intended remote topology is:

```text
tailnet DNS -> nginx -> Host: <opencode domain> -> opencode
tailnet DNS -> nginx -> Host: <openvscode domain> -> openvscode-server
```

The modules deliberately keep:

- `opencode` on its wrapper/config-layering stack
- `openvscode-server` outside the wrapper stack
- `nginx` as infrastructure around the two backends

That separation preserves the existing opencode wrapper architecture instead of mixing proxy concerns into the application package.

## Host-based routing

`services.aiagent.opencode.domain` and `services.aiagent.openvscode.domain` are consumed by the generated nginx config.

- enabled domains must be unique
- both domains are expected to resolve to the same nginx listener
- backends default to loopback
- nginx can bind to `listenAddress = "tailscale"` by resolving `tailscale ip -4` at service start, with `127.0.0.1` as the fallback
- nginx is the only service intended to bind beyond loopback

The current design does not manage `tailscale serve`, DNS, or TLS certificates for custom domains. Those are expected to be handled outside this flake.

## Platform defaults

- `nix run .` enables `computer-use-mcp`
- `nix run .` enables the ZSeven-W OpenPencil MCP endpoint and skill
- Home Manager enables `computer-use-mcp` by default for `services.aiagent.opencode`
- NixOS enables `computer-use-mcp` by default for `services.aiagent.opencode`
- Home Manager enables the ZSeven-W OpenPencil MCP endpoint and skill by default
- NixOS enables the ZSeven-W OpenPencil MCP endpoint and skill by default

Linux computer use should be treated as a desktop/X11 feature, not a headless server feature.

The Linux virtual desktop path is intentionally lightweight: Xvfb provides the X server, Openbox provides a minimal window manager, and the optional browser wrapper loads an unpacked packaged Rango extension into Chromium. This keeps the change inside the existing wrapper and service-launcher layers instead of pushing desktop orchestration into the application package itself.
