{ lib }:
let
  mkEnvExports =
    envVars:
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: value: "export ${name}=${lib.escapeShellArg (toString value)}") envVars
    );
in
rec {
  rangoExtensionUrl = "https://chromewebstore.google.com/detail/rango/lnemjdnjjofijemhdogofbpcedhgcpmb";

  defaultManagedVirtualDisplay = ":99";

  inherit mkEnvExports;

  hasPasswordSource =
    serverPasswordFile: extraEnv: serverPasswordFile != null || extraEnv ? OPENCODE_SERVER_PASSWORD;

  normalizeLocalHost = hostname: if hostname == "0.0.0.0" then "127.0.0.1" else hostname;

  renderNginxConfig =
    {
      listenAddress,
      port,
      routes,
      stateDir,
      extraConfig ? "",
    }:
    let
      renderServer = route: ''
        server {
          listen ${listenAddress}:${toString port};
          server_name ${route.domain};

          location / {
            proxy_pass ${route.upstream};
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection $connection_upgrade;
            proxy_buffering off;
            proxy_read_timeout 3600s;
            proxy_send_timeout 3600s;
          }
        }
      '';

      serverBlocks = lib.concatMapStringsSep "\n\n" renderServer routes;
    in
    ''
      pid ${stateDir}/nginx.pid;
      error_log stderr notice;

      events {}

      http {
        access_log off;
        client_body_temp_path ${stateDir}/client_body_temp;
        proxy_temp_path ${stateDir}/proxy_temp;
        fastcgi_temp_path ${stateDir}/fastcgi_temp;
        uwsgi_temp_path ${stateDir}/uwsgi_temp;
        scgi_temp_path ${stateDir}/scgi_temp;

        map $http_upgrade $connection_upgrade {
          default upgrade;
          "" close;
        }

        ${serverBlocks}

        server {
          listen ${listenAddress}:${toString port} default_server;
          server_name _;
          return 444;
        }

        ${extraConfig}
      }
    '';

  getVirtualDisplay =
    virtualDisplay:
    if !(virtualDisplay.enable or false) then
      null
    else if (virtualDisplay.display or null) != null then
      virtualDisplay.display
    else if (virtualDisplay.fullDesktop or false) then
      defaultManagedVirtualDisplay
    else
      null;

  hasReservedArg =
    reserved: arg: lib.any (flag: arg == flag || lib.hasPrefix "${flag}=" arg) reserved;

  hasReservedArgs = reserved: args: lib.any (hasReservedArg reserved) args;

  hasReservedServeArg = hasReservedArgs [
    "--hostname"
    "--port"
    "--mdns"
  ];

  hasReservedOpenVSCodeArg = hasReservedArgs [
    "--connection-token"
    "--connection-token-file"
    "--host"
    "--port"
    "--socket"
    "--socket-path"
    "--without-connection-token"
  ];

  mkServeArgs =
    {
      hostname,
      port,
      extraArgs ? [ ],
    }:
    [
      "serve"
      "--hostname"
      hostname
      "--port"
      (toString port)
    ]
    ++ extraArgs;

  mkOpenVSCodeServerArgs =
    {
      hostname,
      port,
      workingDirectory,
      extraArgs ? [ ],
      connectionTokenFile ? null,
    }:
    [
      "--accept-server-license-terms"
      "--host"
      hostname
      "--port"
      (toString port)
    ]
    ++ lib.optionals (connectionTokenFile != null) [
      "--connection-token-file"
      (toString connectionTokenFile)
    ]
    ++ [ workingDirectory ]
    ++ extraArgs;

  mkServiceEnv =
    {
      serverUsername ? null,
      display ? null,
    }:
    lib.optionalAttrs (serverUsername != null) {
      OPENCODE_SERVER_USERNAME = serverUsername;
    }
    // lib.optionalAttrs (display != null) {
      DISPLAY = display;
    };

  mkPasswordAssertion =
    {
      hostname,
      serverPasswordFile,
      extraEnv,
      message,
    }:
    {
      assertion = hostname != "0.0.0.0" || hasPasswordSource serverPasswordFile extraEnv;
      inherit message;
    };

  mkReservedServeArgsAssertion =
    {
      extraArgs,
      message,
    }:
    {
      assertion = !(hasReservedServeArg extraArgs);
      inherit message;
    };

  mkReservedOpenVSCodeArgsAssertion =
    {
      extraArgs,
      message,
    }:
    {
      assertion = !(hasReservedOpenVSCodeArg extraArgs);
      inherit message;
    };

  mkServiceLauncher =
    {
      pkgs,
      package,
      args,
      env ? { },
      serverPasswordFile ? null,
      password ? null,
      passwordEnvVar ? "OPENCODE_SERVER_PASSWORD",
      preRun ? "",
      extraExecArgs ? "",
      virtualDisplay ? {
        enable = false;
      },
      name ? "opencode-service",
    }:
    let
      virtualDisplayEnabled = virtualDisplay.enable or false;
      managedVirtualDesktop = virtualDisplay.fullDesktop or false;
      virtualDisplayValue = virtualDisplay.display or null;
      launchBrowser = lib.attrByPath [ "browser" "enable" ] false virtualDisplay;
      browserPackage = lib.attrByPath [ "browser" "package" ] null virtualDisplay;
    in
    pkgs.writeShellScript name ''
      set -eu

      ${mkEnvExports env}

      ${lib.optionalString (password != null) ''
        export ${passwordEnvVar}=${lib.escapeShellArg password}
      ''}

      ${lib.optionalString (serverPasswordFile != null) ''
        if [ ! -r ${lib.escapeShellArg (toString serverPasswordFile)} ]; then
          printf '%s\n' ${lib.escapeShellArg "Configured ${passwordEnvVar} file is not readable: ${toString serverPasswordFile}"} >&2
          exit 1
        fi
        export ${passwordEnvVar}="$(${pkgs.coreutils}/bin/cat ${lib.escapeShellArg (toString serverPasswordFile)})"
      ''}

      ${preRun}

      ${lib.optionalString virtualDisplayEnabled ''
        export DISPLAY=${lib.escapeShellArg virtualDisplayValue}
      ''}

      ${lib.optionalString managedVirtualDesktop ''
        cleanup_managed_desktop() {
          status=$?

          if [ -n "''${browser_pid:-}" ]; then
            kill "$browser_pid" 2>/dev/null || true
            wait "$browser_pid" 2>/dev/null || true
          fi

          if [ -n "''${openbox_pid:-}" ]; then
            kill "$openbox_pid" 2>/dev/null || true
            wait "$openbox_pid" 2>/dev/null || true
          fi

          if [ -n "''${xvfb_pid:-}" ]; then
            kill "$xvfb_pid" 2>/dev/null || true
            wait "$xvfb_pid" 2>/dev/null || true
          fi

          exit "$status"
        }

        display_number="''${DISPLAY#:}"
        display_socket="/tmp/.X11-unix/X$display_number"
        display_lock="/tmp/.X$display_number-lock"

        if ${pkgs.xorg.xdpyinfo}/bin/xdpyinfo -display "$DISPLAY" >/dev/null 2>&1; then
          printf '%s\n' "Managed virtual display $DISPLAY is already active; choose a different services.aiagent.opencode.mcp.computerUse.virtualDisplay.display." >&2
          exit 1
        fi

        if [ -e "$display_socket" ] || [ -e "$display_lock" ]; then
          rm -f "$display_socket" "$display_lock"
        fi

        trap cleanup_managed_desktop EXIT INT TERM

        ${pkgs.xorg.xorgserver}/bin/Xvfb "$DISPLAY" -screen 0 1920x1080x24 -nolisten tcp -ac &
        xvfb_pid=$!

        desktop_ready=0
        for _ in $(${pkgs.coreutils}/bin/seq 1 50); do
          if ${pkgs.xorg.xdpyinfo}/bin/xdpyinfo -display "$DISPLAY" >/dev/null 2>&1; then
            desktop_ready=1
            break
          fi
          sleep 0.2
        done

        if [ "$desktop_ready" -ne 1 ]; then
          printf '%s\n' "Timed out waiting for managed virtual display $DISPLAY." >&2
          exit 1
        fi

        ${pkgs.xorg.xsetroot}/bin/xsetroot -display "$DISPLAY" -solid '#202020' >/dev/null 2>&1 || true
        ${pkgs.openbox}/bin/openbox >/dev/null 2>&1 &
        openbox_pid=$!

        ${lib.optionalString launchBrowser ''
          ${lib.getExe browserPackage} >/dev/null 2>&1 &
          browser_pid=$!
        ''}

        ${lib.getExe package} ${lib.escapeShellArgs args}${extraExecArgs} &
        opencode_pid=$!
        wait "$opencode_pid"
        exit $?
      ''}

      ${lib.optionalString (!managedVirtualDesktop) ''
        exec ${lib.getExe package} ${lib.escapeShellArgs args}${extraExecArgs}
      ''}
    '';

  mkOpenVSCodeServiceLauncher =
    {
      pkgs,
      package,
      hostname,
      port,
      workingDirectory,
      extraArgs ? [ ],
      connectionTokenFile ? null,
      connectionToken ? null,
      name ? "openvscode-service",
    }:
    let
      useInlineConnectionToken = connectionTokenFile == null && connectionToken != null;
    in
    mkServiceLauncher {
      inherit pkgs package name;
      serverPasswordFile = connectionTokenFile;
      password = if useInlineConnectionToken then connectionToken else null;
      passwordEnvVar = "OPENCODE_SERVER_PASSWORD";
      args = mkOpenVSCodeServerArgs {
        inherit
          hostname
          port
          workingDirectory
          extraArgs
          connectionTokenFile
          ;
      };
      extraExecArgs =
        if useInlineConnectionToken then " --connection-token \"$OPENCODE_SERVER_PASSWORD\"" else "";
    };

  mkNginxServiceLauncher =
    {
      pkgs,
      package,
      configFile,
      stateDir,
      name ? "nginx-service",
    }:
    mkServiceLauncher {
      inherit pkgs package name;
      args = [
        "-p"
        stateDir
        "-c"
        configFile
        "-g"
        "daemon off;"
      ];
      preRun = ''
        mkdir -p \
          ${lib.escapeShellArg stateDir} \
          ${lib.escapeShellArg "${stateDir}/client_body_temp"} \
          ${lib.escapeShellArg "${stateDir}/proxy_temp"} \
          ${lib.escapeShellArg "${stateDir}/fastcgi_temp"} \
          ${lib.escapeShellArg "${stateDir}/uwsgi_temp"} \
          ${lib.escapeShellArg "${stateDir}/scgi_temp"}
      '';
    };
}
