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
        hostname = cfg.service.hostname;
        port = cfg.service.port;
      };
    };
    extraEnv = cfg.extraEnv;
    wrapperName = "opencode-service";
  };

  linuxServiceCommand = lib.escapeShellArgs ([ "${lib.getExe servicePackage}" "serve" ] ++ cfg.service.extraArgs);
in
{
  options.services.opencode = {
    enable = lib.mkEnableOption "opencode";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.opencode;
      description = "Base opencode package to wrap.";
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
        default = pkgs.stdenv.isDarwin;
        description = "Enable the packaged computer-use-mcp server.";
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = self.packages.${pkgs.stdenv.hostPlatform.system}.computer-use-mcp;
        description = "computer-use-mcp package to expose to opencode.";
      };
    };

    service = {
      enable = lib.mkEnableOption "the opencode background user service";

      autoStart = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Start the user service automatically.";
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

      workingDirectory = lib.mkOption {
        type = lib.types.str;
        default = config.home.homeDirectory;
        description = "Working directory used by the service.";
      };

      extraArgs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Extra arguments passed to `opencode serve`.";
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        home.packages = [ interactivePackage ];

        warnings = lib.optional (cfg.mcp.computerUse.enable && pkgs.stdenv.isLinux) ''
          services.opencode on Linux requires an interactive X11 session for computer-use-mcp and the Rango browser extension:
          ${helpers.rangoExtensionUrl}
        '';
      }

      (lib.mkIf (cfg.service.enable && pkgs.stdenv.isDarwin) {
        launchd.agents.opencode = {
          enable = true;
          config = {
            Label = "ai.opencode";
            ProgramArguments = [ "${lib.getExe servicePackage}" "serve" ] ++ cfg.service.extraArgs;
            RunAtLoad = cfg.service.autoStart;
            KeepAlive = cfg.service.autoStart;
            WorkingDirectory = cfg.service.workingDirectory;
          };
        };
      })

      (lib.mkIf (cfg.service.enable && pkgs.stdenv.isLinux) {
        systemd.user.services.opencode = {
          Unit = {
            Description = "OpenCode user service";
            After = [ "network.target" ];
          };

          Service = {
            ExecStart = linuxServiceCommand;
            WorkingDirectory = cfg.service.workingDirectory;
            Restart = "on-failure";
          };

          Install = lib.mkIf cfg.service.autoStart {
            WantedBy = [ "default.target" ];
          };
        };
      })
    ]
  );
}
