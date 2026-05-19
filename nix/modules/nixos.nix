{ self }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  helpers = import ../lib.nix { inherit lib; };
  mkOpencodePackage = import ../opencode.nix { inherit lib; };
  linuxSystem = import ./system/linux.nix { inherit lib helpers pkgs; };
  cfg = config.services.opencode;

  defaultPackage = self.packages.${pkgs.stdenv.hostPlatform.system}.opencode;

  baseOpencodePackage =
    if lib.attrByPath [ "passthru" "isWrappedOpencode" ] false cfg.package then
      lib.attrByPath [ "passthru" "unwrappedOpencode" ] cfg.package cfg.package
    else
      cfg.package;

  packageExtraEnv = builtins.removeAttrs cfg.extraEnv (
    lib.optional (cfg.serverPasswordFile != null) "OPENCODE_SERVER_PASSWORD"
    ++ lib.optional (cfg.serverUsername != null) "OPENCODE_SERVER_USERNAME"
  );

  managedPackage = mkOpencodePackage {
    inherit pkgs;
    opencodePackage = baseOpencodePackage;
    mcp = {
      enable = cfg.mcp.enable;
      computerUse = {
        enable = cfg.mcp.computerUse.enable;
        package = cfg.mcp.computerUse.package;
      };
    };
    skills = {
      enable = cfg.skills.enable;
      package = cfg.skills.package;
    };
    extraConfig = cfg.extraConfig;
    extraEnv = packageExtraEnv;
    wrapperName = "opencode";
  };
in
{
  options.services.opencode = {
    enable = lib.mkEnableOption "the opencode headless service";

    package = lib.mkOption {
      type = lib.types.package;
      default = defaultPackage;
      description = "Opencode package to use. Wrapped opencode packages from this flake are unwrapped and rebuilt with the module configuration.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "opencode";
      description = "User account for the service.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "opencode";
      description = "Group for the service.";
    };

    workingDirectory = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/opencode";
      description = "Working directory used by the service.";
    };

    hostname = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Hostname for `opencode serve`.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 4096;
      description = "Port for `opencode serve`.";
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra arguments passed to `opencode serve`.";
    };

    extraConfig = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Additional JSON config merged into OPENCODE_CONFIG_CONTENT.";
    };

    extraEnv = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Extra environment variables exported by the wrapper. This can include `OPENCODE_SERVER_PASSWORD`, though `serverPasswordFile` is preferred for secrets.";
    };

    serverPasswordFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "File containing the password for `OPENCODE_SERVER_PASSWORD`. Use this or `extraEnv.OPENCODE_SERVER_PASSWORD`. If both are set, the file value wins.";
    };

    serverUsername = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional username for HTTP basic auth. Defaults to opencode when unset.";
    };

    mcp = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable configured MCP integrations.";
      };

      computerUse = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable the packaged computer-use-mcp server.";
        };

        package = lib.mkOption {
          type = lib.types.package;
          default = self.packages.${pkgs.stdenv.hostPlatform.system}.computer-use-mcp;
          description = "computer-use-mcp package to expose to opencode.";
        };
      };
    };

    skills = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable bundled opencode skills.";
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = self.packages.${pkgs.stdenv.hostPlatform.system}.opencode-skills;
        description = "Bundled opencode skills package to expose to opencode.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.user != "root";
        message = "services.opencode must not run as root.";
      }
      (helpers.mkPasswordAssertion {
        hostname = cfg.hostname;
        serverPasswordFile = cfg.serverPasswordFile;
        extraEnv = cfg.extraEnv;
        message = "services.opencode.hostname = \"0.0.0.0\" requires a password. Set services.opencode.serverPasswordFile or extraEnv.OPENCODE_SERVER_PASSWORD.";
      })
      (helpers.mkReservedServeArgsAssertion {
        extraArgs = cfg.extraArgs;
        message = "services.opencode.extraArgs must not override hostname, port, or mdns. Use services.opencode.hostname and services.opencode.port instead.";
      })
    ];

    warnings = lib.optional (cfg.mcp.enable && cfg.mcp.computerUse.enable) ''
      computer-use-mcp is desktop-oriented. On Linux it requires an interactive X11 session and the Rango browser extension:
      ${helpers.rangoExtensionUrl}
    '';

    environment.systemPackages = [ managedPackage ];

    users.groups = lib.optionalAttrs (cfg.group == "opencode") {
      ${cfg.group} = { };
    };

    users.users = lib.optionalAttrs (cfg.user == "opencode") {
      ${cfg.user} = {
        isSystemUser = true;
        group = cfg.group;
        home = cfg.workingDirectory;
        createHome = true;
      };
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.workingDirectory} 0750 ${cfg.user} ${cfg.group} -"
    ];

    systemd.services = (linuxSystem.mkNixosService {
      package = managedPackage;
      hostname = cfg.hostname;
      port = cfg.port;
      extraArgs = cfg.extraArgs;
      workingDirectory = cfg.workingDirectory;
      user = cfg.user;
      group = cfg.group;
      serverUsername = cfg.serverUsername;
      serverPasswordFile = cfg.serverPasswordFile;
    }).systemd.services;
  };
}
