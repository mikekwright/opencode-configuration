{
  lib,
  helpers,
  pkgs,
}:
{
  mkHomeManagerService =
    {
      package,
      hostname,
      port,
      extraArgs ? [ ],
      workingDirectory,
      autoStart ? true,
      serverUsername ? null,
      serverPasswordFile ? null,
      virtualDisplay ? {
        enable = false;
      },
    }:
    let
      launcher = helpers.mkServiceLauncher {
        inherit
          pkgs
          package
          serverPasswordFile
          virtualDisplay
          ;
        name = "opencode-systemd-user";
        args = helpers.mkServeArgs {
          inherit hostname port extraArgs;
        };
        env = helpers.mkServiceEnv {
          inherit serverUsername;
          display = virtualDisplay.display or null;
        };
      };
    in
    {
      systemd.user.services.opencode = {
        Unit = {
          Description = "OpenCode user service";
          After = [ "network.target" ];
        };

        Service = {
          ExecStart = "${launcher}";
          WorkingDirectory = workingDirectory;
          Restart = "on-failure";
        };

        Install = lib.mkIf autoStart {
          WantedBy = [ "default.target" ];
        };
      };
    };

  mkCodeServerHomeManagerService =
    {
      package,
      hostname,
      port,
      extraArgs ? [ ],
      workingDirectory,
      autoStart ? true,
      serverPasswordFile ? null,
      password ? null,
    }:
    let
      launcher = helpers.mkServiceLauncher {
        inherit
          pkgs
          package
          serverPasswordFile
          password
          ;
        passwordEnvVar = "PASSWORD";
        name = "code-server-systemd-user";
        args = helpers.mkCodeServerArgs {
          inherit
            hostname
            port
            workingDirectory
            extraArgs
            ;
        };
      };
    in
    {
      systemd.user.services.code-server = {
        Unit = {
          Description = "code-server user service";
          After = [ "network.target" ];
        };

        Service = {
          ExecStart = "${launcher}";
          WorkingDirectory = workingDirectory;
          Restart = "on-failure";
        };

        Install = lib.mkIf autoStart {
          WantedBy = [ "default.target" ];
        };
      };
    };

  mkNixosService =
    {
      package,
      hostname,
      port,
      extraArgs ? [ ],
      workingDirectory,
      user,
      group,
      serverUsername ? null,
      serverPasswordFile ? null,
      virtualDisplay ? {
        enable = false;
      },
    }:
    let
      launcher = helpers.mkServiceLauncher {
        inherit
          pkgs
          package
          serverPasswordFile
          virtualDisplay
          ;
        name = "opencode-systemd";
        args = helpers.mkServeArgs {
          inherit hostname port extraArgs;
        };
        env = helpers.mkServiceEnv {
          inherit serverUsername;
          display = virtualDisplay.display or null;
        };
      };
    in
    {
      systemd.services.opencode = {
        description = "OpenCode headless service";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];

        serviceConfig = {
          Type = "simple";
          User = user;
          Group = group;
          WorkingDirectory = workingDirectory;
          ExecStart = "${launcher}";
          Restart = "on-failure";
        };
      };
    };

  mkCodeServerNixosService =
    {
      package,
      hostname,
      port,
      extraArgs ? [ ],
      workingDirectory,
      user,
      group,
      serverPasswordFile ? null,
      password ? null,
    }:
    let
      launcher = helpers.mkServiceLauncher {
        inherit
          pkgs
          package
          serverPasswordFile
          password
          ;
        passwordEnvVar = "PASSWORD";
        name = "code-server-systemd";
        args = helpers.mkCodeServerArgs {
          inherit
            hostname
            port
            workingDirectory
            extraArgs
            ;
        };
      };
    in
    {
      systemd.services.code-server = {
        description = "code-server service";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];

        serviceConfig = {
          Type = "simple";
          User = user;
          Group = group;
          WorkingDirectory = workingDirectory;
          ExecStart = "${launcher}";
          Restart = "on-failure";
        };
      };
    };
}
