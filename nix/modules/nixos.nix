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
  linuxSystem = import ./system/linux.nix { inherit lib; };

  cfg = config.services.aiagent;
  opencodeCfg = cfg.opencode;
  openvscodeCfg = cfg.openvscode;
  opencodeServerCfg = cfg.servers.opencode;
  openvscodeServerCfg = cfg.servers.openvscode;

  computerUseVirtualDisplay = opencodeCfg.mcp.computerUse.virtualDisplay;
  effectiveComputerUseDisplay = helpers.getVirtualDisplay computerUseVirtualDisplay;

  defaultPackage = self.packages.${pkgs.stdenv.hostPlatform.system}.opencode;
  defaultOpenVSCodePackage = self.packages.${pkgs.stdenv.hostPlatform.system}.openvscode-server;
  defaultBrowserPackage = self.packages.${pkgs.stdenv.hostPlatform.system}.chromium-with-rango;

  baseOpencodePackage =
    if lib.attrByPath [ "passthru" "isWrappedOpencode" ] false opencodeCfg.package then
      lib.attrByPath [ "passthru" "unwrappedOpencode" ] opencodeCfg.package opencodeCfg.package
    else
      opencodeCfg.package;

  sharedEnv = cfg.extraEnvs;
  effectiveOpencodeEnv = sharedEnv // opencodeCfg.extraEnv;

  packageExtraEnv = builtins.removeAttrs effectiveOpencodeEnv (
    lib.optional (opencodeServerCfg.serverPasswordFile != null) "OPENCODE_SERVER_PASSWORD"
    ++ lib.optional (opencodeServerCfg.serverUsername != null) "OPENCODE_SERVER_USERNAME"
  );

  hasOpenVSCodeToken =
    openvscodeServerCfg.connectionTokenFile != null || openvscodeServerCfg.connectionToken != null;
  openvscodeProgramName = builtins.baseNameOf (lib.getExe openvscodeCfg.package);

  wantsOpencodePackage = opencodeCfg.enable || opencodeServerCfg.enable;
  wantsOpenVSCodePackage = openvscodeCfg.enable || openvscodeServerCfg.enable;
  anyServerEnabled = opencodeServerCfg.enable || openvscodeServerCfg.enable;

  enabledPorts =
    lib.optionals opencodeServerCfg.enable [ opencodeServerCfg.port ]
    ++ lib.optionals openvscodeServerCfg.enable [ openvscodeServerCfg.port ];

  serviceHome =
    if opencodeServerCfg.enable then
      opencodeServerCfg.workingDirectory
    else
      openvscodeServerCfg.workingDirectory;

  managedPackage = mkOpencodePackage {
    inherit pkgs;
    opencodePackage = baseOpencodePackage;
    plugins = {
      meridian = {
        inherit (opencodeCfg.plugins.meridian) enable package;
      };
    };
    mcp = {
      inherit (opencodeCfg.mcp) enable;
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
    inherit (opencodeServerCfg) serverPasswordFile;
    virtualDisplay = {
      inherit (computerUseVirtualDisplay) enable fullDesktop;
      display = effectiveComputerUseDisplay;
      browser = {
        inherit (computerUseVirtualDisplay.browser) enable package;
      };
    };
    name = "opencode-systemd";
    preRun = helpers.mkBindAddressResolution {
      bindAddress = opencodeServerCfg.hostname;
      optionPath = "services.aiagent.servers.opencode.hostname";
      tailscaleCommand = lib.getExe pkgs.tailscale;
    };
    command = helpers.mkServeCommand {
      package = managedPackage;
      inherit (opencodeServerCfg) port extraArgs;
    };
    env =
      sharedEnv
      // helpers.mkServiceEnv {
        inherit (opencodeServerCfg) serverUsername;
        display = effectiveComputerUseDisplay;
      };
  };

  openvscodeLauncher = helpers.mkOpenVSCodeServiceLauncher {
    inherit pkgs;
    inherit (openvscodeCfg) package;
    inherit (openvscodeServerCfg)
      hostname
      port
      workingDirectory
      extraArgs
      connectionTokenFile
      connectionToken
      ;
    env = sharedEnv;
    name = "openvscode-server-systemd";
    optionPath = "services.aiagent.servers.openvscode.hostname";
  };

  renamedOptionModules = [
    (lib.mkRenamedOptionModule
      [
        "services"
        "aiagent"
        "opencode"
        "user"
      ]
      [
        "services"
        "aiagent"
        "user"
      ]
    )
    (lib.mkRenamedOptionModule
      [
        "services"
        "aiagent"
        "opencode"
        "group"
      ]
      [
        "services"
        "aiagent"
        "group"
      ]
    )
    (lib.mkRenamedOptionModule
      [
        "services"
        "aiagent"
        "opencode"
        "workingDirectory"
      ]
      [
        "services"
        "aiagent"
        "servers"
        "opencode"
        "workingDirectory"
      ]
    )
    (lib.mkRenamedOptionModule
      [
        "services"
        "aiagent"
        "opencode"
        "hostname"
      ]
      [
        "services"
        "aiagent"
        "servers"
        "opencode"
        "hostname"
      ]
    )
    (lib.mkRenamedOptionModule
      [
        "services"
        "aiagent"
        "opencode"
        "port"
      ]
      [
        "services"
        "aiagent"
        "servers"
        "opencode"
        "port"
      ]
    )
    (lib.mkRenamedOptionModule
      [
        "services"
        "aiagent"
        "opencode"
        "extraArgs"
      ]
      [
        "services"
        "aiagent"
        "servers"
        "opencode"
        "extraArgs"
      ]
    )
    (lib.mkRenamedOptionModule
      [
        "services"
        "aiagent"
        "opencode"
        "serverPasswordFile"
      ]
      [
        "services"
        "aiagent"
        "servers"
        "opencode"
        "serverPasswordFile"
      ]
    )
    (lib.mkRenamedOptionModule
      [
        "services"
        "aiagent"
        "opencode"
        "serverUsername"
      ]
      [
        "services"
        "aiagent"
        "servers"
        "opencode"
        "serverUsername"
      ]
    )
    (lib.mkRenamedOptionModule
      [
        "services"
        "aiagent"
        "openvscode"
        "hostname"
      ]
      [
        "services"
        "aiagent"
        "servers"
        "openvscode"
        "hostname"
      ]
    )
    (lib.mkRenamedOptionModule
      [
        "services"
        "aiagent"
        "openvscode"
        "port"
      ]
      [
        "services"
        "aiagent"
        "servers"
        "openvscode"
        "port"
      ]
    )
    (lib.mkRenamedOptionModule
      [
        "services"
        "aiagent"
        "openvscode"
        "workingDirectory"
      ]
      [
        "services"
        "aiagent"
        "servers"
        "openvscode"
        "workingDirectory"
      ]
    )
    (lib.mkRenamedOptionModule
      [
        "services"
        "aiagent"
        "openvscode"
        "extraArgs"
      ]
      [
        "services"
        "aiagent"
        "servers"
        "openvscode"
        "extraArgs"
      ]
    )
    (lib.mkRenamedOptionModule
      [
        "services"
        "aiagent"
        "openvscode"
        "connectionTokenFile"
      ]
      [
        "services"
        "aiagent"
        "servers"
        "openvscode"
        "connectionTokenFile"
      ]
    )
    (lib.mkRenamedOptionModule
      [
        "services"
        "aiagent"
        "openvscode"
        "connectionToken"
      ]
      [
        "services"
        "aiagent"
        "servers"
        "openvscode"
        "connectionToken"
      ]
    )
    (lib.mkRemovedOptionModule [ "services" "aiagent" "opencode" "domain" ] ''
      services.aiagent.opencode.domain has been removed. Bind services.aiagent.servers.opencode directly instead.
    '')
    (lib.mkRemovedOptionModule [ "services" "aiagent" "openvscode" "domain" ] ''
      services.aiagent.openvscode.domain has been removed. Bind services.aiagent.servers.openvscode directly instead.
    '')
    (lib.mkRemovedOptionModule [ "services" "aiagent" "nginx" ] ''
      services.aiagent.nginx has been removed. Bind services.aiagent.servers.* directly or front them with your own reverse proxy.
    '')
  ];
