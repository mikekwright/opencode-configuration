{
  description = "Run opencode with declarative MCP and service modules";

  inputs = {
    # Opencode 15.3 (May 18th, 2026)
    nixpkgs.url = "github:NixOS/nixpkgs/d8a466512a138669b018648da28062bbf3ef1ea4";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      ...
    }:
    let
      inherit (nixpkgs) lib;

      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];

      forAllSystems = lib.genAttrs systems;

      mkPkgs =
        system:
        import nixpkgs {
          inherit system;
        };

      mkOpencodePackage = import ./nix/opencode.nix { inherit lib; };

      homeManagerModule = import ./nix/modules/home-manager.nix {
        inherit self;
      };

      nixosModule = import ./nix/modules/nixos.nix {
        inherit self;
      };

      mkComputerUsePackage = pkgs: pkgs.callPackage ./nix/packages/computer-use-mcp.nix { };

      mkRangoExtensionPackage = pkgs: pkgs.callPackage ./nix/packages/rango-extension.nix { };

      mkChromiumWithRangoPackage =
        pkgs:
        pkgs.callPackage ./nix/packages/chromium-with-rango.nix {
          rango-extension = mkRangoExtensionPackage pkgs;
        };

      mkBundledSkillsPackage = pkgs: pkgs.callPackage ./nix/packages/opencode-skills.nix { };

      mkOpenPencilSkillPackage = pkgs: pkgs.callPackage ./nix/packages/open-pencil-skill.nix { };

      mkCodeServerSupported = pkgs: lib.meta.availableOn pkgs.stdenv.hostPlatform pkgs.code-server;

      mkDefaultPackage =
        pkgs:
        let
          computerUsePackage = mkComputerUsePackage pkgs;
          bundledSkillsPackage = mkBundledSkillsPackage pkgs;
          openPencilSkillPackage = mkOpenPencilSkillPackage pkgs;
        in
        mkOpencodePackage {
          inherit pkgs;
          opencodePackage = pkgs.opencode;
          mcp = {
            enable = true;
            computerUse = {
              enable = pkgs.stdenv.isDarwin || pkgs.stdenv.isLinux;
              package = computerUsePackage;
            };
            openPencil = {
              enable = true;
              url = "http://127.0.0.1:3100/mcp";
            };
          };
          skills = {
            enable = true;
            package = bundledSkillsPackage;
            openPencil = {
              enable = true;
              package = openPencilSkillPackage;
            };
          };
          wrapperName = "opencode";
        };

      mkHomeManagerCheck =
        pkgs:
        let
          homeDirectory = if pkgs.stdenv.isDarwin then "/Users/opencode" else "/home/opencode";

          hmConfig = home-manager.lib.homeManagerConfiguration {
            inherit pkgs;
            modules = [
              homeManagerModule
              {
                home.username = "opencode";
                home.homeDirectory = homeDirectory;
                home.stateVersion = "24.11";

                services.opencode = {
                  enable = true;
                  web.enable = true;
                };
              }
            ];
          };
        in
        hmConfig.activationPackage;

      mkNixosCheck =
        pkgs:
        let
          nixosConfig = lib.nixosSystem {
            system = pkgs.stdenv.hostPlatform.system;
            modules = [
              nixosModule
              {
                system.stateVersion = "24.11";
                services.opencode.enable = true;
              }
            ];
          };
        in
        nixosConfig.config.system.build.toplevel;
    in
    {
      formatter = forAllSystems (system: (mkPkgs system).nixfmt);

      packages = forAllSystems (
        system:
        let
          pkgs = mkPkgs system;
          codeServerSupported = mkCodeServerSupported pkgs;
          computerUsePackage = mkComputerUsePackage pkgs;
          rangoExtensionPackage = mkRangoExtensionPackage pkgs;
          chromiumWithRangoPackage = if pkgs.stdenv.isLinux then mkChromiumWithRangoPackage pkgs else null;
          bundledSkillsPackage = mkBundledSkillsPackage pkgs;
          openPencilSkillPackage = mkOpenPencilSkillPackage pkgs;
          defaultPackage = mkDefaultPackage pkgs;
        in
        {
          default = defaultPackage;
          opencode = defaultPackage;
          computer-use-mcp = computerUsePackage;
          rango-extension = rangoExtensionPackage;
          opencode-skills = bundledSkillsPackage;
          open-pencil-skill = openPencilSkillPackage;
        }
        // lib.optionalAttrs codeServerSupported {
          code-server = pkgs.code-server;
        }
        // lib.optionalAttrs pkgs.stdenv.isLinux {
          chromium-with-rango = chromiumWithRangoPackage;
        }
      );

      apps = forAllSystems (
        system:
        let
          pkgs = mkPkgs system;
          codeServerSupported = mkCodeServerSupported pkgs;
          program = "${self.packages.${system}.default}/bin/opencode";
        in
        {
          default = {
            type = "app";
            inherit program;
            meta.description = "Run the wrapped opencode CLI";
          };

          opencode = {
            type = "app";
            inherit program;
            meta.description = "Run the wrapped opencode CLI";
          };
        }
        // lib.optionalAttrs codeServerSupported {
          code-server = {
            type = "app";
            program = lib.getExe self.packages.${system}.code-server;
            meta.description = "Run code-server";
          };
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = mkPkgs system;
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.deadnix
              pkgs.nixfmt
              pkgs.nodejs
              self.packages.${system}.opencode
              pkgs.statix
              self.packages.${system}.computer-use-mcp
            ];
          };
        }
      );

      checks = forAllSystems (
        system:
        let
          pkgs = mkPkgs system;
          codeServerSupported = mkCodeServerSupported pkgs;
        in
        {
          default = self.packages.${system}.default;
          computer-use-mcp = self.packages.${system}.computer-use-mcp;
          rango-extension = self.packages.${system}.rango-extension;
          opencode-skills = self.packages.${system}.opencode-skills;
          open-pencil-skill = self.packages.${system}.open-pencil-skill;
          home-manager = mkHomeManagerCheck pkgs;
        }
        // lib.optionalAttrs codeServerSupported {
          code-server = self.packages.${system}.code-server;
        }
        // lib.optionalAttrs pkgs.stdenv.isLinux {
          chromium-with-rango = self.packages.${system}.chromium-with-rango;
          nixos = mkNixosCheck pkgs;
        }
      );

      homeManagerModules = {
        default = homeManagerModule;
        opencode = homeManagerModule;
      };

      nixosModules = {
        default = nixosModule;
        opencode = nixosModule;
      };
    };
}
