let
  lead-model = "openai/gpt-5.4";
  analyzer-model = "openai/gpt-5.4";
  architect-model = "openai/gpt-5.4";
  coder-model = "openai/codex-mini-latest";
  reviewer-model = "github-copilot/grok-code-fast-1";
  devops-model = "openai/codex-mini-latest";

  modelDefaults = {
    inherit
      lead-model
      analyzer-model
      architect-model
      coder-model
      reviewer-model
      devops-model
      ;
  };

  agentModules = [
    ./flake-setup.nix
    ./opencode-agent-manager.nix
    ./opencode-manager.nix
  ];
in
builtins.foldl' (acc: module: acc // (import module modelDefaults)) { } agentModules
