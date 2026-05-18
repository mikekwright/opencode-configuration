{ self }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  helpers = import ../lib.nix { inherit lib; };
  cfg = config.services.opencode;

  interactivePackage = helpers.mkOpencodePackage {
    inherit pkgs;
    opencodePackage = cfg.package;
    enableComputerUse = cfg.mcp.computerUse.enable;
    computerUsePackage = cfg.mcp.computerUse.package;
    bundledSkillsPackage = self.packages.${pkgs.stdenv.hostPlatform.system}.opencode-skills;
    serverPasswordFile = cfg.serverPasswordFile;
    serverUsername = cfg.serverUsername;
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
    serverPasswordFile = cfg.serverPasswordFile;
    serverUsername = cfg.serverUsername;
    extraConfig = lib.recursiveUpdate cfg.extraConfig {
      server = {
        hostname = cfg.web.hostname;
        port = cfg.web.port;
      };
    };
    extraEnv = cfg.extraEnv;
    wrapperName = "opencode-service";
  };

  linuxServiceCommand = lib.escapeShellArgs (
    [
      "${lib.getExe servicePackage}"
      "serve"
    ]
    ++ cfg.web.extraArgs
  );
in
{
  imports = [
    (lib.mkRenamedOptionModule [ "services" "opencode" "service" ] [ "services" "opencode" "web" ])
  ];

  options.services.opencode = {
    enable = lib.mkEnableOption "opencode";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.opencode;
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

    web = {
      enable = lib.mkEnableOption "the opencode background web service";

      autoStart = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Start the web service automatically.";
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
        assertions = [
          {
            assertion =
              !(cfg.web.enable && cfg.web.hostname == "0.0.0.0")
              || cfg.serverPasswordFile != null
              || cfg.extraEnv ? OPENCODE_SERVER_PASSWORD;
            message = "services.opencode.web.hostname = \"0.0.0.0\" requires a password. Set services.opencode.serverPasswordFile or extraEnv.OPENCODE_SERVER_PASSWORD.";
          }
        ];

        home.packages = [ interactivePackage ];

        warnings = lib.optional (cfg.mcp.computerUse.enable && pkgs.stdenv.isLinux) ''
          services.opencode on Linux requires an interactive X11 session for computer-use-mcp and the Rango browser extension:
          ${helpers.rangoExtensionUrl}
        '';
      }

      (lib.mkIf (cfg.web.enable && pkgs.stdenv.isDarwin) {
        launchd.agents.opencode = {
          enable = true;
          config = {
            Label = "ai.opencode";
            ProgramArguments = [
              "${lib.getExe servicePackage}"
              "serve"
            ]
            ++ cfg.web.extraArgs;
            RunAtLoad = cfg.web.autoStart;
            KeepAlive = cfg.web.autoStart;
            WorkingDirectory = cfg.web.workingDirectory;
          };
        };
      })

      (lib.mkIf (cfg.web.enable && pkgs.stdenv.isLinux) {
        systemd.user.services.opencode = {
          Unit = {
            Description = "OpenCode user service";
            After = [ "network.target" ];
          };

          Service = {
            ExecStart = linuxServiceCommand;
            WorkingDirectory = cfg.web.workingDirectory;
            Restart = "on-failure";
          };

          Install = lib.mkIf cfg.web.autoStart {
            WantedBy = [ "default.target" ];
          };
        };
      })
    ]
  );
}
