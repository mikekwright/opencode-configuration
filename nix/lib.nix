{ lib }:
let
  mkEnvExports = envVars:
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: value: "export ${name}=${lib.escapeShellArg (toString value)}") envVars
    );
in
rec {
  rangoExtensionUrl = "https://chromewebstore.google.com/detail/rango/lnemjdnjjofijemhdogofbpcedhgcpmb";

  defaultManagedVirtualDisplay = ":99";

  inherit mkEnvExports;

  getVirtualDisplay = virtualDisplay:
    if !(virtualDisplay.enable or false) then
      null
    else if (virtualDisplay.display or null) != null then
      virtualDisplay.display
    else if (virtualDisplay.fullDesktop or false) then
      defaultManagedVirtualDisplay
    else
      null;

  hasReservedServeArg =
    args:
    lib.any (
      arg:
      arg == "--hostname"
      || lib.hasPrefix "--hostname=" arg
      || arg == "--port"
      || lib.hasPrefix "--port=" arg
      || arg == "--mdns"
    ) args;

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
      assertion =
        hostname != "0.0.0.0"
        || serverPasswordFile != null
        || extraEnv ? OPENCODE_SERVER_PASSWORD;
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

  mkServiceLauncher =
    {
      pkgs,
      package,
      args,
      env ? { },
      serverPasswordFile ? null,
      virtualDisplay ? { enable = false; },
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

      ${lib.optionalString (serverPasswordFile != null) ''
        if [ ! -r ${lib.escapeShellArg (toString serverPasswordFile)} ]; then
          printf '%s\n' ${lib.escapeShellArg "Configured OPENCODE_SERVER_PASSWORD file is not readable: ${toString serverPasswordFile}"} >&2
          exit 1
        fi
        export OPENCODE_SERVER_PASSWORD="$(${pkgs.coreutils}/bin/cat ${lib.escapeShellArg (toString serverPasswordFile)})"
      ''}

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
          printf '%s\n' "Managed virtual display $DISPLAY is already active; choose a different services.opencode.mcp.computerUse.virtualDisplay.display." >&2
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

        ${lib.getExe package} ${lib.escapeShellArgs args} &
        opencode_pid=$!
        wait "$opencode_pid"
        exit $?
      ''}

      ${lib.optionalString (!managedVirtualDesktop) ''
        exec ${lib.getExe package} ${lib.escapeShellArgs args}
      ''}
    '';
}
