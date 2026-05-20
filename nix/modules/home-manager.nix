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
  darwinSystem = import ./system/darwin.nix { inherit helpers pkgs; };
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
      openPencil = {
        enable = cfg.mcp.openPencil.enable;
        url = cfg.mcp.openPencil.url;
      };
    };
    skills = {
      enable = cfg.skills.enable;
      package = cfg.skills.package;
      openPencil = {
        enable = cfg.skills.openPencil.enable;
        package = cfg.skills.openPencil.package;
      };
    };
    extraConfig = cfg.extraConfig;
    extraEnv = packageExtraEnv;
    wrapperName = "opencode";
  };
in
{
  imports = [
    (lib.mkRenamedOptionModule [ "services" "opencode" "service" ] [ "services" "opencode" "web" ])
  ];

  options.services.opencode = {
    enable = lib.mkEnableOption "opencode";

    package = lib.mkOption {
      type = lib.types.package;
      default = defaultPackage;
      description = "Opencode package to use. Wrapped opencode packages from this flake are unwrapped and rebuilt with the module configuration.";
    };

    extraConfig = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Additional JSON config added to the wrapper's OPENCODE_CONFIG_CONTENT layer after OpenCode loads its standard config locations.";
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
          default = pkgs.stdenv.isDarwin;
          description = "Enable the packaged computer-use-mcp server.";
        };

        package = lib.mkOption {
          type = lib.types.package;
          default = self.packages.${pkgs.stdenv.hostPlatform.system}.computer-use-mcp;
          description = "computer-use-mcp package to expose to opencode.";
        };
      };

      openPencil = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable the ZSeven-W OpenPencil MCP connection.";
        };

        url = lib.mkOption {
          type = lib.types.str;
          default = "http://127.0.0.1:3100/mcp";
          description = "URL for the ZSeven-W OpenPencil MCP server exposed by a running desktop or web instance.";
        };

        package = lib.mkOption {
          type = lib.types.nullOr lib.types.package;
          default = null;
          description = "Deprecated and ignored. ZSeven-W/openpencil exposes MCP over HTTP; use services.opencode.mcp.openPencil.url instead.";
        };

        root = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Deprecated and ignored. ZSeven-W/openpencil does not use OPENPENCIL_MCP_ROOT.";
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

      openPencil = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable the ZSeven-W OpenPencil skill package.";
        };

        package = lib.mkOption {
          type = lib.types.package;
          default = self.packages.${pkgs.stdenv.hostPlatform.system}.open-pencil-skill;
          description = "OpenPencil skill package to expose to opencode.";
        };
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
          (helpers.mkPasswordAssertion {
            hostname = if cfg.web.enable then cfg.web.hostname else "127.0.0.1";
            serverPasswordFile = cfg.serverPasswordFile;
            extraEnv = cfg.extraEnv;
            message = "services.opencode.web.hostname = \"0.0.0.0\" requires a password. Set services.opencode.serverPasswordFile or extraEnv.OPENCODE_SERVER_PASSWORD.";
          })
          (helpers.mkReservedServeArgsAssertion {
            extraArgs = cfg.web.extraArgs;
            message = "services.opencode.web.extraArgs must not override hostname, port, or mdns. Use services.opencode.web.hostname and services.opencode.web.port instead.";
          })
        ];

        home.packages = [ managedPackage ];

        warnings =
          lib.optional (cfg.mcp.enable && cfg.mcp.computerUse.enable && pkgs.stdenv.isLinux) ''
            services.opencode on Linux requires an interactive X11 session for computer-use-mcp and the Rango browser extension:
            ${helpers.rangoExtensionUrl}
          ''
          ++ lib.optional (cfg.mcp.enable && cfg.mcp.openPencil.package != null) ''
            services.opencode.mcp.openPencil.package is ignored. ZSeven-W/openpencil exposes MCP over HTTP from a running instance; use services.opencode.mcp.openPencil.url instead.
          ''
          ++ lib.optional (cfg.mcp.enable && cfg.mcp.openPencil.root != null) ''
            services.opencode.mcp.openPencil.root is ignored. ZSeven-W/openpencil does not use OPENPENCIL_MCP_ROOT.
          '';
      }

      (lib.mkIf (cfg.web.enable && pkgs.stdenv.isDarwin) (
        darwinSystem.mkHomeManagerService {
          package = managedPackage;
          hostname = cfg.web.hostname;
          port = cfg.web.port;
          extraArgs = cfg.web.extraArgs;
          workingDirectory = cfg.web.workingDirectory;
          autoStart = cfg.web.autoStart;
          serverUsername = cfg.serverUsername;
          serverPasswordFile = cfg.serverPasswordFile;
        }
      ))

      (lib.mkIf (cfg.web.enable && pkgs.stdenv.isLinux) (
        linuxSystem.mkHomeManagerService {
          package = managedPackage;
          hostname = cfg.web.hostname;
          port = cfg.web.port;
          extraArgs = cfg.web.extraArgs;
          workingDirectory = cfg.web.workingDirectory;
          autoStart = cfg.web.autoStart;
          serverUsername = cfg.serverUsername;
          serverPasswordFile = cfg.serverPasswordFile;
        }
      ))
    ]
  );
}
