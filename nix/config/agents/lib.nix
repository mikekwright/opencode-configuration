{
  allowCommands = commands:
    builtins.listToAttrs (
      builtins.concatLists (
        builtins.map (command: [
          {
            name = command;
            value = "allow";
          }
          {
            name = "${command} *";
            value = "allow";
          }
        ]) commands
      )
    );

  allowOnlyTasks = taskNames:
    builtins.listToAttrs (
      [
        {
          name = "*";
          value = "deny";
        }
      ]
      ++ builtins.map (taskName: {
        name = taskName;
        value = "allow";
      }) taskNames
    );

  readCommandAllowlist = [
    "cat"
    "date"
    "dirname"
    "du"
    "file"
    "git diff"
    "git status"
    "grep"
    "head"
    "ls"
    "pwd"
    "realpath"
    "stat"
    "tail"
    "tree"
    "uname"
    "wc"
    "whoami"
  ];

  renderGuideCatalog = guides:
    let
      names = builtins.sort builtins.lessThan (builtins.attrNames guides);
      renderGuide = name:
        let
          guide = guides.${name};
          frameworkText =
            if guide.frameworks == [ ] then
              "none noted"
            else
              builtins.concatStringsSep ", " guide.frameworks;
        in
        ''
          ### ${guide.title}
          - Detect with: ${builtins.concatStringsSep ", " guide.detect}
          - Frameworks and tools: ${frameworkText}
${builtins.concatStringsSep "\n" (builtins.map (item: "  - ${item}") guide.guidance)}
        '';
    in
    builtins.concatStringsSep "\n\n" (builtins.map renderGuide names);
}
