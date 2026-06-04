{ lib }:
let
  buildMcpConfig = import ./config/mcp.nix { inherit lib; };
  buildRuntimeConfig = import ./config/runtime.nix { inherit lib; };
  buildSkillsConfig = import ./config/skills.nix { inherit lib; };
  tuiConfig = import ./config/tui.nix;
  rangoExtensionUrl = "https://chromewebstore.google.com/detail/rango/lnemjdnjjofijemhdogofbpcedhgcpmb";
  mkEnvExports =
    envVars:
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: value: "export ${name}=${lib.escapeShellArg (toString value)}") envVars
    );
in
{
  pkgs,
  opencodePackage ? pkgs.opencode,
  mcp ? { },
  skills ? { },
  extraConfig ? { },
  extraEnv ? { },
  wrapperName ? "opencode",
}:
let
  baseOpencodePackage = lib.attrByPath [
    "passthru"
    "unwrappedOpencode"
  ] opencodePackage opencodePackage;

  bundledRuntimeConfig = buildRuntimeConfig;

  runtimeConfig = lib.recursiveUpdate (lib.recursiveUpdate bundledRuntimeConfig (
    buildMcpConfig ({ enable = true; } // mcp)
  )) (lib.recursiveUpdate (buildSkillsConfig ({ enable = true; } // skills)) extraConfig);

  tuiConfigFile = pkgs.writeText "opencode-tui.json" (builtins.toJSON tuiConfig);

  envVars = {
    OPENCODE_DISABLE_LSP_DOWNLOAD = "true";
    OPENCODE_TUI_CONFIG = tuiConfigFile;
  }
  // extraEnv
  // {
    OPENCODE_CONFIG_CONTENT = builtins.toJSON runtimeConfig;
  };

  computerUseEnabled =
    lib.attrByPath [ "enable" ] true mcp && lib.attrByPath [ "computerUse" "enable" ] false mcp;

  virtualDisplayEnabled = lib.attrByPath [ "computerUse" "virtualDisplay" "enable" ] false mcp;

  managedVirtualDisplayEnabled = lib.attrByPath [
    "computerUse"
    "virtualDisplay"
    "fullDesktop"
  ] false mcp;

  startupNotice = lib.concatStringsSep "\n" (
    [
      "computer-use-mcp is enabled. Install the Rango browser extension: ${rangoExtensionUrl}"
    ]
    ++ lib.optionals pkgs.stdenv.isLinux [
      (
        if managedVirtualDisplayEnabled then
          "On Linux, computer-use-mcp will use the configured managed virtual X11 desktop."
        else if virtualDisplayEnabled then
          "On Linux, computer-use-mcp will use the configured X11 DISPLAY."
        else
          "On Linux, computer-use-mcp requires an interactive X11 session or services.aiagent.opencode.mcp.computerUse.virtualDisplay."
      )
    ]
  );
in
pkgs.writeShellApplication {
  name = wrapperName;
  excludeShellChecks = [ "SC2016" ];
  runtimeInputs = [ baseOpencodePackage ];
  text = ''
    ${mkEnvExports envVars}

    ${lib.optionalString computerUseEnabled ''
      printf '%s\n' ${lib.escapeShellArg startupNotice} >&2
    ''}

    if [ -n "''${OPENCODE_SERVE_URL:-}" ]; then
      exec ${lib.getExe baseOpencodePackage} attach "$OPENCODE_SERVE_URL" --dir "$PWD" "$@"
    fi

    exec ${lib.getExe baseOpencodePackage} "$@"
  '';
  passthru = {
    isWrappedOpencode = true;
    unwrappedOpencode = baseOpencodePackage;
  };
}
