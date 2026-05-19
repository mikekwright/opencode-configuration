{ lib }:
let
  buildMcpConfig = import ./config/mcp.nix { inherit lib; };
  buildSkillsConfig = import ./config/skills.nix { inherit lib; };
  rangoExtensionUrl = "https://chromewebstore.google.com/detail/rango/lnemjdnjjofijemhdogofbpcedhgcpmb";
  mkEnvExports = envVars:
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
  baseOpencodePackage =
    lib.attrByPath [ "passthru" "unwrappedOpencode" ] opencodePackage opencodePackage;

  runtimeConfig =
    lib.recursiveUpdate
      (lib.recursiveUpdate (buildMcpConfig ({ enable = true; } // mcp)) (buildSkillsConfig ({ enable = true; } // skills)))
      extraConfig;

  envVars = extraEnv // {
    OPENCODE_CONFIG_CONTENT = builtins.toJSON runtimeConfig;
  };

  computerUseEnabled =
    lib.attrByPath [ "enable" ] true mcp
    && lib.attrByPath [ "computerUse" "enable" ] false mcp;

  startupNotice = lib.concatStringsSep "\n" (
    [
      "computer-use-mcp is enabled. Install the Rango browser extension: ${rangoExtensionUrl}"
    ]
    ++ lib.optionals pkgs.stdenv.isLinux [
      "On Linux, computer-use-mcp requires an interactive X11 session."
    ]
  );
in
pkgs.writeShellApplication {
  name = wrapperName;
  runtimeInputs = [ baseOpencodePackage ];
  text = ''
    ${mkEnvExports envVars}

    ${lib.optionalString computerUseEnabled ''
      printf '%s\n' ${lib.escapeShellArg startupNotice} >&2
    ''}

    exec ${lib.getExe baseOpencodePackage} "$@"
  '';
  passthru = {
    isWrappedOpencode = true;
    unwrappedOpencode = baseOpencodePackage;
  };
}
