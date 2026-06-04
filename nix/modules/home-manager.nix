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
  darwinSystem = import ./system/darwin.nix { };
  linuxSystem = import ./system/linux.nix { inherit lib; };

  cfg = config.services.aiagent;
  opencodeCfg = cfg.opencode;
  openvscodeCfg = cfg.openvscode;
  nginxCfg = cfg.nginx;

  computerUseVirtualDisplay = opencodeCfg.mcp.computerUse.virtualDisplay;
  effectiveComputerUseDisplay = helpers.getVirtualDisplay computerUseVirtualDisplay;

  defaultPackage = self.packages.${pkgs.stdenv.hostPlatform.system}.opencode;
  defaultOpenVSCodePackage = self.packages.${pkgs.stdenv.hostPlatform.system}.openvscode-server;
  defaultNginxPackage = self.packages.${pkgs.stdenv.hostPlatform.system}.nginx;
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
    if lib.attrByPath [ "passthru" "isWrappedOpencode" ] false opencodeCfg.package then
      lib.attrByPath [ "passthru" "unwrappedOpencode" ] opencodeCfg.package opencodeCfg.package
    else
      opencodeCfg.package;

  packageExtraEnv = builtins.removeAttrs opencodeCfg.extraEnv (
    lib.optional (opencodeCfg.serverPasswordFile != null) "OPENCODE_SERVER_PASSWORD"
    ++ lib.optional (opencodeCfg.serverUsername != null) "OPENCODE_SERVER_USERNAME"
  );

  hasOpencodePassword = helpers.hasPasswordSource opencodeCfg.serverPasswordFile opencodeCfg.extraEnv;
  hasOpenVSCodeToken =
    openvscodeCfg.connectionTokenFile != null || openvscodeCfg.connectionToken != null;
  openvscodeProgramName = builtins.baseNameOf (lib.getExe openvscodeCfg.package);

  enabledPorts =
    lib.optionals opencodeCfg.enable [ opencodeCfg.port ]
    ++ lib.optionals openvscodeCfg.enable [ openvscodeCfg.port ]
    ++ lib.optionals nginxCfg.enable [ nginxCfg.port ];

  enabledDomains =
    lib.optionals (opencodeCfg.enable && opencodeCfg.domain != null) [ opencodeCfg.domain ]
    ++ lib.optionals (openvscodeCfg.enable && openvscodeCfg.domain != null) [ openvscodeCfg.domain ];

  nginxRoutes =
    lib.optionals (opencodeCfg.enable && opencodeCfg.domain != null) [
      {
        inherit (opencodeCfg) domain;
        upstream = "http://${helpers.normalizeLocalHost opencodeCfg.hostname}:${toString opencodeCfg.port}";
      }
    ]
    ++ lib.optionals (openvscodeCfg.enable && openvscodeCfg.domain != null) [
      {
        inherit (openvscodeCfg) domain;
        upstream = "http://${helpers.normalizeLocalHost openvscodeCfg.hostname}:${toString openvscodeCfg.port}";
      }
    ];

  stateRoot = "${config.home.homeDirectory}/.local/state/aiagent";
  nginxStateDir = "${stateRoot}/nginx";
  nginxConfigFile = pkgs.writeText "aiagent-nginx.conf" (
    helpers.renderNginxConfig {
      inherit (nginxCfg) listenAddress port extraConfig;
      routes = nginxRoutes;
      stateDir = nginxStateDir;
    }
  );

  managedPackage = mkOpencodePackage {
    inherit pkgs;
    opencodePackage = baseOpencodePackage;
    mcp = {
      enable = opencodeCfg.mcp.enable;
      computerUse = {
        inherit (opencodeCfg.mcp.computerUse) enable package;
        virtualDisplay = {
          inherit (computerUseVirtualDisplay) enable fullDesktop;
          display = effectiveComputerUseDisplay;
        };
      };
      openPencil = {
        inherit (opencodeCfg.mcp.openPencil) enable url;
      };
      banani = {
        inherit (opencodeCfg.mcp.banani) enable url;
      };
    };
    skills = {
      inherit (opencodeCfg.skills) enable package;
      openPencil = {
        inherit (opencodeCfg.skills.openPencil) enable package;
      };
    };
    inherit (opencodeCfg) extraConfig;
    extraEnv = packageExtraEnv;
    wrapperName = "opencode";
  };

  opencodeLauncher = helpers.mkServiceLauncher {
    inherit pkgs;
    package = managedPackage;
    inherit (opencodeCfg) serverPasswordFile;
    virtualDisplay = {
      inherit (computerUseVirtualDisplay) enable fullDesktop;
      display = effectiveComputerUseDisplay;
      browser = {
        inherit (computerUseVirtualDisplay.browser) enable package;
      };
    };
    name = "opencode-service";
    args = helpers.mkServeArgs {
      inherit (opencodeCfg) hostname port extraArgs;
    };
    env = helpers.mkServiceEnv {
      inherit (opencodeCfg) serverUsername;
      display = effectiveComputerUseDisplay;
    };
  };

  openvscodeLauncher = helpers.mkOpenVSCodeServiceLauncher {
    inherit pkgs;
    inherit (openvscodeCfg)
      package
      hostname
      port
      workingDirectory
      extraArgs
      connectionTokenFile
      connectionToken
      ;
    name = "openvscode-server-service";
  };

  nginxLauncher = helpers.mkNginxServiceLauncher {
    inherit pkgs;
    inherit (nginxCfg) package;
    configFile = nginxConfigFile;
    stateDir = nginxStateDir;
    name = "nginx-service";
  };

  anyServiceEnabled = opencodeCfg.enable || openvscodeCfg.enable || nginxCfg.enable;
