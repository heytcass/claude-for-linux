# Example flake.nix that uses claude-cowork
# This shows how to integrate Claude Cowork into your system flake

{
  description = "My NixOS configuration with Claude Cowork";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Add Claude Cowork flake
    claude-cowork = {
      url = "github:yourusername/claude-for-linux";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # If using Home Manager
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, claude-cowork, home-manager, ... }@inputs: {
    # NixOS configuration
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        ./hardware-configuration.nix

        # Import Claude Cowork module
        claude-cowork.nixosModules.default

        # Your configuration
        {
          services.claude-cowork = {
            enable = true;
            autoInstall = true;
          };
        }
      ];
    };

    # Home Manager configuration
    homeConfigurations.myuser = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      extraSpecialArgs = { inherit inputs; };
      modules = [
        # Import Claude Cowork Home Manager module
        claude-cowork.homeManagerModules.default

        # Your configuration
        {
          programs.claude-cowork = {
            enable = true;
            installPatches = true;
            createDesktopEntry = true;
          };
        }
      ];
    };
  };
}
