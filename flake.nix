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

  outputs = inputs@{ self, nixpkgs, home-manager, ... }:
    let
      inherit (nixpkgs) lib;

      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];

      forAllSystems = lib.genAttrs systems;

      mkPkgs = system:
        import nixpkgs {
          inherit system;
        };

      helpers = import ./nix/lib.nix { inherit lib; };

      homeManagerModule = import ./nix/modules/home-manager.nix {
        inherit self;
      };

      nixosModule = import ./nix/modules/nixos.nix {
        inherit self;
      };

      mkComputerUsePackage = pkgs:
        pkgs.callPackage ./nix/packages/computer-use-mcp.nix { };

      mkBundledSkillsPackage = pkgs:
        pkgs.callPackage ./nix/packages/opencode-skills.nix { };

      mkDefaultPackage = pkgs:
        let
          computerUsePackage = mkComputerUsePackage pkgs;
          bundledSkillsPackage = mkBundledSkillsPackage pkgs;
        in
        helpers.mkOpencodePackage {
          inherit pkgs computerUsePackage bundledSkillsPackage;
          enableComputerUse = pkgs.stdenv.isDarwin || pkgs.stdenv.isLinux;
          wrapperName = "opencode";
        };

      mkHomeManagerCheck = pkgs:
        let
          homeDirectory =
            if pkgs.stdenv.isDarwin then
              "/Users/opencode"
            else
              "/home/opencode";

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

      mkNixosCheck = pkgs:
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
          bundledSkillsPackage = mkBundledSkillsPackage pkgs;
          defaultPackage = mkDefaultPackage pkgs;
        in
        {
          default = defaultPackage;
          opencode = pkgs.opencode;
          computer-use-mcp = computerUsePackage;
          opencode-skills = bundledSkillsPackage;
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
              pkgs.opencode
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
        in
        {
          default = self.packages.${system}.default;
          computer-use-mcp = self.packages.${system}.computer-use-mcp;
          opencode-skills = self.packages.${system}.opencode-skills;
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
