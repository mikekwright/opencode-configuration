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

      mkOpenPencilMcpPackage = pkgs: pkgs.callPackage ./nix/packages/open-pencil-mcp.nix { };

      mkBundledSkillsPackage = pkgs: pkgs.callPackage ./nix/packages/opencode-skills.nix { };

      mkOpenPencilSkillPackage = pkgs: pkgs.callPackage ./nix/packages/open-pencil-skill.nix { };

      mkOpenPencilRoot = pkgs:
        if pkgs.stdenv.isDarwin then
          "/Users/mikewright/Development/designs"
        else
          "/home/mikewright/Development/designs";

      mkDefaultPackage =
        pkgs:
        let
          computerUsePackage = mkComputerUsePackage pkgs;
          openPencilMcpPackage = mkOpenPencilMcpPackage pkgs;
          bundledSkillsPackage = mkBundledSkillsPackage pkgs;
          openPencilSkillPackage = mkOpenPencilSkillPackage pkgs;
          openPencilRoot = mkOpenPencilRoot pkgs;
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
              package = openPencilMcpPackage;
              root = openPencilRoot;
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
          computerUsePackage = mkComputerUsePackage pkgs;
          openPencilMcpPackage = mkOpenPencilMcpPackage pkgs;
          bundledSkillsPackage = mkBundledSkillsPackage pkgs;
          openPencilSkillPackage = mkOpenPencilSkillPackage pkgs;
          defaultPackage = mkDefaultPackage pkgs;
        in
        {
          default = defaultPackage;
          opencode = defaultPackage;
          computer-use-mcp = computerUsePackage;
          open-pencil-mcp = openPencilMcpPackage;
          opencode-skills = bundledSkillsPackage;
          open-pencil-skill = openPencilSkillPackage;
        }
      );

      apps = forAllSystems (
        system:
        let
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
              self.packages.${system}.open-pencil-mcp
            ];
          };
        }
      );

      checks = forAllSystems (
        system:
        let
          pkgs = mkPkgs system;
        in
        {
          default = self.packages.${system}.default;
          computer-use-mcp = self.packages.${system}.computer-use-mcp;
          open-pencil-mcp = self.packages.${system}.open-pencil-mcp;
          opencode-skills = self.packages.${system}.opencode-skills;
          open-pencil-skill = self.packages.${system}.open-pencil-skill;
          home-manager = mkHomeManagerCheck pkgs;
        }
        // lib.optionalAttrs pkgs.stdenv.isLinux {
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
