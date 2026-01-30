# Example NixOS configuration with Claude Cowork
# Add this to your /etc/nixos/configuration.nix

{ config, pkgs, ... }:

{
  # Import the Claude Cowork flake
  # (Assumes you've added it to your flake inputs)
  imports = [
    inputs.claude-cowork.nixosModules.default
  ];

  # Enable Claude Cowork
  services.claude-cowork = {
    enable = true;
    autoInstall = true;  # Automatically patch on system activation
  };

  # Optional: Install Claude Desktop from Anthropic's deb package
  # This requires downloading the .deb manually and converting it
  environment.systemPackages = with pkgs; [
    # ... your other packages ...

    # If you've packaged Claude Desktop as a Nix package:
    # claude-desktop

    # Or use dpkg to install the .deb (not recommended for NixOS)
  ];
}
