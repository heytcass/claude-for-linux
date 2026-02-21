{
  description = "Claude Desktop for Linux - fully declarative NixOS package with Cowork support";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      # Claude Desktop version and source
      claudeVersion = "1.1.3918";
      claudeDmgHash = "sha256-u3FShy6BW3LpLW657VZTeBfbr5Qj23qSQscQY2cOGxk=";
      claudeDmgUrl = "https://downloads.claude.ai/releases/darwin/universal/${claudeVersion}/Claude-a4b368d308b05c425b74c1c19ed47a572d3a90f6.dmg";

      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];

      forEachSystem = f: builtins.listToAttrs (map (system: {
        name = system;
        value = f system;
      }) supportedSystems);

    in {
      packages = forEachSystem (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};

          # Fetch macOS DMG
          claudeSrc = pkgs.fetchurl {
            url = claudeDmgUrl;
            hash = claudeDmgHash;
          };

          # Python ASAR tool
          asarTool = pkgs.writeScriptBin "asar-tool" ''
            #!${pkgs.python3}/bin/python3
            ${builtins.readFile ./tools/asar_tool.py}
          '';

          # Extract app.asar from DMG and apply patches
          claudeApp = pkgs.stdenv.mkDerivation {
            pname = "claude-desktop-app";
            version = claudeVersion;

            src = claudeSrc;

            nativeBuildInputs = with pkgs; [
              dmg2img
              p7zip
              python3
              nodejs
              perl
            ];

            dontUnpack = true;

            buildPhase = ''
              runHook preBuild

              echo "=== Extracting Claude Desktop ${claudeVersion} ==="

              # Convert DMG to IMG
              echo "[1/6] Converting DMG to IMG..."
              dmg2img $src claude.img

              # Extract with 7z
              echo "[2/6] Extracting IMG..."
              mkdir -p dmg-contents
              7z x -y -odmg-contents claude.img > /dev/null 2>&1 || true

              # Find app.asar
              echo "[3/6] Locating app.asar..."
              APP_ASAR=$(find dmg-contents -name "app.asar" -path "*/Contents/Resources/*" | head -1)
              if [ -z "$APP_ASAR" ]; then
                echo "ERROR: app.asar not found in DMG"
                find dmg-contents -name "*.asar" || true
                exit 1
              fi
              echo "  Found: $APP_ASAR"

              # Also grab app.asar.unpacked if it exists
              APP_UNPACKED="$(dirname "$APP_ASAR")/app.asar.unpacked"

              # Locate the Resources directory (contains i18n, icons, etc.)
              RESOURCES_DIR="$(dirname "$APP_ASAR")"
              echo "  Resources dir: $RESOURCES_DIR"

              # Extract ASAR
              echo "[4/6] Extracting ASAR..."
              mkdir -p extracted
              ${asarTool}/bin/asar-tool extract "$APP_ASAR" extracted

              # Copy i18n resources into ASAR tree
              # The app looks for resources/i18n/*.json relative to the ASAR root
              echo "  Copying i18n resources..."
              mkdir -p extracted/resources/i18n
              for json in "$RESOURCES_DIR"/*.json; do
                if [ -f "$json" ]; then
                  cp "$json" extracted/resources/i18n/
                fi
              done
              echo "  Copied $(ls extracted/resources/i18n/*.json 2>/dev/null | wc -l) i18n files"

              # Copy tray icons directly into resources/ (not resources/icons/)
              # The app resolves icon paths via path.resolve(__dirname, "../..", "resources")
              echo "  Copying tray icons..."
              for icon in "$RESOURCES_DIR"/TrayIcon*.png "$RESOURCES_DIR"/Tray-Win32*.ico "$RESOURCES_DIR"/EchoTray*.png; do
                if [ -f "$icon" ]; then
                  cp "$icon" extracted/resources/
                fi
              done
              echo "  Copied $(ls extracted/resources/TrayIcon* extracted/resources/EchoTray* extracted/resources/Tray-Win32* 2>/dev/null | wc -l) tray icons"

              # Extract app icon from ICNS for notification icon and desktop entry
              echo "  Extracting app icons from ICNS..."
              ICNS_FILE="$RESOURCES_DIR/electron.icns"
              if [ -f "$ICNS_FILE" ]; then
                mkdir -p icon-extracted
                ${pkgs.python3}/bin/python3 ${./tools/icns_extract.py} "$ICNS_FILE" icon-extracted
                # Place 256px icon in ASAR resources as icon.png (used for notifications)
                if [ -f icon-extracted/256.png ]; then
                  cp icon-extracted/256.png extracted/resources/icon.png
                  echo "  Installed icon.png (256x256) for notifications"
                elif [ -f icon-extracted/512.png ]; then
                  cp icon-extracted/512.png extracted/resources/icon.png
                  echo "  Installed icon.png (512x512) for notifications"
                fi
              else
                echo "  WARNING: electron.icns not found, skipping app icon extraction"
              fi

              # Apply patches (version-resilient regex + dynamic discovery)
              echo "[5/6] Applying patches..."

              INDEX="extracted/.vite/build/index.js"
              MAINVIEW="extracted/.vite/build/mainView.js"

              # --- Patch 00: Native module stub ---
              echo "[patch:00] Installing native module stub..."
              mkdir -p extracted/node_modules/@ant/claude-native
              cp ${./modules/enhanced-claude-native-stub.js} extracted/node_modules/@ant/claude-native/index.js
              cat > extracted/node_modules/@ant/claude-native/package.json <<STUBPKG
              {"name":"@ant/claude-native","version":"1.0.0-linux-stub","main":"index.js"}
              STUBPKG
              echo "[patch:00] Done"

              # --- Patch 01: Cowork module loader ---
              echo "[patch:01] Installing cowork module..."
              mkdir -p extracted/node_modules/claude-cowork-linux
              cp ${./modules/claude-cowork-linux.js} extracted/node_modules/claude-cowork-linux/index.js
              cat > extracted/node_modules/claude-cowork-linux/package.json <<COWORKPKG
              {"name":"claude-cowork-linux","version":"2.0.0","main":"index.js"}
              COWORKPKG
              cat ${./scripts/cowork-init.js} >> "$INDEX"
              echo "[patch:01] Done"

              # --- Patch 02: Platform flag (regex) ---
              # Makes the Windows platform flag also true on Linux, routing through TS VM path
              echo "[patch:02] Patching platform flag..."
              perl -i -pe 's{(\w+=process\.platform==="darwin",)(\w+)(=process\.platform==="win32")}{$1$2$3||process.platform==="linux"}g' "$INDEX"
              grep -qP '\w+=process\.platform==="win32"\|\|process\.platform==="linux"' "$INDEX" \
                || { echo "ERROR: patch 02 (platform flag) failed to apply"; exit 1; }
              echo "[patch:02] Done"

              # --- Patch 03: Availability check (regex) ---
              # Prepends Linux "supported" return before the platform check
              echo "[patch:03] Patching availability check..."
              perl -i -pe 's{(function )(\w+)(\(\)\{)(const t=process\.platform;if\(t!=="darwin"&&t!=="win32"\)return\{status:"unsupported")}{$1$2$3if(process.platform==="linux"\&\&global.__linuxCowork)return\{status:"supported"\};$4}g' "$INDEX"
              grep -qP 'if\(process\.platform==="linux"&&global\.__linuxCowork\)return\{status:"supported"\}' "$INDEX" \
                || { echo "ERROR: patch 03 (availability check) failed to apply"; exit 1; }
              echo "[patch:03] Done"

              # --- Patch 04: Skip download (regex) ---
              # Skips macOS VM bundle download on Linux
              echo "[patch:04] Patching download skip..."
              perl -i -pe 's{(async function \w+\(t,e\)\{)(.{0,200}?\[downloadVM\])}{$1if(process.platform==="linux"\&\&global.__linuxCowork){console.log("[Cowork Linux] Skipping bundle download");return!1}$2}g' "$INDEX"
              grep -qP 'async function \w+\(t,e\)\{if\(process\.platform==="linux"' "$INDEX" \
                || { echo "ERROR: patch 04 (skip download) failed to apply"; exit 1; }
              echo "[patch:04] Done"

              # --- Patch 05: VM start intercept (dynamic Node.js) ---
              # Discovers function name via [VM:start] log string, injects bubblewrap session
              echo "[patch:05] Patching VM start intercept..."
              ${pkgs.nodejs}/bin/node ${./scripts/patch-vm-start.js} extracted
              echo "[patch:05] Done"

              # --- Patch 06a: VM getter (regex) ---
              # Returns Linux VM instance from getter function
              echo "[patch:06a] Patching VM getter..."
              perl -i -pe 's{(async function )(\w+)(\(\)\{)(const \w+=await \w+\(\);return\(\w+==null\?void 0:\w+\.vm\)\?\?null)}{$1$2$3if(process.platform==="linux"\&\&global.__linuxCowork\&\&global.__linuxCowork.vmInstance){console.log("[Cowork Linux] $2() returning Linux VM");return global.__linuxCowork.vmInstance}$4}g' "$INDEX"
              grep -qP '\[Cowork Linux\] \w+\(\) returning Linux VM' "$INDEX" \
                || { echo "ERROR: patch 06a (VM getter) failed to apply"; exit 1; }
              echo "[patch:06a] Done"

              # --- Patch 06b: Platform getter (regex) ---
              # Don't return null for Linux in platform-gated getter
              echo "[patch:06b] Patching platform getter..."
              perl -i -pe 's{(async function \w+\(\)\{return )process\.platform!=="darwin"\?null(:await \w+\(\))}{''${1}process.platform!=="darwin"\&\&process.platform!=="linux"?null''${2}}g' "$INDEX"
              grep -qP 'process\.platform!=="darwin"&&process\.platform!=="linux"\?null' "$INDEX" \
                || { echo "ERROR: patch 06b (platform getter) failed to apply"; exit 1; }
              echo "[patch:06b] Done"

              # --- Patch 07: Platform branding ---
              echo "[patch:07] Injecting platform branding fix..."
              cat ${./scripts/branding-fix.js} >> "$MAINVIEW"
              echo "[patch:07] Done"

              # --- Patch 08a: Tray icon resource path (regex) ---
              # Returns real filesystem path on Linux (COSMIC SNI can't read from ASAR)
              echo "[patch:08a] Patching tray icon resource path..."
              perl -i -pe 's{function (\w+)\(\)\{return (\w+)\.app\.isPackaged\?(\w+)\.resourcesPath:(\w+)\.resolve\(__dirname,"\.\.","\.\.","resources"\)\}}{function $1(){return process.platform==="linux"?$4.join($4.dirname($2.app.getAppPath()),"resources"):$2.app.isPackaged?$3.resourcesPath:$4.resolve(__dirname,"..","..","resources")}}g' "$INDEX"
              grep -qP 'process\.platform==="linux"\?\w+\.join\(\w+\.dirname\(' "$INDEX" \
                || { echo "ERROR: patch 08a (tray icon path) failed to apply"; exit 1; }
              echo "[patch:08a] Done"

              # --- Patch 08b: Tray icon filename (regex) ---
              # Linux uses theme-aware PNGs instead of Windows ICOs
              echo "[patch:08b] Patching tray icon filename selection..."
              perl -i -pe 's{(\w+)\?(\w+)=(\w+)\.nativeTheme\.shouldUseDarkColors\?"Tray-Win32-Dark\.ico":"Tray-Win32\.ico":(\w+)="TrayIconTemplate\.png"}{process.platform==="linux"?($2=$3.nativeTheme.shouldUseDarkColors?"TrayIconTemplate-Dark.png":"TrayIconTemplate.png"):$1?$2=$3.nativeTheme.shouldUseDarkColors?"Tray-Win32-Dark.ico":"Tray-Win32.ico":$4="TrayIconTemplate.png"}g' "$INDEX"
              grep -qP 'process\.platform==="linux"\?\(' "$INDEX" \
                || { echo "ERROR: patch 08b (tray icon filename) failed to apply"; exit 1; }
              echo "[patch:08b] Done"

              # --- Patch 09: DBus tray cleanup delay (regex) ---
              # Prevents StatusNotifierItem registration race on Linux
              echo "[patch:09] Patching tray DBus cleanup delay..."
              perl -i -pe 's{(\w+)&&\(\1\.destroy\(\),\1=null\)}{$1&&($1.destroy(),$1=null,await new Promise(r=>setTimeout(r,250)))}g' "$INDEX"
              echo "[patch:09] Done"

              # Repack ASAR
              echo "[6/6] Repacking ASAR..."
              ${asarTool}/bin/asar-tool pack extracted app.asar

              echo "=== Build complete ==="

              runHook postBuild
            '';

            installPhase = ''
              runHook preInstall

              mkdir -p $out/lib/claude-desktop
              cp app.asar $out/lib/claude-desktop/

              # Copy unpacked resources if they exist
              if [ -d "$(dirname $(find dmg-contents -name 'app.asar' -path '*/Contents/Resources/*' | head -1))/app.asar.unpacked" ]; then
                cp -r "$(dirname $(find dmg-contents -name 'app.asar' -path '*/Contents/Resources/*' | head -1))/app.asar.unpacked" \
                  $out/lib/claude-desktop/app.asar.unpacked
              fi

              # Copy tray icons and app icon to real filesystem (alongside ASAR)
              # COSMIC's SNI can't read from inside ASAR archives, so these must
              # be on the real filesystem for the tray icon to display correctly.
              mkdir -p $out/lib/claude-desktop/resources
              for icon in extracted/resources/TrayIconTemplate*.png extracted/resources/icon.png; do
                if [ -f "$icon" ]; then
                  cp "$icon" $out/lib/claude-desktop/resources/
                fi
              done

              # Install hicolor theme icons for desktop entry
              if [ -d icon-extracted ]; then
                for png in icon-extracted/*.png; do
                  size=$(basename "$png" .png)
                  if [ "$size" -gt 0 ] 2>/dev/null; then
                    mkdir -p "$out/share/icons/hicolor/''${size}x''${size}/apps"
                    cp "$png" "$out/share/icons/hicolor/''${size}x''${size}/apps/claude.png"
                    echo "  Installed ''${size}x''${size} icon"
                  fi
                done
              fi

              runHook postInstall
            '';
          };

          # Basic Claude Desktop wrapper (direct electron)
          claudeDesktop = pkgs.symlinkJoin {
            name = "claude-desktop-${claudeVersion}";
            paths = [ claudeApp ];
            nativeBuildInputs = [ pkgs.makeWrapper ];
            postBuild = ''
              mkdir -p $out/bin
              makeWrapper ${pkgs.electron_37}/bin/electron $out/bin/claude-desktop \
                --add-flags "$out/lib/claude-desktop/app.asar" \
                --add-flags "--no-sandbox" \
                --add-flags "--ozone-platform-hint=auto" \
                --add-flags "--class=Claude" \
                --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.bubblewrap ]} \
                --set BWRAP_PATH "${pkgs.bubblewrap}/bin/bwrap" \
                --set CHROME_DESKTOP "claude-desktop.desktop" \
                --prefix XDG_DATA_DIRS : "$out/share"

              # Desktop entry
              mkdir -p $out/share/applications
              cat > $out/share/applications/claude-desktop.desktop <<DESKTOP
              [Desktop Entry]
              Name=Claude
              Comment=Claude AI Assistant
              Exec=$out/bin/claude-desktop %U
              Icon=claude
              Type=Application
              Categories=Development;Utility;
              MimeType=x-scheme-handler/claude;
              StartupWMClass=Claude
              DESKTOP
              sed -i 's/^              //' $out/share/applications/claude-desktop.desktop
            '';
            meta = with pkgs.lib; {
              description = "Claude Desktop for Linux with Cowork support";
              homepage = "https://claude.ai";
              platforms = platforms.linux;
              mainProgram = "claude-desktop";
            };
          };

          # FHS wrapper for maximum compatibility (cowork + MCP)
          claudeDesktopFHS = pkgs.buildFHSEnv {
            name = "claude-desktop";
            targetPkgs = pkgs: with pkgs; [
              bubblewrap
              nodejs
              python3
              glibc
              openssl
              docker-client
              coreutils
              bash
              gnugrep
              gnused
              gawk
              findutils
              git
              curl
              wget
            ];
            runScript = "${claudeDesktop}/bin/claude-desktop";
            meta = with pkgs.lib; {
              description = "Claude Desktop for Linux (FHS) with Cowork and MCP support";
              homepage = "https://claude.ai";
              platforms = platforms.linux;
              mainProgram = "claude-desktop";
            };
          };

        in {
          default = claudeDesktop;
          claude-desktop = claudeDesktop;
          claude-desktop-fhs = claudeDesktopFHS;
          claude-app = claudeApp;
          asar-tool = asarTool;
        }
      );

      apps = forEachSystem (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/claude-desktop";
        };
        claude-desktop = {
          type = "app";
          program = "${self.packages.${system}.claude-desktop}/bin/claude-desktop";
        };
        claude-desktop-fhs = {
          type = "app";
          program = "${self.packages.${system}.claude-desktop-fhs}/bin/claude-desktop";
        };
      });

      # NixOS module
      nixosModules.default = { config, lib, pkgs, ... }:
        let
          cfg = config.programs.claude-desktop;
        in {
          options.programs.claude-desktop = {
            enable = lib.mkEnableOption "Claude Desktop with Cowork support";

            package = lib.mkOption {
              type = lib.types.package;
              default = self.packages.${pkgs.system}.claude-desktop;
              defaultText = lib.literalExpression "claude-for-linux.packages.\${system}.claude-desktop";
              description = "The Claude Desktop package to use.";
            };

            fhs = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Use FHS wrapper for better MCP and Cowork compatibility.";
            };
          };

          config = lib.mkIf cfg.enable {
            environment.systemPackages = [
              (if cfg.fhs
               then self.packages.${pkgs.system}.claude-desktop-fhs
               else cfg.package)
              pkgs.bubblewrap
            ];
          };
        };

      # Home Manager module
      homeManagerModules.default = { config, lib, pkgs, ... }:
        let
          cfg = config.programs.claude-desktop;
          pkg = if cfg.fhs
                then self.packages.${pkgs.system}.claude-desktop-fhs
                else cfg.package;
        in {
          options.programs.claude-desktop = {
            enable = lib.mkEnableOption "Claude Desktop with Cowork support";

            package = lib.mkOption {
              type = lib.types.package;
              default = self.packages.${pkgs.system}.claude-desktop;
              defaultText = lib.literalExpression "claude-for-linux.packages.\${system}.claude-desktop";
              description = "The Claude Desktop package to use.";
            };

            fhs = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Use FHS wrapper for better MCP and Cowork compatibility.";
            };

            createDesktopEntry = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Create desktop entry for Claude Desktop.";
            };
          };

          config = lib.mkIf cfg.enable {
            home.packages = [ pkg pkgs.bubblewrap ];

            xdg.desktopEntries.claude-desktop = lib.mkIf cfg.createDesktopEntry {
              name = "Claude";
              genericName = "AI Assistant";
              exec = "${pkg}/bin/claude-desktop %U";
              icon = "claude";
              categories = [ "Development" "Utility" ];
              comment = "Claude Desktop with Linux Cowork support";
              mimeType = [ "x-scheme-handler/claude" ];
              settings = {
                StartupWMClass = "Claude";
              };
            };
          };
        };

      # Development shell
      devShells = forEachSystem (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in {
          default = pkgs.mkShell {
            buildInputs = with pkgs; [
              nodejs
              python3
              bubblewrap
              electron_37
              dmg2img
              p7zip

              # Development tools
              nodePackages.prettier
            ];

            shellHook = ''
              echo "Claude Desktop Linux Development Shell"
              echo ""
              echo "  node:     $(node --version)"
              echo "  python3:  $(python3 --version 2>&1)"
              echo "  bwrap:    $(bwrap --version 2>&1 | head -1)"
              echo "  electron: $(electron --version 2>/dev/null || echo 'available')"
              echo ""
              echo "Build:  nix build ."
              echo "Run:    nix run ."
              echo "FHS:    nix run .#claude-desktop-fhs"
            '';
          };
        }
      );
    };
}
