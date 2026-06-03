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
  computerUseVirtualDisplay = cfg.mcp.computerUse.virtualDisplay;
  effectiveComputerUseDisplay = helpers.getVirtualDisplay computerUseVirtualDisplay;

  defaultPackage = self.packages.${pkgs.stdenv.hostPlatform.system}.opencode;
  codeServerSupported = lib.meta.availableOn pkgs.stdenv.hostPlatform pkgs.openvscode-server;
  defaultCodeServerPackage = if codeServerSupported then pkgs.openvscode-server else null;
  defaultBrowserPackage =
    if pkgs.stdenv.isLinux then
      self.packages.${pkgs.stdenv.hostPlatform.system}.chromium-with-rango
    else
      pkgs.writeShellApplication {
        name = "chromium-with-rango-unavailable";
        text = ''
          printf '%s\n' 'chromium-with-rango is only available on Linux.' >&2
          exit 1
        '';
      };

  baseOpencodePackage =
    if lib.attrByPath [ "passthru" "isWrappedOpencode" ] false cfg.package then
      lib.attrByPath [ "passthru" "unwrappedOpencode" ] cfg.package cfg.package
    else
      cfg.package;

  packageExtraEnv = builtins.removeAttrs cfg.extraEnv (
    lib.optional (cfg.serverPasswordFile != null) "OPENCODE_SERVER_PASSWORD"
    ++ lib.optional (cfg.serverUsername != null) "OPENCODE_SERVER_USERNAME"
  );

  codeServerPassword =
    if cfg.serverPasswordFile != null then null else cfg.extraEnv.OPENCODE_SERVER_PASSWORD or null;

  codeServerProgramName =
    if cfg.codeServer.package == null then
      null
    else
      builtins.baseNameOf (lib.getExe cfg.codeServer.package);

  managedPackage = mkOpencodePackage {
    inherit pkgs;
    opencodePackage = baseOpencodePackage;
    mcp = {
      enable = cfg.mcp.enable;
      computerUse = {
        enable = cfg.mcp.computerUse.enable;
        package = cfg.mcp.computerUse.package;
        virtualDisplay = {
          enable = computerUseVirtualDisplay.enable;
          fullDesktop = computerUseVirtualDisplay.fullDesktop;
          display = effectiveComputerUseDisplay;
        };
      };
      openPencil = {
        enable = cfg.mcp.openPencil.enable;
        url = cfg.mcp.openPencil.url;
      };
      banani = {
        enable = cfg.mcp.banani.enable;
        url = cfg.mcp.banani.url;
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
          default = true;
          description = "Enable the packaged computer-use-mcp server.";
        };

        package = lib.mkOption {
          type = lib.types.package;
          default = self.packages.${pkgs.stdenv.hostPlatform.system}.computer-use-mcp;
          description = "computer-use-mcp package to expose to opencode.";
        };

        virtualDisplay = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable Linux virtual display support for computer-use-mcp.";
          };

          fullDesktop = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Manage a lightweight Linux virtual X11 desktop for computer-use-mcp.";
          };

          display = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "DISPLAY value to export to computer-use-mcp. Defaults to :99 when fullDesktop is enabled and display is unset.";
          };

          browser = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Launch the configured Chromium-with-Rango browser inside the managed virtual desktop.";
            };

            package = lib.mkOption {
              type = lib.types.package;
              default = defaultBrowserPackage;
              description = "Browser package to launch for the managed virtual desktop flow.";
            };
          };
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

      banani = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable the Banani MCP connection.";
        };

        url = lib.mkOption {
          type = lib.types.str;
          default = "https://app.banani.co/api/mcp/mcp";
          description = "URL for the Banani MCP server.";
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

    codeServer = {
      enable = lib.mkEnableOption "the code-server background service";

      package = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        default = defaultCodeServerPackage;
        description = "VS Code server package to run. Defaults to nixpkgs `openvscode-server` when it is available on this platform.";
      };

      autoStart = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Start the code-server service automatically.";
      };

      hostname = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "Hostname for `code-server --bind-addr`.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 9998;
        description = "Port for `code-server --bind-addr`.";
      };

      workingDirectory = lib.mkOption {
        type = lib.types.str;
        default = cfg.web.workingDirectory;
        description = "Working directory opened by code-server and used by the service.";
      };

      extraArgs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Extra arguments passed to `code-server`.";
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
          {
            assertion = !cfg.codeServer.enable || cfg.codeServer.package != null;
            message = "services.opencode.codeServer.enable requires a VS Code server package on this platform. Set services.opencode.codeServer.package explicitly if nixpkgs does not provide one.";
          }
          {
            assertion =
              !cfg.codeServer.enable
              || cfg.codeServer.package == null
              || lib.elem codeServerProgramName [
                "code-server"
                "openvscode-server"
              ];
            message = "services.opencode.codeServer.package must provide either the `code-server` or `openvscode-server` executable.";
          }
          {
            assertion =
              !cfg.codeServer.enable || cfg.serverPasswordFile != null || cfg.extraEnv ? OPENCODE_SERVER_PASSWORD;
            message = "services.opencode.codeServer.enable requires services.opencode.serverPasswordFile or extraEnv.OPENCODE_SERVER_PASSWORD so the VS Code service can reuse the opencode password source.";
          }
          (helpers.mkReservedCodeServerArgsAssertion {
            extraArgs = cfg.codeServer.extraArgs;
            message = "services.opencode.codeServer.extraArgs must not override the service host, port, or auth/token flags. Use services.opencode.codeServer.hostname and services.opencode.codeServer.port instead.";
          })
          {
            assertion = !computerUseVirtualDisplay.enable || effectiveComputerUseDisplay != null;
            message = "services.opencode.mcp.computerUse.virtualDisplay.enable requires virtualDisplay.fullDesktop = true or virtualDisplay.display to be set.";
          }
          {
            assertion =
              !computerUseVirtualDisplay.browser.enable
              || (computerUseVirtualDisplay.enable && computerUseVirtualDisplay.fullDesktop);
            message = "services.opencode.mcp.computerUse.virtualDisplay.browser.enable requires virtualDisplay.enable = true and virtualDisplay.fullDesktop = true.";
          }
          {
            assertion = !computerUseVirtualDisplay.enable || pkgs.stdenv.isLinux;
            message = "services.opencode.mcp.computerUse.virtualDisplay is only supported on Linux.";
          }
          {
            assertion = !(cfg.mcp.enable && cfg.mcp.banani.enable) || cfg.extraEnv ? BANANI_API_KEY;
            message = "services.opencode.mcp.banani.enable requires extraEnv.BANANI_API_KEY.";
          }
        ];

        home.packages = [
          managedPackage
        ]
        ++ lib.optional (cfg.codeServer.enable && cfg.codeServer.package != null) cfg.codeServer.package;

        warnings =
          lib.optional (cfg.mcp.enable && cfg.mcp.computerUse.enable && pkgs.stdenv.isLinux) ''
            services.opencode on Linux needs X11 for computer-use-mcp. Set services.opencode.mcp.computerUse.virtualDisplay.display for an existing X11 session or enable services.opencode.mcp.computerUse.virtualDisplay.fullDesktop for a managed Xvfb/openbox desktop. Rango browser extension:
            ${helpers.rangoExtensionUrl}
          ''
          ++ lib.optional (cfg.mcp.enable && cfg.mcp.openPencil.package != null) ''
            services.opencode.mcp.openPencil.package is ignored. ZSeven-W/openpencil exposes MCP over HTTP from a running instance; use services.opencode.mcp.openPencil.url instead.
          ''
          ++ lib.optional (cfg.mcp.enable && cfg.mcp.openPencil.root != null) ''
            services.opencode.mcp.openPencil.root is ignored. ZSeven-W/openpencil does not use OPENPENCIL_MCP_ROOT.
          ''
          ++ lib.optional (cfg.codeServer.enable && cfg.serverUsername != null) ''
            services.opencode.serverUsername is ignored by services.opencode.codeServer. Neither openvscode-server nor code-server shares opencode's username setting.
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
          virtualDisplay = {
            enable = computerUseVirtualDisplay.enable;
            fullDesktop = computerUseVirtualDisplay.fullDesktop;
            display = effectiveComputerUseDisplay;
            browser = {
              enable = computerUseVirtualDisplay.browser.enable;
              package = computerUseVirtualDisplay.browser.package;
            };
          };
        }
      ))

      (lib.mkIf (cfg.codeServer.enable && cfg.codeServer.package != null && pkgs.stdenv.isDarwin) (
        darwinSystem.mkCodeServerHomeManagerService {
          package = cfg.codeServer.package;
          hostname = cfg.codeServer.hostname;
          port = cfg.codeServer.port;
          extraArgs = cfg.codeServer.extraArgs;
          workingDirectory = cfg.codeServer.workingDirectory;
          autoStart = cfg.codeServer.autoStart;
          serverPasswordFile = cfg.serverPasswordFile;
          password = codeServerPassword;
        }
      ))

      (lib.mkIf (cfg.codeServer.enable && cfg.codeServer.package != null && pkgs.stdenv.isLinux) (
        linuxSystem.mkCodeServerHomeManagerService {
          package = cfg.codeServer.package;
          hostname = cfg.codeServer.hostname;
          port = cfg.codeServer.port;
          extraArgs = cfg.codeServer.extraArgs;
          workingDirectory = cfg.codeServer.workingDirectory;
          autoStart = cfg.codeServer.autoStart;
          serverPasswordFile = cfg.serverPasswordFile;
          password = codeServerPassword;
        }
      ))
    ]
  );
}
