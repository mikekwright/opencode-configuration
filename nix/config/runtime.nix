{ lib }:
let
  bundledAgents = import ./agents;

  normalizeAgent = agent:
    let
      cleanedAgent = builtins.removeAttrs agent [ "permissions" ];
    in
    if agent ? permission then
      cleanedAgent
    else if agent ? permissions then
      cleanedAgent
      // {
        permission = agent.permissions;
      }
    else
      cleanedAgent;

  permissionDefaults = {
    doom_loop = "ask";
    webfetch = "ask";
    bash = {
      "*" = "ask";
      "git status" = "allow";
      "git diff" = "allow";
      "ls" = "allow";
      "tree" = "allow";
      "cat" = "allow";
      "pwd" = "allow";
      "cd" = "allow";
      "nix" = "allow";
      "poetry run" = "allow";
      "pytest" = "allow";
      "npm run build" = "allow";
    };
  };
in
{
  autoupdate = false;
  plugin = [ "opencode-browser" ];
  agent = lib.mapAttrs (_: normalizeAgent) bundledAgents;
  permission = permissionDefaults;
  provider = {
    lmstudio = {
      npm = "@ai-sdk/openai-compatible";
      name = "LM Studio (Personal)";
      options = {
        baseURL = "https://codemodel.mikeanddede.com/v1";
        headers = {
          "X-Platform-Token" = "{env:OPENCODE_PLATFORM_TOKEN}";
        };
        models = {
          "qwen/qwen3-coder-30b" = {
            name = "qwen3-coder-30b";
          };
        };
      };
    };
  };
}
