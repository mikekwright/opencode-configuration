{ lib }:
let
  rangoExtensionUrl = "https://chromewebstore.google.com/detail/rango/lnemjdnjjofijemhdogofbpcedhgcpmb";

  baseRuntimeConfig = {
    mcp = {
      context7 = {
        type = "remote";
        url = "https://mcp.context7.com/mcp";
        enabled = true;
      };
    };
  };

  mkComputerUseConfig =
    {
      enableComputerUse ? false,
      computerUsePackage ? null,
    }:
    lib.optionalAttrs enableComputerUse {
      mcp = {
        computer-use = {
          type = "local";
          command = [ "${lib.getExe computerUsePackage}" ];
          enabled = true;
        };
      };
    };

  mkRuntimeConfig =
    {
      enableComputerUse ? false,
      computerUsePackage ? null,
      extraConfig ? { },
    }:
    lib.recursiveUpdate
      (lib.recursiveUpdate
        baseRuntimeConfig
        (mkComputerUseConfig {
          inherit enableComputerUse computerUsePackage;
        }))
      extraConfig;
in
{
  inherit rangoExtensionUrl;

  inherit mkRuntimeConfig;

  mkOpencodePackage =
    {
      pkgs,
      opencodePackage ? pkgs.opencode,
      enableComputerUse ? false,
      computerUsePackage ? null,
      extraConfig ? { },
      extraEnv ? { },
      wrapperName ? "opencode",
    }:
    assert !enableComputerUse || computerUsePackage != null;
    let
      runtimeConfig = mkRuntimeConfig {
        inherit enableComputerUse computerUsePackage extraConfig;
      };

      envVars = extraEnv // {
        OPENCODE_CONFIG_CONTENT = builtins.toJSON runtimeConfig;
      };

      envExports = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (
          name: value: "export ${name}=${lib.escapeShellArg (toString value)}"
        ) envVars
      );

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
      runtimeInputs = [ opencodePackage ] ++ lib.optionals enableComputerUse [ computerUsePackage ];
      text = ''
        ${envExports}
        ${lib.optionalString enableComputerUse ''
          printf '%s\n' ${lib.escapeShellArg startupNotice} >&2
        ''}
        exec ${lib.getExe opencodePackage} "$@"
      '';
    };
}
