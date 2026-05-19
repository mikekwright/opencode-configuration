{ lib, helpers, pkgs }:
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
    }:
    let
      launcher = helpers.mkServiceLauncher {
        inherit pkgs package serverPasswordFile;
        name = "opencode-systemd-user";
        args = helpers.mkServeArgs {
          inherit hostname port extraArgs;
        };
        env = helpers.mkServiceEnv {
          inherit serverUsername;
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
    }:
    let
      launcher = helpers.mkServiceLauncher {
        inherit pkgs package serverPasswordFile;
        name = "opencode-systemd";
        args = helpers.mkServeArgs {
          inherit hostname port extraArgs;
        };
        env = helpers.mkServiceEnv {
          inherit serverUsername;
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
}
