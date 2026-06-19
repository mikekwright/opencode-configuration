# opencode-configuration

This flake packages `opencode`, `openvscode-server`, and `nginx`, then exposes Home Manager and NixOS modules under `services.aiagent` for a remote AI-first development machine.

## Usage

Run wrapped `opencode`:

```bash
nix run .
```

Run `openvscode-server`:

```bash
nix run .#openvscode-server
```

Open the development shell:

```bash
nix develop
```

Start the OpenCode web UI locally:

```bash
nix run . -- serve
```

## Flake outputs

- `packages.<system>.default` – wrapped `opencode`
- `packages.<system>.opencode` – wrapped `opencode`
- `packages.<system>.openvscode-server` – upstream `openvscode-server`
- `packages.<system>.nginx` – upstream `nginx`
- `packages.<system>.computer-use-mcp` – packaged MCP server
- `packages.<system>.rango-extension` – packaged unpacked Rango extension bundle
- `packages.<system>.chromium-with-rango` – Linux-only Chromium wrapper for the managed virtual desktop flow
- `packages.<system>.opencode-skills` – bundled opencode skills package
- `packages.<system>.open-pencil-skill` – bundled `ZSeven-W/openpencil-skill` package
- `apps.<system>.default` – wrapped `opencode`
- `apps.<system>.openvscode-server` – `openvscode-server`
- `homeManagerModules.default` – Home Manager module for Darwin and Linux
- `nixosModules.default` – NixOS module

## Service topology

The managed stack is:

```text
tailnet DNS -> nginx -> Host: <opencode domain> -> opencode
tailnet DNS -> nginx -> Host: <openvscode domain> -> openvscode-server
```

Typical defaults:

- `opencode` listens on `127.0.0.1:4096`
- `openvscode-server` listens on `127.0.0.1:9998`
- `nginx` listens on `127.0.0.1:8123` unless you expose it explicitly

This flake does **not** manage:

- `tailscale serve`
- Tailscale installation
- DNS records
- TLS certificates for custom domains

You are expected to point multiple domains at the same machine and nginx port, then let nginx route by `Host` header.

For the most conservative setup, bind `services.aiagent.nginx.listenAddress` directly to the machine's Tailscale IP instead of `0.0.0.0`, or set it to `"tailscale"` to resolve `tailscale ip -4` when nginx starts and fall back to `127.0.0.1`.

## `services.aiagent`

The public module interface is:

```nix
{
  services.aiagent = {
    opencode = {
      enable = true;
      hostname = "127.0.0.1";
      port = 4096;
      domain = "agent.example.internal";
    };

    openvscode = {
      enable = true;
      hostname = "127.0.0.1";
      port = 9998;
      domain = "code.example.internal";
    };

    nginx = {
      enable = true;
      listenAddress = "tailscale";
      port = 8123;
    };
  };
}
```

Behavior:

- `services.aiagent.opencode.domain` tells nginx which host should proxy to `opencode`
- `services.aiagent.openvscode.domain` tells nginx which host should proxy to `openvscode-server`
- `services.aiagent.nginx.listenAddress = "tailscale"` resolves the first `tailscale ip -4` address when nginx starts and falls back to `127.0.0.1`
- both domains must resolve to the same nginx listener
- enabled services must use distinct ports
- nginx requires at least one enabled backend with a domain

## Config layering

The wrapper adds the Nix-generated MCP and skills configuration through `OPENCODE_CONFIG_CONTENT`.

OpenCode merges config sources instead of replacing them, so the wrapped package still reads the usual locations as well:

- `~/.config/opencode/opencode.json`
- `OPENCODE_CONFIG`
- project `opencode.json`
- `.opencode/`
- `OPENCODE_CONFIG_DIR`

The wrapper intentionally does not override `HOME`, `XDG_CONFIG_HOME`, `OPENCODE_CONFIG`, or `OPENCODE_CONFIG_DIR`, so bundled config from this flake is layered on top of the standard locations instead of replacing them. Standard locations are still read, but bundled keys win on conflicts because `OPENCODE_CONFIG_CONTENT` loads later.