in
{
  imports = renamedOptionModules;

  options.services.aiagent = {
    extraEnvs = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Extra environment variables exported by all aiagent services and used as the base environment for the wrapped opencode package.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "opencode";
      description = "User account for the managed aiagent services.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "opencode";
      description = "Group for the managed aiagent services.";
    };

    opencode = {
      enable = lib.mkEnableOption "installing the wrapped opencode package";

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
        description = "Additional environment variables exported by the wrapped opencode package after services.aiagent.extraEnvs. This can include OPENCODE_SERVER_PASSWORD, though serverPasswordFile is preferred for secrets.";
      };

      plugins = {
        meridian = {
          enable = lib.mkEnableOption "the Meridian OpenCode plugin";

          package = lib.mkOption {
            type = lib.types.package;
            default = self.packages.${pkgs.stdenv.hostPlatform.system}.meridian;
            description = "Meridian package that provides the OpenCode plugin path.";
          };
        };
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
      enable = lib.mkEnableOption "installing the OpenVSCode Server package";

      package = lib.mkOption {
        type = lib.types.package;
        default = defaultOpenVSCodePackage;
        description = "OpenVSCode Server package to use.";
      };
    };

    servers = {
      opencode = {
        enable = lib.mkEnableOption "the opencode background service";

        workingDirectory = lib.mkOption {
          type = lib.types.str;
          default = "/var/lib/opencode";
          description = "Working directory used by the opencode service.";
        };

        hostname = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          description = "Address for opencode serve. Set this to \"tailscale\" to resolve tailscale ip -4 when the service starts.";
        };

        port = lib.mkOption {
          type = lib.types.port;
          default = 4096;
          description = "Port for opencode serve.";
        };

        extraArgs = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Extra arguments passed to opencode serve.";
        };

        serverPasswordFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = "File containing the password for OPENCODE_SERVER_PASSWORD. Use this or services.aiagent.extraEnvs.OPENCODE_SERVER_PASSWORD or services.aiagent.opencode.extraEnv.OPENCODE_SERVER_PASSWORD. If multiple values are set, the file value wins.";
        };

        serverUsername = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Optional username for HTTP basic auth. Defaults to opencode when unset.";
        };
      };

      openvscode = {
        enable = lib.mkEnableOption "the OpenVSCode Server background service";

        hostname = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          description = "Address for openvscode-server. Set this to \"tailscale\" to resolve tailscale ip -4 when the service starts.";
        };

        port = lib.mkOption {
          type = lib.types.port;
          default = 9998;
          description = "Port for openvscode-server --port.";
        };

        workingDirectory = lib.mkOption {
          type = lib.types.str;
          default = opencodeServerCfg.workingDirectory;
          description = "Working directory opened by OpenVSCode Server and used by the service.";
        };

        extraArgs = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Extra arguments passed to openvscode-server.";
        };

        connectionTokenFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = opencodeServerCfg.serverPasswordFile;
          description = "File containing the OpenVSCode Server connection token. Defaults to the opencode password file when present.";
        };

        connectionToken = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = effectiveOpencodeEnv.OPENCODE_SERVER_PASSWORD or null;
          description = "Inline OpenVSCode Server connection token. Defaults to the effective opencode password when present.";
        };
      };
    };
  };

  config = {
    assertions = [
      {
        assertion = !anyServerEnabled || cfg.user != "root";
        message = "services.aiagent.user must not be root.";
      }
      (helpers.mkPasswordAssertion {
        inherit (opencodeServerCfg) enable serverPasswordFile;
        bindAddress = opencodeServerCfg.hostname;
        extraEnv = effectiveOpencodeEnv;
        message = "services.aiagent.servers.opencode.hostname = \"tailscale\" or a non-loopback address requires a password. Set services.aiagent.servers.opencode.serverPasswordFile, services.aiagent.extraEnvs.OPENCODE_SERVER_PASSWORD, or services.aiagent.opencode.extraEnv.OPENCODE_SERVER_PASSWORD.";
      })
      (helpers.mkReservedServeArgsAssertion {
        inherit (opencodeServerCfg) enable extraArgs;
        message = "services.aiagent.servers.opencode.extraArgs must not override hostname, port, or mdns. Use services.aiagent.servers.opencode.hostname and services.aiagent.servers.opencode.port instead.";
      })
      {
        assertion = !wantsOpenVSCodePackage || openvscodeProgramName == "openvscode-server";
        message = "services.aiagent.openvscode.package must provide the openvscode-server executable.";
      }
      {
        assertion = !openvscodeServerCfg.enable || hasOpenVSCodeToken;
        message = "services.aiagent.servers.openvscode.enable requires services.aiagent.servers.openvscode.connectionTokenFile or connectionToken.";
      }
      (helpers.mkReservedOpenVSCodeArgsAssertion {
        inherit (openvscodeServerCfg) enable extraArgs;
        message = "services.aiagent.servers.openvscode.extraArgs must not override the service host, port, or connection-token flags. Use services.aiagent.servers.openvscode.hostname and services.aiagent.servers.openvscode.port instead.";
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
        assertion =
          !(opencodeCfg.mcp.enable && opencodeCfg.mcp.banani.enable) || effectiveOpencodeEnv ? BANANI_API_KEY;
        message = "services.aiagent.opencode.mcp.banani.enable requires services.aiagent.extraEnvs.BANANI_API_KEY or services.aiagent.opencode.extraEnv.BANANI_API_KEY.";
      }
      {
        assertion = lib.length enabledPorts == lib.length (lib.unique enabledPorts);
        message = "Enabled aiagent services must use distinct ports.";
      }
    ];

    warnings =
      lib.optional (opencodeCfg.mcp.enable && opencodeCfg.mcp.computerUse.enable) ''
        computer-use-mcp is desktop-oriented. On Linux it needs X11. Set services.aiagent.opencode.mcp.computerUse.virtualDisplay.display for an existing X11 session or enable services.aiagent.opencode.mcp.computerUse.virtualDisplay.fullDesktop for a managed Xvfb/openbox desktop. Rango browser extension:
        ${helpers.rangoExtensionUrl}
      ''
      ++ lib.optional (opencodeCfg.mcp.enable && opencodeCfg.mcp.openPencil.package != null) ''
        services.aiagent.opencode.mcp.openPencil.package is ignored. ZSeven-W/openpencil exposes MCP over HTTP from a running instance; use services.aiagent.opencode.mcp.openPencil.url instead.
      ''
      ++ lib.optional (opencodeCfg.mcp.enable && opencodeCfg.mcp.openPencil.root != null) ''
        services.aiagent.opencode.mcp.openPencil.root is ignored. ZSeven-W/openpencil does not use OPENPENCIL_MCP_ROOT.
      '';

    environment.systemPackages =
      lib.optionals wantsOpencodePackage [ managedPackage ]
      ++ lib.optionals wantsOpenVSCodePackage [ openvscodeCfg.package ];

    users.groups = lib.mkIf anyServerEnabled (
      lib.optionalAttrs (cfg.group == "opencode") {
        ${cfg.group} = { };
      }
    );

    users.users = lib.mkIf anyServerEnabled (
      lib.optionalAttrs (cfg.user == "opencode") {
        ${cfg.user} = {
          isSystemUser = true;
          inherit (cfg) group;
          home = serviceHome;
          createHome = true;
        };
      }
    );

    systemd.tmpfiles.rules =
      lib.optionals opencodeServerCfg.enable [
        "d ${opencodeServerCfg.workingDirectory} 0750 ${cfg.user} ${cfg.group} -"
      ]
      ++ lib.optionals (
        openvscodeServerCfg.enable
        && (
          !opencodeServerCfg.enable
          || openvscodeServerCfg.workingDirectory != opencodeServerCfg.workingDirectory
        )
      ) [ "d ${openvscodeServerCfg.workingDirectory} 0750 ${cfg.user} ${cfg.group} -" ];

    systemd.services =
      lib.optionalAttrs opencodeServerCfg.enable
        (linuxSystem.mkSystemService {
          name = "opencode";
          description = "OpenCode service";
          launcher = opencodeLauncher;
          inherit (opencodeServerCfg) workingDirectory;
          inherit (cfg) user group;
        }).systemd.services
      //
        lib.optionalAttrs openvscodeServerCfg.enable
          (linuxSystem.mkSystemService {
            name = "openvscode-server";
            description = "OpenVSCode Server service";
            launcher = openvscodeLauncher;
            inherit (openvscodeServerCfg) workingDirectory;
            inherit (cfg) user group;
          }).systemd.services;
  };
}
