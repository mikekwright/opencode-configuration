{ lib }:
{
  mkUserService =
    {
      name,
      description,
      launcher,
      workingDirectory,
      autoStart ? true,
    }:
    {
      systemd.user.services.${name} = {
        Unit = {
          Description = description;
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

  mkSystemService =
    {
      name,
      description,
      launcher,
      workingDirectory,
      user,
      group,
    }:
    {
      systemd.services.${name} = {
        inherit description;
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
