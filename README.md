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

## Home Manager example

```nix
{
  imports = [ inputs.opencode-configuration.homeManagerModules.default ];

  services.opencode = {
    enable = true;
    service.enable = true;
  };
}
```

`computer-use-mcp` is enabled by default on Darwin. On Linux it is available, but disabled by default because it expects an interactive X11 session.

## NixOS example

```nix
{
  imports = [ inputs.opencode-configuration.nixosModules.default ];

  services.opencode.enable = true;
}
```

The NixOS service runs `opencode serve` and leaves `computer-use-mcp` disabled by default.

## Rango browser extension

When `computer-use-mcp` is enabled, the wrapper prints a reminder to install the Rango browser extension:

https://chromewebstore.google.com/detail/rango/lnemjdnjjofijemhdogofbpcedhgcpmb
