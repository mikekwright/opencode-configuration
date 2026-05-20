{
  c = {
    title = "C";
    detect = [ "*.c" "*.h" "CMakeLists.txt" "meson.build" "compile_commands.json" ];
    frameworks = [ "cmake" "meson" "criterion" "ctest" ];
    guidance = [
      "Prefer modern C (C17 or C23) unless the project is pinned to an older standard, and keep ownership rules explicit around every allocation boundary."
      "Reach for CMake or Meson rather than ad hoc shell build logic, and keep compiler flags, sanitizers, and test targets declarative."
      "Model resource cleanup clearly, keep headers narrow, and avoid hidden global state that makes tests or portability harder."
      "Use small focused modules, explicit error returns, and tests through ctest, Criterion, or another established C harness."
    ];
  };

  cplusplus = {
    title = "C++";
    detect = [ "*.cc" "*.cpp" "*.cxx" "*.hpp" "*.hh" "CMakeLists.txt" "meson.build" ];
    frameworks = [ "cmake" "meson" "catch2" "googletest" ];
    guidance = [
      "Target modern C++ (C++20 or C++23) unless the project says otherwise, and prefer RAII, standard library containers, and smart pointers over manual ownership patterns."
      "Use CMake or Meson for repeatable builds, keep warnings high, and enable sanitizers or static analysis in development configurations."
      "Favor clear value types, std::optional/std::variant/std::expected style APIs, and avoid deep inheritance trees unless the domain truly benefits from them."
      "Write focused unit tests with Catch2 or GoogleTest, and keep concurrency and memory lifetimes obvious in the design."
    ];
  };

  dotnet = {
    title = ".NET";
    detect = [ "*.csproj" "*.fsproj" "*.sln" "Directory.Build.props" ];
    frameworks = [ "dotnet" "asp.net core" "minimal api" "xunit" "nunit" ];
    guidance = [
      "Prefer current supported .NET releases, SDK-style project files, async-first APIs, and built-in dependency injection for service composition."
      "Keep boundaries explicit between web, application, domain, and infrastructure layers, and use records or small immutable types where they improve clarity."
      "Use ASP.NET Core conventions, structured logging, typed configuration, and robust cancellation-token handling for async work."
      "Cover behavior with xUnit, NUnit, or similar tools, and keep integration tests isolated with disposable infrastructure such as Testcontainers when needed."
    ];
  };

  elixir = {
    title = "Elixir";
    detect = [ "mix.exs" "config/config.exs" "lib/*.ex" "lib/*.exs" ];
    frameworks = [ "mix" "otp" "phoenix" "liveview" "exunit" ];
    guidance = [
      "Lean on OTP behaviours, supervision trees, and small pure functions, and keep GenServer processes focused on coordination rather than holding complex business logic."
      "Use Phoenix or LiveView idioms where present, and keep contexts, schemas, and external integrations separated cleanly."
      "Prefer explicit pattern matching, tagged tuples, and pipeline-friendly modules over mutable or overly object-like designs."
      "Test with ExUnit, async tasks where safe, and deterministic integration boundaries around external services."
    ];
  };

  erlang = {
    title = "Erlang";
    detect = [ "rebar.config" "src/*.erl" "apps/*/src/*.erl" ];
    frameworks = [ "rebar3" "otp" "common test" "eunit" ];
    guidance = [
      "Favor OTP behaviours, supervisors, and explicit process responsibilities, with clear message contracts between concurrent components."
      "Keep modules small, use records or maps intentionally, and design for crash isolation and restartability rather than defensive shared-state patterns."
      "Prefer rebar3 conventions and keep build, release, and test commands standard for the ecosystem."
      "Use Common Test or EUnit to cover message flows, failure handling, and distributed edge cases where they matter."
    ];
  };

  golang = {
    title = "Go";
    detect = [ "go.mod" "go.sum" "*.go" ];
    frameworks = [ "go toolchain" "net/http" "chi" "gin" "pgx" "sqlc" "testing" ];
    guidance = [
      "Follow standard Go project layout, keep packages cohesive, and prefer small interfaces owned by the consumer rather than large shared abstractions."
      "Thread context.Context through I/O boundaries, return explicit errors, and keep goroutine ownership and shutdown semantics easy to trace."
      "Prefer the standard library where it is sufficient, and use pgx or sqlc style data layers over heavy ORM patterns."
      "Use table-driven tests, focus on public behavior, and keep concurrency tests deterministic and race-safe."
    ];
  };

  java = {
    title = "Java";
    detect = [ "pom.xml" "build.gradle" "build.gradle.kts" "settings.gradle" "*.java" ];
    frameworks = [ "gradle" "maven" "spring boot" "micronaut" "quarkus" "junit 5" ];
    guidance = [
      "Target current LTS Java where possible, use Gradle or Maven conventions, and keep modules aligned with clear architectural boundaries."
      "Prefer immutable DTOs, records, and sealed types when they simplify domain modelling, and avoid unnecessary framework magic in core business logic."
      "Use dependency injection intentionally, keep persistence and transport code at the edges, and favour clear transactional boundaries."
      "Test with JUnit 5 and focused integration tests, using Testcontainers or equivalent tools when real infrastructure coverage matters."
    ];
  };

  python = {
    title = "Python";
    detect = [ "pyproject.toml" "requirements.txt" "uv.lock" "poetry.lock" "*.py" ];
    frameworks = [ "uv" "pytest" "fastapi" "pydantic" "django" "sqlalchemy" ];
    guidance = [
      "Prefer Python 3.12+ features when available, typed APIs, and pyproject.toml based configuration rather than legacy setup files."
      "Use uv or the existing project toolchain consistently, keep environments reproducible, and prefer FastAPI, Pydantic, or other explicit typed interfaces where appropriate."
      "Keep business logic separate from framework glue, avoid hidden global state, and use dependency injection or small factories for testability."
      "Test with pytest, cover async paths explicitly when present, and use ruff or equivalent linting and formatting tools when the project has them."
    ];
  };

  rust = {
    title = "Rust";
    detect = [ "Cargo.toml" "Cargo.lock" "rust-toolchain.toml" "*.rs" ];
    frameworks = [ "cargo" "tokio" "axum" "sqlx" "clippy" "rustfmt" ];
    guidance = [
      "Follow idiomatic Cargo layout, keep ownership and borrowing boundaries obvious, and model fallible operations with Result rather than hidden panics."
      "Prefer small traits or plain functions over premature abstraction, and use derives and newtypes to make invariants visible."
      "Run rustfmt and clippy as part of the normal workflow, and keep async boundaries, feature flags, and unsafe usage tightly scoped."
      "Test with cargo test, integration tests, and property-style checks where they buy confidence for parsing, transforms, or protocol logic."
    ];
  };

  scala = {
    title = "Scala";
    detect = [ "build.sbt" "project/build.properties" "*.scala" "mill-build" ];
    frameworks = [ "sbt" "mill" "zio" "cats effect" "munit" "scalatest" ];
    guidance = [
      "Prefer Scala 3 when the project allows it, keep algebraic data types explicit, and use effect systems such as ZIO or Cats Effect consistently when they are part of the stack."
      "Keep domain modelling and side-effecting integrations separate, and use small well-named modules over inheritance-heavy designs."
      "Follow the existing build tool conventions with sbt or mill, and avoid mixing incompatible dependency or effect patterns inside one feature."
      "Use MUnit or ScalaTest for focused tests, covering effectful logic with deterministic runtime control."
    ];
  };

  swift = {
    title = "Swift";
    detect = [ "Package.swift" "*.swift" "*.xcodeproj" "*.xcworkspace" ];
    frameworks = [ "swift package manager" "swiftui" "vapor" "xctest" ];
    guidance = [
      "Prefer current Swift language and package-manager features, protocol-oriented composition, and value types where they clarify ownership and state."
      "Use async/await and structured concurrency carefully, making actor or main-actor boundaries explicit when UI or shared mutable state is involved."
      "Keep SwiftUI, Vapor, or other framework-specific glue at the edges so domain logic stays testable and reusable."
      "Test with XCTest or Swift Testing, and keep networking, persistence, and time-dependent behavior injectable."
    ];
  };

  typescript = {
    title = "TypeScript";
    detect = [ "package.json" "tsconfig.json" "*.ts" "*.tsx" "deno.json" "bun.lockb" "pnpm-lock.yaml" ];
    frameworks = [ "node" "react" "next.js" "vite" "bun" "vitest" "playwright" "zod" ];
    guidance = [
      "Enable strict TypeScript when possible, keep runtime validation explicit with tools like Zod when inputs cross trust boundaries, and avoid using any unless the boundary is clearly isolated."
      "Follow the existing runtime choice consistently across Node, Bun, or Deno, and keep package-manager usage aligned with the lockfile already in the repo."
      "Separate UI, domain, and data-fetching concerns cleanly, and keep server and client code boundaries explicit in frameworks such as Next.js."
      "Use Vitest, Jest, Playwright, or the project standard for testing, and prefer small pure helpers and composable modules over large stateful classes."
    ];
  };

  zig = {
    title = "Zig";
    detect = [ "build.zig" "build.zig.zon" "*.zig" ];
    frameworks = [ "zig build" "std.testing" ];
    guidance = [
      "Follow standard Zig project structure, use the built-in build system, and make allocator ownership and error-union handling explicit in every API."
      "Prefer small composable functions, explicit data movement, and compile-time checks where they simplify correctness rather than obscuring intent."
      "Keep optional and error values obvious, and avoid introducing hidden allocation or lifetime behavior."
      "Test with std.testing and zig build test, keeping fixtures small and deterministic."
    ];
  };
}