## Authentication defaults

### OpenCode

OpenCode still uses its own password handling:

- `services.aiagent.opencode.serverPasswordFile`
- `services.aiagent.opencode.extraEnv.OPENCODE_SERVER_PASSWORD`

If nginx exposes `services.aiagent.opencode.domain`, evaluation requires one of those password sources.

### OpenVSCode Server

OpenVSCode Server uses a connection token:

- `services.aiagent.openvscode.connectionTokenFile`
- `services.aiagent.openvscode.connectionToken`

Defaults:

- `connectionTokenFile` defaults to `services.aiagent.opencode.serverPasswordFile`
- `connectionToken` defaults to `services.aiagent.opencode.extraEnv.OPENCODE_SERVER_PASSWORD`

So if you already configure an OpenCode password, OpenVSCode Server can reuse it automatically.

## Examples

### Home Manager: local-only OpenCode

```nix
{
  imports = [ inputs.opencode-configuration.homeManagerModules.default ];

  services.aiagent.opencode.enable = true;
}
```

`computer-use-mcp` is enabled by default. On Linux it still needs X11, but you can either point `services.aiagent.opencode.mcp.computerUse.virtualDisplay.display` at an existing session or enable `services.aiagent.opencode.mcp.computerUse.virtualDisplay.fullDesktop` for a managed virtual desktop.

### Home Manager: remote host-based setup on a Tailscale IP

```nix
{
  imports = [ inputs.opencode-configuration.homeManagerModules.default ];

  services.aiagent = {
    opencode = {
      enable = true;
      domain = "agent.dev.internal";
      serverPasswordFile = "/run/secrets/opencode-password";
      serverUsername = "michael";
    };

    openvscode = {
      enable = true;
      domain = "code.dev.internal";
    };

    nginx = {
      enable = true;
      listenAddress = "tailscale";
      port = 8123;
    };
  };
}
```

Point both domains at the machine's current Tailscale IPv4, then access:

- `http://agent.dev.internal:8123`
- `http://code.dev.internal:8123`

Home Manager user services must use ports `>= 1024`.

### Home Manager: extra config and extra environment

```nix
{
  imports = [ inputs.opencode-configuration.homeManagerModules.default ];

  services.aiagent.opencode = {
    enable = true;

    extraConfig = {
      model = "anthropic/claude-sonnet-4-5";
      server.cors = [ "https://example.com" ];
    };

    extraEnv = {
      ANTHROPIC_API_KEY = "...";
      OPENCODE_SERVER_USERNAME = "opencode";
      OPENCODE_SERVER_PASSWORD = "secret";
    };
  };
}
```

### Home Manager: separate OpenVSCode token

```nix
{
  imports = [ inputs.opencode-configuration.homeManagerModules.default ];

  services.aiagent = {
    opencode = {
      enable = true;
      serverPasswordFile = "/run/secrets/opencode-password";
    };

    openvscode = {
      enable = true;
      connectionTokenFile = "/run/secrets/openvscode-token";
    };
  };
}
```

### NixOS: local-only OpenCode

```nix
{
  imports = [ inputs.opencode-configuration.nixosModules.default ];

  services.aiagent.opencode.enable = true;
}
```

### NixOS: remote host-based setup

```nix
{
  imports = [ inputs.opencode-configuration.nixosModules.default ];

  services.aiagent = {
    opencode = {
      enable = true;
      domain = "agent.dev.internal";
      serverPasswordFile = "/run/secrets/opencode-password";
      serverUsername = "michael";
    };

    openvscode = {
      enable = true;
      domain = "code.dev.internal";
    };

    nginx = {
      enable = true;
      listenAddress = "tailscale";
      port = 8123;
    };
  };
}
```

### NixOS: explicit OpenVSCode token

