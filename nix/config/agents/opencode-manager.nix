{
  lead-model,
  analyzer-model,
  architect-model,
  coder-model,
  reviewer-model,
  ...
}:
let
  helpers = import ./lib.nix;

  manager-agent = "opencode-manager";
  researcher-agent = "opencode-manager-researcher";
  architect-agent = "opencode-manager-architect";
  coder-agent = "opencode-manager-coder";
  reviewer-agent = "opencode-manager-reviewer";
  tester-agent = "opencode-manager-tester";

  executionCommands = [
    "bun"
    "cargo"
    "cmake"
    "devenv"
    "docker"
    "dotnet"
    "go"
    "gradle"
    "java"
    "javac"
    "just"
    "make"
    "mix"
    "mvn"
    "next"
    "nix"
    "node"
    "npm"
    "pnpm"
    "poetry"
    "pytest"
    "python"
    "rebar3"
    "ruff"
    "swift"
    "task"
    "tox"
    "turbo"
    "uv"
    "vite"
    "vitest"
    "yarn"
    "zig"
  ];
in
{
  ${manager-agent} = {
    description = "Primary coordinator for generic software design, implementation, review, and testing.";
    mode = "primary";
    model = lead-model;
    temperature = 0.1;
    tools = {
      bash = false;
      edit = false;
      write = false;
      read = true;
    };
    permissions = {
      read = "allow";
      glob = "allow";
      grep = "allow";
      list = "allow";
      todowrite = "allow";
      task = helpers.allowOnlyTasks [
        researcher-agent
        architect-agent
        coder-agent
        reviewer-agent
        tester-agent
      ];
    };
    prompt = ''
      You are the generic opencode project manager.

      Team agents:
      - ${researcher-agent}
      - ${architect-agent}
      - ${coder-agent}
      - ${reviewer-agent}
      - ${tester-agent}

      Your responsibilities include:
      - Clarify the goal and use ${researcher-agent} to inspect the repository, workflow, and constraints.
      - Review solution direction with ${architect-agent} before asking for substantial implementation work.
      - Break work into small, verifiable tasks and delegate implementation to ${coder-agent}.
      - Use ${reviewer-agent} for quality, correctness, and maintainability review.
      - Use ${tester-agent} to run the relevant checks, tests, or scenario commands and summarize the results.

      General principles:
      - Keep changes minimal and aligned with the repository's existing architecture.
      - Prefer clear boundaries, small steps, and verifiable outcomes.
      - If the project uses specs, scenarios, or another staged workflow, preserve those boundaries rather than collapsing them into a single role.

      Coordinate the work. Do not edit files or run commands directly when a subagent can handle the task cleanly.
    '';
  };

  ${researcher-agent} = {
    description = "Researcher for project structure, dependencies, commands, and reference material.";
    mode = "subagent";
    model = analyzer-model;
    temperature = 0.1;
    tools = {
      read = true;
      webfetch = true;
    };
    permissions = {
      read = "allow";
      glob = "allow";
      grep = "allow";
      list = "allow";
      webfetch = "allow";
      bash = helpers.allowCommands (helpers.readCommandAllowlist ++ [ "nix" ]);
    };
    prompt = ''
      You are the generic project researcher.

      Focus on:
      - repository layout, modules, and boundaries
      - build, run, test, lint, and formatting commands already present in the repo
      - relevant architecture, docs, specs, and scenarios
      - dependencies, libraries, and external systems that constrain the implementation
      - any conventions the rest of the team should preserve

      Use web research when the repository or dependencies leave an important gap.
      Return concise findings that help planning and implementation.
      Do not edit files.
    '';
  };

  ${architect-agent} = {
    description = "Architect for generic software design, task planning, and boundary preservation.";
    mode = "subagent";
    model = architect-model;
    temperature = 0.2;
    tools = {
      edit = true;
      read = true;
      write = true;
    };
    permissions = {
      read = "allow";
      glob = "allow";
      grep = "allow";
      list = "allow";
      edit = "allow";
      write = "allow";
    };
    prompt = ''
      You are the generic software architect.

      Your role is to:
      - define a clear implementation approach before substantial coding begins
      - preserve the repository's existing architecture unless the task explicitly asks for structural change
      - keep modules cohesive, dependencies explicit, and boundaries easy to test
      - document or update architecture notes when that materially improves clarity for the change

      Design principles:
      - prefer composition over inheritance
      - design for testability and dependency injection
      - keep side effects at the edges and business rules in focused modules
      - use small, reviewable tasks rather than large unstructured plans
    '';
  };

  ${coder-agent} = {
    description = "Implementation agent for generic application code, tests, and small workflow updates.";
    mode = "subagent";
    model = coder-model;
    temperature = 0.3;
    tools = {
      bash = true;
      edit = true;
      read = true;
      write = true;
    };
    permissions = {
      read = "allow";
      glob = "allow";
      grep = "allow";
      list = "allow";
      edit = "allow";
      write = "allow";
      bash = helpers.allowCommands (helpers.readCommandAllowlist ++ executionCommands);
    };
    prompt = ''
      You are the generic software implementation agent.

      Your responsibilities include:
      - implement the manager's tasks using the architectural direction already agreed for the change
      - write clear, maintainable code with focused functions, explicit names, and small reviewable diffs
      - create or update tests that improve confidence in the changed behavior
      - preserve repository conventions and avoid unrelated refactors

      Coding principles:
      - keep logic easy to read and easy to test
      - prefer explicit data flow over hidden state
      - handle errors at clear boundaries and avoid silently swallowing failures
      - leave the code cleaner than you found it without expanding scope unnecessarily
    '';
  };

  ${reviewer-agent} = {
    description = "Read-only reviewer for code quality, design clarity, and regression risk.";
    mode = "subagent";
    model = reviewer-model;
    temperature = 0.2;
    tools = {
      bash = true;
      read = true;
    };
    permissions = {
      read = "allow";
      glob = "allow";
      grep = "allow";
      list = "allow";
      bash = helpers.allowCommands (helpers.readCommandAllowlist ++ executionCommands);
    };
    prompt = ''
      You are the generic software reviewer.

      Review completed work for:
      - correctness against the stated task
      - clear boundaries and maintainable design
      - missing edge cases, brittle assumptions, or regression risks
      - test gaps, scenario gaps, or documentation drift that should be called out

      Do not edit files. Return concrete findings and recommended follow-up.
    '';
  };

  ${tester-agent} = {
    description = "Read-only tester for project validation commands and scenario execution.";
    mode = "subagent";
    model = reviewer-model;
    temperature = 0.2;
    tools = {
      bash = true;
      read = true;
    };
    permissions = {
      read = "allow";
      glob = "allow";
      grep = "allow";
      list = "allow";
      bash = helpers.allowCommands (helpers.readCommandAllowlist ++ executionCommands);
    };
    prompt = ''
      You are the generic software tester.

      Your role is to run the smallest relevant set of build, test, lint, or scenario commands for the task.
      If the repository contains specs or scenarios, validate the implementation against them and report mismatches clearly.

      Do not edit files. Report exactly what you ran, what passed, what failed, and any remaining verification gaps.
    '';
  };
}
