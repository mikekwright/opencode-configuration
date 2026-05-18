# opencode-configuration

This flake packages `opencode`, exposes service modules, and wires in declarative MCP integrations.

## Usage

Run opencode from this repository:

```bash
nix run .
```

Open the development shell:

```bash
nix develop
```

Start the web UI locally:

```bash
nix run . -- web
```

Expose the web UI on your network with a password:

```bash
OPENCODE_SERVER_PASSWORD=secret nix run . -- web --hostname 0.0.0.0 --port 4096
```

## Flake outputs

- `packages.<system>.default` – wrapped `opencode`
- `packages.<system>.computer-use-mcp` – packaged MCP server
- `packages.<system>.opencode-skills` – bundled opencode skills package
- `homeManagerModules.default` – Home Manager module for Darwin and Linux
- `nixosModules.default` – NixOS module for a headless Linux service

## Bundled runtime additions

- `context7` is enabled by default as a remote MCP at `https://mcp.context7.com/mcp`
- `computer-use-mcp` is available as a local packaged MCP
- bundled skills are installed from `$out/share/opencode/skills`
- the initial bundled skill is `devenv-2`

## Adding future bundled skills

- add the skill under `nix/skills/<skill-name>/SKILL.md`
- keep supporting docs as `notes.md`, `examples.md`, or similar in the same folder
- the packaging layer copies `nix/skills/` into the installed opencode skill bundle

## `extraEnv` explained

`extraEnv` is a Nix attribute set of environment variables that the wrapper exports before launching opencode.

Use it for normal runtime environment variables such as provider API keys, feature flags, or a custom HTTP auth username.

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

`computer-use-mcp` is enabled by default on Darwin. On Linux it is available, but disabled by default because it expects an interactive X11 session.

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

### NixOS: minimal

```nix
{
  imports = [ inputs.opencode-configuration.nixosModules.default ];

  services.opencode.enable = true;
}
```

The NixOS service runs `opencode serve` and leaves `computer-use-mcp` disabled by default.

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

## Rango browser extension

When `computer-use-mcp` is enabled, the wrapper prints a reminder to install the Rango browser extension:

https://chromewebstore.google.com/detail/rango/lnemjdnjjofijemhdogofbpcedhgcpmb
