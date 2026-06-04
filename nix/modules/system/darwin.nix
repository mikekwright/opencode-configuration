_: {
  mkAgent =
    {
      name,
      label,
      launcher,
      workingDirectory,
      autoStart ? true,
    }:
    {
      launchd.agents.${name} = {
        enable = true;
        config = {
          Label = label;
          ProgramArguments = [ "${launcher}" ];
          RunAtLoad = autoStart;
          KeepAlive = autoStart;
          WorkingDirectory = workingDirectory;
        };
      };
    };
}
