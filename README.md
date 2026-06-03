# opencode-configuration

This flake packages `opencode`, exposes service modules, and wires in declarative MCP integrations.

## Usage

Run opencode from this repository:

```bash
nix run .
```

Run code-server from this repository on supported platforms:

```bash
nix run .#code-server
```

Open the development shell:

```bash
nix develop
```

Start the web UI locally:

```bash
nix run . -- serve
```

Expose the web UI on your network with a password:

```bash
OPENCODE_SERVER_PASSWORD=secret nix run . -- serve --hostname 0.0.0.0 --port 4096
```

## Two OpenPencil projects

There are two different projects named OpenPencil, and both GitHub landing pages call out the name collision.

- [`open-pencil/open-pencil`](https://github.com/open-pencil/open-pencil) presents itself as a Figma-compatible visual design editor focused on `.fig` and `.pen` files, real-time collaboration, a standalone `@open-pencil/mcp` package, and the separate `open-pencil/skills` repository.
- [`ZSeven-W/openpencil`](https://github.com/ZSeven-W/openpencil) presents itself as an AI-native vector design tool focused on `.op` files, the `op` CLI, concurrent agent teams, a built-in MCP server exposed by the running app, and the separate `ZSeven-W/openpencil-skill` repository.

This flake now targets `ZSeven-W/openpencil`.

## Flake outputs

- `packages.<system>.default` – wrapped `opencode`
- `packages.<system>.opencode` – wrapped interactive `opencode`
- `packages.<system>.computer-use-mcp` – packaged MCP server
- `packages.<system>.code-server` – upstream `code-server` package when nixpkgs supports the current platform
- `packages.<system>.rango-extension` – packaged unpacked Rango extension bundle
- `packages.<system>.chromium-with-rango` – Linux-only Chromium wrapper for the managed virtual desktop flow
- `packages.<system>.opencode-skills` – bundled opencode skills package
- `packages.<system>.open-pencil-skill` – bundled `ZSeven-W/openpencil-skill` package
- `homeManagerModules.default` – Home Manager module for Darwin and Linux
- `nixosModules.default` – NixOS module for a headless Linux service

Home Manager and NixOS services run the wrapped `opencode` package directly with `serve` arguments.
Both modules can also run `code-server` as a separate service using the same password source as the opencode server.

## Config layering

The wrapper adds the Nix-generated MCP and skills configuration through `OPENCODE_CONFIG_CONTENT`.

OpenCode merges config sources instead of replacing them, so the wrapped package still reads the usual locations as well:

- `~/.config/opencode/opencode.json`
- `OPENCODE_CONFIG`
- project `opencode.json`
- `.opencode/`
- `OPENCODE_CONFIG_DIR`

The wrapper intentionally does not override `HOME`, `XDG_CONFIG_HOME`, `OPENCODE_CONFIG`, or `OPENCODE_CONFIG_DIR`, so bundled config from this flake is layered on top of the standard locations instead of replacing them. Standard locations are still read, but bundled keys win on conflicts because `OPENCODE_CONFIG_CONTENT` loads later.

For services, project-local `opencode.json` and `.opencode/` discovery depends on the configured working directory.

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

The OpenPencil MCP entry expects a running `ZSeven-W/openpencil` desktop or web instance to expose that endpoint.

The bundled LM Studio provider expects `OPENCODE_PLATFORM_TOKEN` in the environment and passes it through OpenCode's `{env:...}` substitution.

## Adding future bundled skills

- add the skill under `nix/skills/<skill-name>/SKILL.md`
- keep supporting docs as `notes.md`, `examples.md`, or similar in the same folder
- the packaging layer copies `nix/skills/` into the installed opencode skill bundle

## `extraEnv` explained

`extraEnv` is a Nix attribute set of environment variables that the wrapper exports before launching opencode.

Use it for normal runtime environment variables such as provider API keys, feature flags, or a custom HTTP auth username.

When `services.opencode.mcp.banani.enable = true`, `extraEnv.BANANI_API_KEY` is required.

Example:

```nix
{
  services.opencode = {
    enable = true;
    extraEnv = {
      ANTHROPIC_API_KEY = "...";
      OPENCODE_SERVER_USERNAME = "michael";
    };
  };
}
```

Passwords can be supplied either way:

- `serverPasswordFile = "/path/to/file";`
- `extraEnv.OPENCODE_SERVER_PASSWORD = "...";`

If both are set, `serverPasswordFile` wins.

For secrets, prefer `serverPasswordFile` over putting the secret directly into `extraEnv`.

## code-server service

Both exposed modules add `services.opencode.codeServer`.

- `enable = true` starts a separate `code-server` service
- `port` defaults to `9998`
- `hostname` defaults to `127.0.0.1`
- `workingDirectory` defaults to the same working directory as the opencode service on that platform
- the service reuses `services.opencode.serverPasswordFile` or `extraEnv.OPENCODE_SERVER_PASSWORD`
- `services.opencode.serverUsername` is ignored because code-server supports password auth, but not a shared username field

If nixpkgs does not provide `code-server` for the current platform, set `services.opencode.codeServer.package` explicitly.

## Feature toggles

`computer-use-mcp` is now enabled by default in the exposed Home Manager and NixOS modules. OpenPencil is enabled by default for both the MCP connection and skill, and can still be disabled independently.

```nix
{
  services.opencode = {
    mcp.enable = false;
    skills.enable = false;
  };
}
```

### Enable OpenPencil MCP only

```nix
{
  services.opencode.mcp.openPencil = {
    enable = true;
    url = "http://127.0.0.1:3100/mcp";
  };
}
```

The default URL matches the MCP endpoint that `ZSeven-W/openpencil` exposes from a running desktop or web instance.
`services.opencode.mcp.openPencil.package` and `services.opencode.mcp.openPencil.root` are now deprecated and ignored.

### Enable Banani MCP

```nix
{
  services.opencode = {
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
  services.opencode.skills.openPencil.enable = true;
}
```

The packaged skill teaches opencode about `.op` files, the `op` CLI, and the layered MCP workflow used by `ZSeven-W/openpencil`.

### Linux virtual display for computer-use-mcp

Both the Home Manager and NixOS modules expose:

```nix
services.opencode.mcp.computerUse.virtualDisplay = {
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

### Enable both OpenPencil additions

```nix
{
  services.opencode = {
    mcp.openPencil = {
      enable = true;
      url = "http://127.0.0.1:3100/mcp";
    };

    skills.openPencil.enable = true;
  };
}
```

## Password sources

### Password from file

```nix
{
  services.opencode = {
    enable = true;
    serverPasswordFile = "/run/secrets/opencode-password";
  };
}
```

### Password from `extraEnv`

```nix
{
  services.opencode = {
    enable = true;
    extraEnv = {
      OPENCODE_SERVER_PASSWORD = "secret";
    };
  };
}
```

## Examples

### Home Manager: minimal

```nix
{
  imports = [ inputs.opencode-configuration.homeManagerModules.default ];

  services.opencode = {
    enable = true;
    web.enable = true;
  };
}
```

`computer-use-mcp` is enabled by default. On Linux it still needs X11, but you can now either point `services.opencode.mcp.computerUse.virtualDisplay.display` at an existing session or enable `services.opencode.mcp.computerUse.virtualDisplay.fullDesktop` for a managed virtual desktop.

### Home Manager: network-accessible service with password file

```nix
{
  imports = [ inputs.opencode-configuration.homeManagerModules.default ];

  services.opencode = {
    enable = true;
    serverPasswordFile = "/run/secrets/opencode-password";
    serverUsername = "michael";

    web = {
      enable = true;
      hostname = "0.0.0.0";
      port = 4096;
    };
  };
}
```

If `web.hostname = "0.0.0.0"` and no password is configured, evaluation will fail.

### Home Manager: extra config and extra environment

```nix
{
  imports = [ inputs.opencode-configuration.homeManagerModules.default ];

  services.opencode = {
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

### Home Manager: run code-server too

```nix
{
  imports = [ inputs.opencode-configuration.homeManagerModules.default ];

  services.opencode = {
    enable = true;
    serverPasswordFile = "/run/secrets/opencode-password";

    codeServer = {
      enable = true;
      port = 9998;
    };
  };
}
```

### NixOS: minimal

```nix
{
  imports = [ inputs.opencode-configuration.nixosModules.default ];

  services.opencode.enable = true;
}
```

The NixOS service runs `opencode serve` through the wrapped package with `computer-use-mcp` enabled by default. On Linux you can now either reuse an existing X11 `DISPLAY` or let the service manage an Xvfb/Openbox desktop.

### NixOS: network-accessible service with password file

```nix
{
  imports = [ inputs.opencode-configuration.nixosModules.default ];

  services.opencode = {
    enable = true;
    hostname = "0.0.0.0";
    port = 4096;
    serverPasswordFile = "/run/secrets/opencode-password";
    serverUsername = "michael";
  };
}
```

If `hostname = "0.0.0.0"` and no password is configured, evaluation will fail.

### NixOS: extra environment

```nix
{
  imports = [ inputs.opencode-configuration.nixosModules.default ];

  services.opencode = {
    enable = true;
    extraEnv = {
      ANTHROPIC_API_KEY = "...";
      OPENCODE_SERVER_USERNAME = "opencode";
      OPENCODE_SERVER_PASSWORD = "secret";
    };
  };
}
```

### NixOS: run code-server too

```nix
{
  imports = [ inputs.opencode-configuration.nixosModules.default ];

  services.opencode = {
    enable = true;
    serverPasswordFile = "/run/secrets/opencode-password";

    codeServer = {
      enable = true;
      port = 9998;
    };
  };
}
```

## Rango browser extension

When `computer-use-mcp` is enabled, the wrapper prints a reminder to install the Rango browser extension:

https://chromewebstore.google.com/detail/rango/lnemjdnjjofijemhdogofbpcedhgcpmb

For the managed Linux virtual desktop flow, this repository also exposes `packages.<system>.chromium-with-rango`. It wraps Chromium and loads an unpacked packaged Rango extension from `packages.<system>.rango-extension`. This is intended for the managed virtual desktop/browser flow only, and it uses a local Chromium profile directory instead of a Chrome Web Store install.

# Possible additions

* There is a claude solution that uses a plugin and then anthropic sdk using [Meridian](https://github.com/rynfar/meridian), this is the [opencode-with-claude](https://github.com/ianjwhite99/opencode-with-claude) plugin.  Might add that in the future.