```nix
{
  imports = [ inputs.opencode-configuration.nixosModules.default ];

  services.aiagent = {
    openvscode = {
      enable = true;
      connectionTokenFile = "/run/secrets/openvscode-token";
    };

    nginx = {
      enable = true;
      listenAddress = "tailscale";
      port = 8123;
    };
  };
}
```

## MCP and skills

`services.aiagent.opencode` keeps the existing MCP and skills controls.

### Enable OpenPencil MCP only

```nix
{
  services.aiagent.opencode.mcp.openPencil = {
    enable = true;
    url = "http://127.0.0.1:3100/mcp";
  };
}
```

The default URL matches the MCP endpoint that `ZSeven-W/openpencil` exposes from a running desktop or web instance.
`services.aiagent.opencode.mcp.openPencil.package` and `services.aiagent.opencode.mcp.openPencil.root` are deprecated and ignored.

### Enable Banani MCP

```nix
{
  services.aiagent.opencode = {
    mcp.banani = {
      enable = true;
      url = "https://app.banani.co/api/mcp/mcp";
    };

    extraEnv.BANANI_API_KEY = "...";
  };
}
```

Banani is wired as a remote MCP entry named `banani`. Evaluation fails if Banani is enabled without `extraEnv.BANANI_API_KEY`.

### Enable OpenPencil skill only

```nix
{
  services.aiagent.opencode.skills.openPencil.enable = true;
}
```

### Linux virtual display for computer-use-mcp

Both modules expose:

```nix
services.aiagent.opencode.mcp.computerUse.virtualDisplay = {
  enable = true;
  fullDesktop = true;
  display = null;

  browser = {
    enable = true;
  };
};
```

- `enable` turns on Linux virtual display handling
- `fullDesktop = true` starts a managed Xvfb + Openbox session
- `display` can point at an existing X11 display instead
- if `fullDesktop = true` and `display = null`, the managed default is `:99`
- evaluation fails when `virtualDisplay.enable = true` and neither `fullDesktop` nor `display` is set
- `browser.enable = true` is only valid with `virtualDisplay.enable = true` and `fullDesktop = true`

When `browser.enable = true`, the Linux service launcher starts the configured Chromium wrapper inside the managed virtual desktop.

## Bundled runtime additions

- bundled custom agents are generated from `nix/config/agents/` and currently expose the `flake-setup`, `opencode-agent-manager`, and `opencode-manager` families
- the wrapper exports `OPENCODE_TUI_CONFIG` with bundled `tui.json` keybinds
- the wrapper exports `OPENCODE_DISABLE_LSP_DOWNLOAD=true` by default
- if `OPENCODE_SERVE_URL` is set, the wrapper runs `opencode attach "$OPENCODE_SERVE_URL" --dir "$PWD"`
- `context7` is enabled by default as a remote MCP at `https://mcp.context7.com/mcp`
- `computer-use-mcp` is enabled by default as a local packaged MCP
- Linux services can export a configured X11 `DISPLAY` to `computer-use-mcp` or manage a lightweight Xvfb/Openbox desktop
- bundled skills are installed from `$out/share/opencode/skills`
- the initial bundled skill is `devenv-2`
- OpenPencil is enabled by default as a remote MCP at `http://127.0.0.1:3100/mcp`
- Banani can be enabled as a remote MCP at `https://app.banani.co/api/mcp/mcp`
- the optional OpenPencil skill comes from `ZSeven-W/openpencil-skill`

## Rango browser extension

When `computer-use-mcp` is enabled, the wrapper prints a reminder to install the Rango browser extension:

https://chromewebstore.google.com/detail/rango/lnemjdnjjofijemhdogofbpcedhgcpmb

For the managed Linux virtual desktop flow, this repository also exposes `packages.<system>.chromium-with-rango`. It wraps Chromium and loads an unpacked packaged Rango extension from `packages.<system>.rango-extension`. This is intended for the managed virtual desktop/browser flow only, and it uses a local Chromium profile directory instead of a Chrome Web Store install.
