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

  mkBundledSkillConfig =
    {
      bundledSkillsPackage ? null,
    }:
    lib.optionalAttrs (bundledSkillsPackage != null) {
      skills.paths = [ "${bundledSkillsPackage}/share/opencode/skills" ];
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
      bundledSkillsPackage ? null,
      extraConfig ? { },
    }:
    lib.recursiveUpdate
      (lib.recursiveUpdate
        (lib.recursiveUpdate
          baseRuntimeConfig
          (mkBundledSkillConfig {
            inherit bundledSkillsPackage;
          }))
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
      bundledSkillsPackage ? null,
      serverPasswordFile ? null,
      serverUsername ? null,
      extraConfig ? { },
      extraEnv ? { },
      wrapperName ? "opencode",
    }:
    assert !enableComputerUse || computerUsePackage != null;
    let
      runtimeConfig = mkRuntimeConfig {
        inherit enableComputerUse computerUsePackage bundledSkillsPackage extraConfig;
      };

      configuredServerHostname = lib.attrByPath [ "server" "hostname" ] "" runtimeConfig;
      configuredServerMdns = lib.attrByPath [ "server" "mdns" ] false runtimeConfig;

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
        configured_hostname=${lib.escapeShellArg configuredServerHostname}
        configured_mdns=${if configuredServerMdns then "1" else "0"}

        ${envExports}

        ${lib.optionalString (serverUsername != null) ''
          export OPENCODE_SERVER_USERNAME=${lib.escapeShellArg serverUsername}
        ''}

        ${lib.optionalString (serverPasswordFile != null) ''
          if [ ! -r ${lib.escapeShellArg (toString serverPasswordFile)} ]; then
            printf '%s\n' ${lib.escapeShellArg "Configured OPENCODE_SERVER_PASSWORD file is not readable: ${toString serverPasswordFile}"} >&2
            exit 1
          fi
          export OPENCODE_SERVER_PASSWORD="$(cat ${lib.escapeShellArg (toString serverPasswordFile)})"
        ''}

        requested_hostname="$configured_hostname"
        requested_mdns="$configured_mdns"

        for arg in "$@"; do
          case "$arg" in
            --hostname=*)
              requested_hostname="''${arg#--hostname=}"
              ;;
            --mdns)
              requested_mdns=1
              ;;
          esac
        done

        args=("$@")
        for ((i = 0; i < ''${#args[@]}; i++)); do
          case "''${args[$i]}" in
            --hostname)
              if (( i + 1 < ''${#args[@]} )); then
                requested_hostname="''${args[$((i + 1))]}"
              fi
              ;;
          esac
        done

        if [ "$requested_mdns" = "1" ] && [ -z "$requested_hostname" ]; then
          requested_hostname="0.0.0.0"
        fi

        if [ "$requested_hostname" = "0.0.0.0" ] && [ -z "''${OPENCODE_SERVER_PASSWORD:-}" ]; then
          printf '%s\n' 'Refusing to bind opencode to 0.0.0.0 without a password. Set OPENCODE_SERVER_PASSWORD, or use the services.opencode.serverPasswordFile option.' >&2
          exit 1
        fi

        ${lib.optionalString enableComputerUse ''
          printf '%s\n' ${lib.escapeShellArg startupNotice} >&2
        ''}
        exec ${lib.getExe opencodePackage} "$@"
      '';
    };
}
