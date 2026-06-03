# Architecture

## Single wrapper design

The default package is a thin wrapper around `pkgs.opencode`.

The `opencode` wrapper:

- exports `OPENCODE_CONFIG_CONTENT`
- exports `OPENCODE_TUI_CONFIG` pointing at a bundled `tui.json`
- exports `OPENCODE_DISABLE_LSP_DOWNLOAD=true` by default
- preserves standard OpenCode config discovery from global and project locations
- restores bundled custom agents from `nix/config/agents/` through inline runtime config, keeping the bundled catalog focused on `flake-setup`, `opencode-agent-manager`, and `opencode-manager`
- adds bundled opencode skill paths from the installed package
- adds the remote `context7` MCP declaratively
- adds the local `computer-use-mcp` server declaratively
- can add `DISPLAY` to the local `computer-use-mcp` runtime config when Linux virtual display support is enabled
- can add the ZSeven-W OpenPencil MCP endpoint declaratively
- can add the Banani MCP endpoint declaratively with an API key from `extraEnv.BANANI_API_KEY`
- attaches to `OPENCODE_SERVE_URL` with `opencode attach ... --dir "$PWD"` when requested
- prints the Rango extension reminder when computer-use is enabled

`nix/opencode.nix` builds the wrapper. `nix/config/runtime.nix` restores the old runtime defaults and bundled agent set, `nix/config/tui.nix` restores the bundled TUI keybinds, and `nix/config/mcp.nix` plus `nix/config/skills.nix` produce the MCP and skills fragments that the wrapper exports through `OPENCODE_CONFIG_CONTENT`.

OpenCode merges configuration sources instead of replacing them. The wrapper does not set `OPENCODE_CONFIG`, `OPENCODE_CONFIG_DIR`, `HOME`, or `XDG_CONFIG_HOME`, so normal discovery still applies for `~/.config/opencode/opencode.json`, project `opencode.json`, and `.opencode/`. The bundled Nix config is added as the inline `OPENCODE_CONFIG_CONTENT` layer, so standard locations are still read, but bundled keys win on conflicts.

Bundled skills live in `nix/skills/` and are packaged to `share/opencode/skills`, which keeps them out of the project-local `.opencode/` tree while still making them available to the wrapped install.

The LM Studio provider config is bundled in `nix/config/runtime.nix` and uses OpenCode variable substitution with `OPENCODE_PLATFORM_TOKEN` instead of a hardcoded secret.

The optional OpenPencil skill is packaged separately from the upstream `ZSeven-W/openpencil-skill` repository and contributes its `skills/` contents under `share/opencode/skills` only when explicitly enabled.

## Service modules

- `nix/modules/system/darwin.nix` contains Darwin launchd behavior
- `nix/modules/system/linux.nix` contains Linux systemd behavior reused by Home Manager and NixOS
- Home Manager and NixOS services use a small launcher script that exports service environment, then execs the wrapped `opencode` package with `serve` arguments
- the same service layer can also run a separate VS Code web service, defaulting to `openvscode-server` and reusing the opencode password source while keeping that service outside the opencode wrapper/config stack
- on Linux, that launcher can either export an existing X11 `DISPLAY` to `computer-use-mcp` or manage a lightweight Xvfb + Openbox desktop before starting `opencode serve`
- when the managed Linux desktop flow enables the browser option, the launcher also starts the packaged Chromium-with-Rango wrapper inside that virtual desktop

## Platform defaults

- `nix run .` enables `computer-use-mcp`
- `nix run .` enables the ZSeven-W OpenPencil MCP endpoint and skill
- Home Manager enables `computer-use-mcp` by default
- NixOS enables `computer-use-mcp` by default
- Home Manager enables the ZSeven-W OpenPencil MCP endpoint and skill by default
- NixOS enables the ZSeven-W OpenPencil MCP endpoint and skill by default

Linux computer use should be treated as a desktop/X11 feature, not a headless server feature.

The Linux virtual desktop path is intentionally lightweight: Xvfb provides the X server, Openbox provides a minimal window manager, and the optional browser wrapper loads an unpacked packaged Rango extension into Chromium. This keeps the change inside the existing wrapper and service-launcher layers instead of pushing desktop orchestration into the application package itself.

When enabled, OpenPencil is configured as a remote MCP at `http://127.0.0.1:3100/mcp`, matching the default endpoint exposed by a running ZSeven-W OpenPencil desktop or web instance. The old standalone `@open-pencil/mcp` packaging and `OPENPENCIL_MCP_ROOT` scoping are no longer used.

When enabled, Banani is configured as a remote MCP entry named `banani` at `https://app.banani.co/api/mcp/mcp` by default. The runtime MCP config sends `Authorization: Bearer {env:BANANI_API_KEY}` and the service modules assert that `extraEnv.BANANI_API_KEY` is present before evaluation succeeds.