in
{
  options.services.aiagent = {
    opencode = {
      enable = lib.mkEnableOption "the opencode background service";

      package = lib.mkOption {
        type = lib.types.package;
        default = defaultPackage;
        description = "Opencode package to use. Wrapped opencode packages from this flake are unwrapped and rebuilt with the module configuration.";
      };

      autoStart = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Start the opencode service automatically.";
      };

      workingDirectory = lib.mkOption {
        type = lib.types.str;
        default = config.home.homeDirectory;
        description = "Working directory used by the opencode service.";
      };

      hostname = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "Hostname for `opencode serve`. Keep this on loopback when nginx is handling remote access.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 4096;
        description = "Port for `opencode serve`.";
      };

      domain = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Optional domain that nginx should route to the opencode backend.";
      };

      extraArgs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Extra arguments passed to `opencode serve`.";
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
            description = "Deprecated and ignored. ZSeven-W/openpencil exposes MCP over HTTP; use services.aiagent.opencode.mcp.openPencil.url instead.";
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
    };

    openvscode = {
      enable = lib.mkEnableOption "the OpenVSCode Server background service";

      package = lib.mkOption {
        type = lib.types.package;
        default = defaultOpenVSCodePackage;
        description = "OpenVSCode Server package to run.";
      };

      autoStart = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Start the OpenVSCode Server service automatically.";
      };

      hostname = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "Hostname for `openvscode-server --host`. Keep this on loopback when nginx is handling remote access.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 9998;
        description = "Port for `openvscode-server --port`.";
      };

      workingDirectory = lib.mkOption {
        type = lib.types.str;
        default = opencodeCfg.workingDirectory;
        description = "Working directory opened by OpenVSCode Server and used by the service.";
      };

      domain = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Optional domain that nginx should route to the OpenVSCode Server backend.";
      };

      extraArgs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Extra arguments passed to `openvscode-server`.";
      };

      connectionTokenFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = opencodeCfg.serverPasswordFile;
        description = "File containing the OpenVSCode Server connection token. Defaults to the opencode password file when present.";
      };

      connectionToken = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = opencodeCfg.extraEnv.OPENCODE_SERVER_PASSWORD or null;
        description = "Inline OpenVSCode Server connection token. Defaults to the opencode password when present.";
      };
    };

    nginx = {
      enable = lib.mkEnableOption "the nginx reverse proxy service";

      package = lib.mkOption {
        type = lib.types.package;
        default = defaultNginxPackage;
        description = "nginx package to run.";
      };

      autoStart = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Start the nginx service automatically.";
      };

      listenAddress = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "Address that nginx listens on. For tailnet exposure, prefer a Tailscale IP instead of `0.0.0.0` when possible.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 8123;
        description = "Port that nginx listens on.";
      };

      extraConfig = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Additional raw nginx config appended inside the generated `http {}` block.";
      };
    };
  };

  config = lib.mkIf anyServiceEnabled (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = !opencodeCfg.enable || opencodeCfg.port >= 1024;
            message = "services.aiagent.opencode.port must be >= 1024 for Home Manager user services.";
          }
          {
            assertion = !openvscodeCfg.enable || openvscodeCfg.port >= 1024;
            message = "services.aiagent.openvscode.port must be >= 1024 for Home Manager user services.";
          }
          {
            assertion = !nginxCfg.enable || nginxCfg.port >= 1024;
            message = "services.aiagent.nginx.port must be >= 1024 for Home Manager user services.";
          }
          (helpers.mkPasswordAssertion {
            inherit (opencodeCfg) hostname serverPasswordFile extraEnv;
            message = "services.aiagent.opencode.hostname = \"0.0.0.0\" requires a password. Set services.aiagent.opencode.serverPasswordFile or extraEnv.OPENCODE_SERVER_PASSWORD.";
          })
          (helpers.mkReservedServeArgsAssertion {
            inherit (opencodeCfg) extraArgs;
            message = "services.aiagent.opencode.extraArgs must not override hostname, port, or mdns. Use services.aiagent.opencode.hostname and services.aiagent.opencode.port instead.";
          })
          {
            assertion =
              !(nginxCfg.enable && opencodeCfg.enable && opencodeCfg.domain != null) || hasOpencodePassword;
            message = "services.aiagent.opencode.domain requires services.aiagent.opencode.serverPasswordFile or extraEnv.OPENCODE_SERVER_PASSWORD because nginx will expose opencode remotely.";
          }
          {
            assertion = !openvscodeCfg.enable || openvscodeProgramName == "openvscode-server";
            message = "services.aiagent.openvscode.package must provide the `openvscode-server` executable.";
          }
          {
            assertion = !openvscodeCfg.enable || hasOpenVSCodeToken;
            message = "services.aiagent.openvscode.enable requires services.aiagent.openvscode.connectionTokenFile or connectionToken.";
          }
          (helpers.mkReservedOpenVSCodeArgsAssertion {
            inherit (openvscodeCfg) extraArgs;
            message = "services.aiagent.openvscode.extraArgs must not override the service host, port, or connection-token flags. Use services.aiagent.openvscode.hostname and services.aiagent.openvscode.port instead.";
          })
          {
            assertion = !computerUseVirtualDisplay.enable || effectiveComputerUseDisplay != null;
            message = "services.aiagent.opencode.mcp.computerUse.virtualDisplay.enable requires virtualDisplay.fullDesktop = true or virtualDisplay.display to be set.";
          }
          {
            assertion =
              !computerUseVirtualDisplay.browser.enable
              || (computerUseVirtualDisplay.enable && computerUseVirtualDisplay.fullDesktop);
            message = "services.aiagent.opencode.mcp.computerUse.virtualDisplay.browser.enable requires virtualDisplay.enable = true and virtualDisplay.fullDesktop = true.";
          }
          {
            assertion = !computerUseVirtualDisplay.enable || pkgs.stdenv.isLinux;
            message = "services.aiagent.opencode.mcp.computerUse.virtualDisplay is only supported on Linux.";
          }
          {
            assertion =
              !(opencodeCfg.mcp.enable && opencodeCfg.mcp.banani.enable) || opencodeCfg.extraEnv ? BANANI_API_KEY;
            message = "services.aiagent.opencode.mcp.banani.enable requires extraEnv.BANANI_API_KEY.";
          }
          {
            assertion = lib.length enabledPorts == lib.length (lib.unique enabledPorts);
            message = "Enabled aiagent services must use distinct ports.";
          }
          {
            assertion = lib.length enabledDomains == lib.length (lib.unique enabledDomains);
            message = "services.aiagent.opencode.domain and services.aiagent.openvscode.domain must be unique.";
          }
          {
            assertion = !nginxCfg.enable || nginxRoutes != [ ];
            message = "services.aiagent.nginx.enable requires at least one enabled backend with a domain. Set services.aiagent.opencode.domain or services.aiagent.openvscode.domain.";
          }
        ];

        home.packages =
          lib.optionals opencodeCfg.enable [ managedPackage ]
          ++ lib.optionals openvscodeCfg.enable [ openvscodeCfg.package ]
          ++ lib.optionals nginxCfg.enable [ nginxCfg.package ];

        warnings =
          lib.optional (opencodeCfg.mcp.enable && opencodeCfg.mcp.computerUse.enable && pkgs.stdenv.isLinux)
            ''
              services.aiagent.opencode on Linux needs X11 for computer-use-mcp. Set services.aiagent.opencode.mcp.computerUse.virtualDisplay.display for an existing X11 session or enable services.aiagent.opencode.mcp.computerUse.virtualDisplay.fullDesktop for a managed Xvfb/openbox desktop. Rango browser extension:
              ${helpers.rangoExtensionUrl}
            ''
          ++ lib.optional (opencodeCfg.mcp.enable && opencodeCfg.mcp.openPencil.package != null) ''
            services.aiagent.opencode.mcp.openPencil.package is ignored. ZSeven-W/openpencil exposes MCP over HTTP from a running instance; use services.aiagent.opencode.mcp.openPencil.url instead.
          ''
          ++ lib.optional (opencodeCfg.mcp.enable && opencodeCfg.mcp.openPencil.root != null) ''
            services.aiagent.opencode.mcp.openPencil.root is ignored. ZSeven-W/openpencil does not use OPENPENCIL_MCP_ROOT.
          ''
          ++ lib.optional (opencodeCfg.domain != null && !nginxCfg.enable) ''
            services.aiagent.opencode.domain is set but services.aiagent.nginx.enable is false, so the domain will not be routed anywhere.
          ''
          ++ lib.optional (openvscodeCfg.domain != null && !nginxCfg.enable) ''
            services.aiagent.openvscode.domain is set but services.aiagent.nginx.enable is false, so the domain will not be routed anywhere.
          ''
          ++ lib.optional (nginxCfg.enable && nginxCfg.listenAddress == "0.0.0.0") ''
            services.aiagent.nginx.listenAddress = "0.0.0.0" exposes nginx on every interface. Prefer binding directly to a Tailscale IP when possible.
          '';
      }

      (lib.mkIf (opencodeCfg.enable && pkgs.stdenv.isDarwin) (
        darwinSystem.mkAgent {
          name = "opencode";
          label = "ai.opencode";
          launcher = opencodeLauncher;
          inherit (opencodeCfg) workingDirectory autoStart;
        }
      ))

      (lib.mkIf (opencodeCfg.enable && pkgs.stdenv.isLinux) (
        linuxSystem.mkUserService {
          name = "opencode";
          description = "OpenCode user service";
          launcher = opencodeLauncher;
          inherit (opencodeCfg) workingDirectory autoStart;
        }
      ))

      (lib.mkIf (openvscodeCfg.enable && pkgs.stdenv.isDarwin) (
        darwinSystem.mkAgent {
          name = "openvscode-server";
          label = "ai.openvscode-server";
          launcher = openvscodeLauncher;
          inherit (openvscodeCfg) workingDirectory autoStart;
        }
      ))

      (lib.mkIf (openvscodeCfg.enable && pkgs.stdenv.isLinux) (
        linuxSystem.mkUserService {
          name = "openvscode-server";
          description = "OpenVSCode Server user service";
          launcher = openvscodeLauncher;
          inherit (openvscodeCfg) workingDirectory autoStart;
        }
      ))

      (lib.mkIf (nginxCfg.enable && pkgs.stdenv.isDarwin) (
        darwinSystem.mkAgent {
          name = "nginx";
          label = "ai.nginx";
          launcher = nginxLauncher;
          workingDirectory = nginxStateDir;
          inherit (nginxCfg) autoStart;
        }
      ))

      (lib.mkIf (nginxCfg.enable && pkgs.stdenv.isLinux) (
        linuxSystem.mkUserService {
          name = "nginx";
          description = "nginx reverse proxy user service";
          launcher = nginxLauncher;
          workingDirectory = nginxStateDir;
          inherit (nginxCfg) autoStart;
        }
      ))
    ]
  );
}
