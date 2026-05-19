{ lib }:
let
  mkEnvExports = envVars:
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: value: "export ${name}=${lib.escapeShellArg (toString value)}") envVars
    );
in
rec {
  rangoExtensionUrl = "https://chromewebstore.google.com/detail/rango/lnemjdnjjofijemhdogofbpcedhgcpmb";

  inherit mkEnvExports;

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
    }:
    lib.optionalAttrs (serverUsername != null) {
      OPENCODE_SERVER_USERNAME = serverUsername;
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
      name ? "opencode-service",
    }:
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

      exec ${lib.getExe package} ${lib.escapeShellArgs args}
    '';
}
