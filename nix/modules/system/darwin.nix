{ helpers, pkgs }:
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
        name = "opencode-launchd";
        args = helpers.mkServeArgs {
          inherit hostname port extraArgs;
        };
        env = helpers.mkServiceEnv {
          inherit serverUsername;
        };
      };
    in
    {
      launchd.agents.opencode = {
        enable = true;
        config = {
          Label = "ai.opencode";
          ProgramArguments = [ "${launcher}" ];
          RunAtLoad = autoStart;
          KeepAlive = autoStart;
          WorkingDirectory = workingDirectory;
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
      launcher = helpers.mkCodeEditorServiceLauncher {
        inherit
          pkgs
          package
          hostname
          port
          workingDirectory
          extraArgs
          serverPasswordFile
          password
          ;
        name = "code-server-launchd";
      };
    in
    {
      launchd.agents.code-server = {
        enable = true;
        config = {
          Label = "ai.code-server";
          ProgramArguments = [ "${launcher}" ];
          RunAtLoad = autoStart;
          KeepAlive = autoStart;
          WorkingDirectory = workingDirectory;
        };
      };
    };
}
