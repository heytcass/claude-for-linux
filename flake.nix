{
  description = "Claude Desktop for Linux with Cowork support";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # Python script to handle ASAR operations
        asarTool = pkgs.writeScriptBin "asar-tool" ''
          #!${pkgs.python3}/bin/python3
          ${builtins.readFile ./scripts/asar_tool.py}
        '';

        # Cowork patches as derivations
        coworkPatches = pkgs.stdenv.mkDerivation {
          name = "claude-cowork-patches";
          src = ./scripts;

          buildInputs = [ pkgs.nodejs ];

          installPhase = ''
            mkdir -p $out/patches
            cp patch-cowork-linux-v3.js $out/patches/
            cp patch-cowork-v7-function.js $out/patches/
            cp patch-cowork-v8-intercept.js $out/patches/
            cp patch-cowork-v9-skip-download.js $out/patches/
            cp patch-cowork-v10-vi-function.js $out/patches/
            cp patch-cowork-v11-swift-module.js $out/patches/
          '';
        };

        # Cowork Linux module
        coworkModule = pkgs.stdenv.mkDerivation {
          name = "claude-cowork-linux-module";
          src = ./modules;

          installPhase = ''
            mkdir -p $out/node_modules/claude-cowork-linux
            cp claude-cowork-linux.js $out/node_modules/claude-cowork-linux/index.js
          '';
        };

        # Main installer script
        claudeCoworkInstaller = pkgs.writeShellApplication {
          name = "install-claude-cowork";

          runtimeInputs = with pkgs; [
            python3
            nodejs
            bubblewrap
            coreutils
            gnugrep
          ];

          text = ''
            set -e

            # Colors
            RED='\033[0;31m'
            GREEN='\033[0;32m'
            YELLOW='\033[1;33m'
            BLUE='\033[0;34m'
            NC='\033[0m'

            echo -e "''${BLUE}=== Claude Cowork Linux Installer (Nix) ===$NC"
            echo

            # Check if running as root
            if [ "$EUID" -eq 0 ]; then
              echo -e "''${RED}Error: Do not run this script with sudo$NC"
              exit 1
            fi

            # Locate Claude Desktop installation
            CLAUDE_DIR="/opt/claude-desktop"
            if [ ! -d "$CLAUDE_DIR" ]; then
              echo -e "''${RED}Error: Claude Desktop not found at $CLAUDE_DIR$NC"
              echo "Please install Claude Desktop first or set CLAUDE_DIR environment variable"
              exit 1
            fi

            echo -e "''${YELLOW}[1/7] Checking prerequisites...$NC"
            echo "  ✓ Bubblewrap: $(${pkgs.bubblewrap}/bin/bwrap --version | head -1)"
            echo "  ✓ Node.js: $(${pkgs.nodejs}/bin/node --version)"
            echo "  ✓ Python: $(${pkgs.python3}/bin/python3 --version)"
            echo

            echo -e "''${YELLOW}[2/7] Creating backup...$NC"
            if [ ! -f "$CLAUDE_DIR/app.asar.pre-cowork" ]; then
              sudo cp "$CLAUDE_DIR/app.asar" "$CLAUDE_DIR/app.asar.pre-cowork"
              echo "  ✓ Created pre-cowork backup"
            else
              echo "  ✓ Backup already exists"
            fi
            echo

            echo -e "''${YELLOW}[3/7] Extracting app.asar...$NC"
            EXTRACT_DIR="/tmp/claude-cowork-extract-$$"
            sudo rm -rf "$EXTRACT_DIR"
            mkdir -p "$EXTRACT_DIR"

            # Extract from backup to get clean slate
            ${asarTool}/bin/asar-tool extract \
              "$CLAUDE_DIR/app.asar.pre-cowork" \
              "$EXTRACT_DIR" > /dev/null 2>&1

            sudo chown -R "$USER:$USER" "$EXTRACT_DIR"
            echo "  ✓ Extracted to $EXTRACT_DIR"
            echo

            echo -e "''${YELLOW}[4/7] Installing Cowork module...$NC"
            mkdir -p "$EXTRACT_DIR/node_modules/claude-cowork-linux"
            cp -r ${coworkModule}/node_modules/claude-cowork-linux/* \
              "$EXTRACT_DIR/node_modules/claude-cowork-linux/"
            echo "  ✓ Module installed"
            echo

            echo -e "''${YELLOW}[5/7] Applying patches...$NC"
            for patch in ${coworkPatches}/patches/*.js; do
              patchname=$(basename "$patch")
              echo "  Applying $patchname..."
              ${pkgs.nodejs}/bin/node "$patch" "$EXTRACT_DIR" 2>&1 | grep -E "✅|Found|Applied" || true
            done
            echo "  ✓ All patches applied"
            echo

            echo -e "''${YELLOW}[6/7] Repacking app.asar...$NC"
            TIMESTAMP=$(date +%s)
            sudo mv "$CLAUDE_DIR/app.asar" "$CLAUDE_DIR/app.asar.backup-$TIMESTAMP"

            ${asarTool}/bin/asar-tool pack \
              "$EXTRACT_DIR" \
              "$EXTRACT_DIR.asar" > /dev/null 2>&1

            sudo mv "$EXTRACT_DIR.asar" "$CLAUDE_DIR/app.asar"
            echo "  ✓ Repacked (old backup: app.asar.backup-$TIMESTAMP)"
            echo

            echo -e "''${YELLOW}[7/7] Cleaning up...$NC"
            # Keep extraction dir for debugging
            echo "  ✓ Done (kept $EXTRACT_DIR for debugging)"
            echo

            echo -e "''${GREEN}✅ Installation complete!$NC"
            echo
            echo "Launch Claude Code and toggle Cowork on."
            echo "Watch for: '[Cowork Linux] Dispatching Ready status to UI'"
            echo
          '';
        };

        # Wrapper for Claude Desktop with proper environment
        claudeDesktopWrapper = pkgs.writeShellApplication {
          name = "claude-desktop-cowork";

          runtimeInputs = with pkgs; [
            bubblewrap
          ];

          text = ''
            # Ensure bubblewrap is in PATH
            export PATH="${pkgs.bubblewrap}/bin:$PATH"

            # Launch Claude Desktop
            if [ -f "/opt/claude-desktop/claude-desktop.sh" ]; then
              exec /opt/claude-desktop/claude-desktop.sh --no-sandbox "$@"
            elif [ -f "/opt/claude-desktop/claude" ]; then
              exec /opt/claude-desktop/claude --no-sandbox "$@"
            else
              echo "Error: Claude Desktop executable not found"
              exit 1
            fi
          '';
        };

        # Wrapper with auto-update check
        claudeDesktopAutoUpdate = pkgs.writeShellApplication {
          name = "claude-desktop-auto-update";

          runtimeInputs = with pkgs; [
            bubblewrap
            curl
            coreutils
            libnotify  # for notify-send
          ];

          text = ''
            ${builtins.readFile ./scripts/claude-wrapper-with-update.sh}
          '';
        };

      in
      {
        packages = {
          default = claudeCoworkInstaller;
          installer = claudeCoworkInstaller;
          wrapper = claudeDesktopWrapper;
          wrapper-auto-update = claudeDesktopAutoUpdate;
          patches = coworkPatches;
          module = coworkModule;
          asar-tool = asarTool;
        };

        apps = {
          default = {
            type = "app";
            program = "${claudeCoworkInstaller}/bin/install-claude-cowork";
          };
          install = {
            type = "app";
            program = "${claudeCoworkInstaller}/bin/install-claude-cowork";
          };
          run = {
            type = "app";
            program = "${claudeDesktopWrapper}/bin/claude-desktop-cowork";
          };
          run-auto-update = {
            type = "app";
            program = "${claudeDesktopAutoUpdate}/bin/claude-desktop-auto-update";
          };
        };

        # Development shell with all tools
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nodejs
            python3
            bubblewrap

            # Development tools
            nodePackages.prettier
            nodePackages.eslint

            # For testing
            gnugrep
            coreutils
          ];

          shellHook = ''
            echo "🚀 Claude Cowork Linux Development Shell"
            echo ""
            echo "Available commands:"
            echo "  - node: $(node --version)"
            echo "  - python3: $(python3 --version)"
            echo "  - bwrap: $(bwrap --version | head -1)"
            echo ""
            echo "Try: nix run . -- to install patches"
            echo "     nix run .#run -- to launch Claude Desktop"
          '';
        };

        # NixOS module for system-wide installation
        nixosModules.default = { config, lib, pkgs, ... }:
          with lib;
          let
            cfg = config.services.claude-cowork;
          in
          {
            options.services.claude-cowork = {
              enable = mkEnableOption "Claude Desktop with Cowork support";

              package = mkOption {
                type = types.package;
                default = self.packages.${system}.installer;
                description = "Claude Cowork installer package";
              };

              autoInstall = mkOption {
                type = types.bool;
                default = false;
                description = "Automatically install patches on system activation";
              };
            };

            config = mkIf cfg.enable {
              # Ensure bubblewrap is available
              environment.systemPackages = with pkgs; [
                bubblewrap
                cfg.package
              ];

              # Optionally auto-install patches
              system.activationScripts.claude-cowork = mkIf cfg.autoInstall (
                stringAfter [ "etc" ] ''
                  if [ -d "/opt/claude-desktop" ]; then
                    echo "Installing Claude Cowork patches..."
                    ${cfg.package}/bin/install-claude-cowork || true
                  fi
                ''
              );
            };
          };

        # Home Manager module for user-level installation
        homeManagerModules.default = { config, lib, pkgs, ... }:
          with lib;
          let
            cfg = config.programs.claude-cowork;
          in
          {
            options.programs.claude-cowork = {
              enable = mkEnableOption "Claude Desktop with Cowork support";

              installPatches = mkOption {
                type = types.bool;
                default = true;
                description = "Install Cowork patches to Claude Desktop";
              };

              createDesktopEntry = mkOption {
                type = types.bool;
                default = true;
                description = "Create desktop entry for Claude with Cowork";
              };
            };

            config = mkIf cfg.enable {
              home.packages = with pkgs; [
                bubblewrap
                self.packages.${system}.wrapper
              ];

              # Desktop entry
              xdg.desktopEntries.claude-cowork = mkIf cfg.createDesktopEntry {
                name = "Claude (Cowork)";
                genericName = "AI Assistant with Cowork";
                exec = "${self.packages.${system}.wrapper}/bin/claude-desktop-cowork";
                icon = "claude";
                categories = [ "Development" "Utility" ];
                comment = "Claude Desktop with Linux Cowork support";
              };

              # Installation activation
              home.activation.claude-cowork = mkIf cfg.installPatches (
                lib.hm.dag.entryAfter [ "writeBoundary" ] ''
                  if [ -d "/opt/claude-desktop" ]; then
                    $DRY_RUN_CMD ${self.packages.${system}.installer}/bin/install-claude-cowork || true
                  fi
                ''
              );
            };
          };
      }
    );
}
