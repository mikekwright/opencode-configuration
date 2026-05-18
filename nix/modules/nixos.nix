{ self }:
{ config, lib, pkgs, ... }:
let
  helpers = import ../lib.nix { inherit lib; };
  cfg = config.services.opencode;

  interactivePackage = helpers.mkOpencodePackage {
    inherit pkgs;
    opencodePackage = cfg.package;
    enableComputerUse = cfg.mcp.computerUse.enable;
    computerUsePackage = cfg.mcp.computerUse.package;
    bundledSkillsPackage = self.packages.${pkgs.stdenv.hostPlatform.system}.opencode-skills;
    extraConfig = cfg.extraConfig;
    extraEnv = cfg.extraEnv;
    wrapperName = "opencode";
  };

  servicePackage = helpers.mkOpencodePackage {
    inherit pkgs;
    opencodePackage = cfg.package;
    enableComputerUse = cfg.mcp.computerUse.enable;
    computerUsePackage = cfg.mcp.computerUse.package;
    bundledSkillsPackage = self.packages.${pkgs.stdenv.hostPlatform.system}.opencode-skills;
    extraConfig = lib.recursiveUpdate cfg.extraConfig {
      server = {
        hostname = cfg.hostname;
        port = cfg.port;
      };
    };
    extraEnv = cfg.extraEnv;
    wrapperName = "opencode-service";
  };

  serviceCommand = lib.escapeShellArgs ([ "${lib.getExe servicePackage}" "serve" ] ++ cfg.extraArgs);
in
{
  options.services.opencode = {
    enable = lib.mkEnableOption "the opencode headless service";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.opencode;
      description = "Base opencode package to wrap.";
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
      description = "Extra environment variables exported by the wrapper.";
    };

    mcp.computerUse = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable computer-use-mcp for the service wrapper.";
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = self.packages.${pkgs.stdenv.hostPlatform.system}.computer-use-mcp;
        description = "computer-use-mcp package to expose to opencode.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.user != "root";
        message = "services.opencode must not run as root.";
      }
    ];

    warnings = lib.optional cfg.mcp.computerUse.enable ''
      computer-use-mcp is desktop-oriented. On Linux it requires an interactive X11 session and the Rango browser extension:
      ${helpers.rangoExtensionUrl}
    '';

    environment.systemPackages = [ interactivePackage ];

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

    systemd.services.opencode = {
      description = "OpenCode headless service";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.workingDirectory;
        ExecStart = serviceCommand;
        Restart = "on-failure";
      };
    };
  };
}
