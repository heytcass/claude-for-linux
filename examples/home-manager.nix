# Example Home Manager configuration with Claude Cowork
# Add this to your home.nix or home-manager configuration

{ config, pkgs, ... }:

{
  # Import the Claude Cowork flake
  # (Assumes you've added it to your flake inputs)
  imports = [
    inputs.claude-cowork.homeManagerModules.default
  ];

  # Enable Claude Cowork
  programs.claude-cowork = {
    enable = true;
    installPatches = true;
    createDesktopEntry = true;  # Creates desktop launcher
  };

  # Optional: Create custom shell alias
  home.shellAliases = {
    claude = "claude-desktop-cowork";
  };

  # Optional: Add to session startup
  # systemd.user.services.claude-desktop = {
  #   Unit = {
  #     Description = "Claude Desktop with Cowork";
  #     After = [ "graphical-session.target" ];
  #   };
  #   Service = {
  #     ExecStart = "${pkgs.claude-desktop-cowork}/bin/claude-desktop-cowork";
  #     Restart = "on-failure";
  #   };
  #   Install.WantedBy = [ "graphical-session.target" ];
  # };
}
