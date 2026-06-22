{ lib }:
let
  mkEnvExports =
    envVars:
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: value: "export ${name}=${lib.escapeShellArg (toString value)}") envVars
    );

  loopbackBindAddresses = [
    "127.0.0.1"
    "::1"
    "localhost"
  ];
in
rec {
  rangoExtensionUrl = "https://chromewebstore.google.com/detail/rango/lnemjdnjjofijemhdogofbpcedhgcpmb";

  defaultManagedVirtualDisplay = ":99";

  inherit mkEnvExports;

  hasPasswordSource =
    serverPasswordFile: extraEnv: serverPasswordFile != null || extraEnv ? OPENCODE_SERVER_PASSWORD;

  isLoopbackBindAddress = bindAddress: lib.elem bindAddress loopbackBindAddresses;

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

  mkServeCommand =
    {
      package,
      port,
      extraArgs ? [ ],
      bindAddressEnvVar ? "AIAGENT_BIND_ADDRESS",
    }:
    let
      extraArgsString = lib.optionalString (extraArgs != [ ]) " ${lib.escapeShellArgs extraArgs}";
      bindAddressRef = ''"${"$"}${bindAddressEnvVar}"'';
    in
    "exec ${lib.getExe package} serve --hostname ${bindAddressRef} --port ${lib.escapeShellArg (toString port)}${extraArgsString}";

  mkOpenVSCodeServerCommand =
    {
      package,
      port,
      workingDirectory,
      extraArgs ? [ ],
      connectionTokenFile ? null,
      connectionTokenEnvVar ? null,
      bindAddressEnvVar ? "AIAGENT_BIND_ADDRESS",
    }:
    let
      extraArgsString = lib.optionalString (extraArgs != [ ]) " ${lib.escapeShellArgs extraArgs}";
      bindAddressRef = ''"${"$"}${bindAddressEnvVar}"'';
      connectionTokenFileArgs = lib.optionalString (
        connectionTokenFile != null
      ) " --connection-token-file ${lib.escapeShellArg (toString connectionTokenFile)}";
      connectionTokenArgs = lib.optionalString (
        connectionTokenEnvVar != null
      ) " --connection-token \"${"$"}${connectionTokenEnvVar}\"";
    in
    "exec ${lib.getExe package} --accept-server-license-terms --host ${bindAddressRef} --port ${lib.escapeShellArg (toString port)}${connectionTokenFileArgs}${connectionTokenArgs} ${lib.escapeShellArg workingDirectory}${extraArgsString}";

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

  mkBindAddressResolution =
    {
      bindAddress,
      optionPath,
      envVar ? "AIAGENT_BIND_ADDRESS",
      tailscaleCommand ? "tailscale",
    }:
    let
      bindAddressRef = ''"${"$"}${envVar}"'';
      escapedTailscaleCommand = lib.escapeShellArg tailscaleCommand;
    in
    ''
      ${envVar}=${lib.escapeShellArg bindAddress}

      if [ ${bindAddressRef} = "tailscale" ]; then
        if ! command -v ${escapedTailscaleCommand} >/dev/null 2>&1; then
          printf '%s\n' ${lib.escapeShellArg "${optionPath} = \"tailscale\" requires the tailscale CLI to be available."} >&2
          exit 1
        fi

        set -- $(${escapedTailscaleCommand} ip -4 2>/dev/null)

        if [ "$#" -lt 1 ]; then
          printf '%s\n' ${lib.escapeShellArg "Failed to resolve a Tailscale IPv4 address for ${optionPath} = \"tailscale\"."} >&2
          exit 1
        fi

        ${envVar}="$1"
      fi

      export ${envVar}
    '';

  mkPasswordAssertion =
    {
      enable ? true,
      bindAddress,
      serverPasswordFile,
      extraEnv,
      message,
    }:
    {
      assertion =
        !enable || isLoopbackBindAddress bindAddress || hasPasswordSource serverPasswordFile extraEnv;
      inherit message;
    };

  mkReservedServeArgsAssertion =
    {
      enable ? true,
      extraArgs,
      message,
    }:
    {
      assertion = !enable || !(hasReservedServeArg extraArgs);
      inherit message;
    };

  mkReservedOpenVSCodeArgsAssertion =
    {
      enable ? true,
      extraArgs,
      message,
    }:
    {
      assertion = !enable || !(hasReservedOpenVSCodeArg extraArgs);
      inherit message;
    };

  mkServiceLauncher =
    {
      pkgs,
      package,
      args ? [ ],
      command ? null,
      env ? { },
      serverPasswordFile ? null,
      password ? null,
      passwordEnvVar ? "OPENCODE_SERVER_PASSWORD",
      preRun ? "",
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
      launchCommand =
        if command != null then
          command
        else
          let
            argsString = lib.optionalString (args != [ ]) " ${lib.escapeShellArgs args}";
          in
          "exec ${lib.getExe package}${argsString}";
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

      run_main() {
        ${launchCommand}
      }

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

        run_main &
        service_pid=$!
        wait "$service_pid"
        exit $?
      ''}

      ${lib.optionalString (!managedVirtualDesktop) ''
        run_main
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
      env ? { },
      name ? "openvscode-service",
      optionPath ? "services.aiagent.servers.openvscode.hostname",
    }:
    let
      useInlineConnectionToken = connectionTokenFile == null && connectionToken != null;
    in
    mkServiceLauncher {
      inherit
        pkgs
        package
        name
        env
        ;
      serverPasswordFile = connectionTokenFile;
      password = if useInlineConnectionToken then connectionToken else null;
      passwordEnvVar = "AIAGENT_OPENVSCODE_CONNECTION_TOKEN";
      preRun = mkBindAddressResolution {
        bindAddress = hostname;
        inherit optionPath;
        tailscaleCommand = lib.getExe pkgs.tailscale;
      };
      command = mkOpenVSCodeServerCommand {
        inherit
          package
          port
          workingDirectory
          extraArgs
          connectionTokenFile
          ;
        connectionTokenEnvVar =
          if useInlineConnectionToken then "AIAGENT_OPENVSCODE_CONNECTION_TOKEN" else null;
      };
    };
}
