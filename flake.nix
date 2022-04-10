{
  description = "alacritty nightly";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    naersk = {
      url = "github:nix-community/naersk";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    alacritty-src = {
      url = "github:alacritty/alacritty";
      flake = false;
    };
    alacritty-sixel-src = {
      url = "github:microo8/alacritty-sixel";
      flake = false;
    };
    alacritty-ligature-src = {
      url = "github:zenixls2/alacritty/ligature";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, naersk, alacritty-src
    , alacritty-sixel-src, alacritty-ligature-src, ... }:
    {
      overlay = final: prev:
        let
          pkgs = nixpkgs.legacyPackages.${prev.system};

          naersk-lib = (naersk.lib.${prev.system}.override {
            inherit (pkgs) cargo rustc;
          });

          attrsForNaersk = {
            NIX_DEBUG = 1;
            NIX_ENFORCE_PURITY = 0;
            nativeBuildInputs = with pkgs; [
              cmake
              gzip
              installShellFiles
              makeWrapper
              ncurses
              pkg-config
              python3
            ];
            buildInputs = with pkgs;
              [
                libiconv
                expat
                fontconfig
                freetype
                libGL
                xorg.libX11
                xorg.libXcursor
                xorg.libXi
                xorg.libXrandr
                xorg.libXxf86vm
                xorg.libxcb
              ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux
              (with pkgs; [ fontconfig pkgconfig libxkbcommon wayland ])
              ++ pkgs.lib.optionals pkgs.stdenv.isDarwin
              (with pkgs.darwin.apple_sdk.frameworks; [
                AppKit
                CoreGraphics
                CoreServices
                CoreText
                Foundation
                OpenGL
              ]);

            dontPatchELF = true;

            overrideMain = (_: {
              outputs = [ "out" "terminfo" ];
              postPatch = ''
                substituteInPlace alacritty/src/config/ui_config.rs \
                  --replace xdg-open ${pkgs.xdg-utils}/bin/xdg-open
              '';

              postInstall = (if pkgs.stdenv.isDarwin then ''
                mkdir $out/Applications
                cp -r extra/osx/Alacritty.app $out/Applications
                ln -s $out/bin $out/Applications/Alacritty.app/Contents/MacOS
              '' else ''
                install -D extra/linux/Alacritty.desktop -t $out/share/applications/
                install -D extra/linux/io.alacritty.Alacritty.appdata.xml -t $out/share/appdata/
                install -D extra/logo/compat/alacritty-term.svg $out/share/icons/hicolor/scalable/apps/Alacritty.svg
              '') + ''

                echo -n "output is: $out"

                installShellCompletion --zsh extra/completions/_alacritty
                installShellCompletion --bash extra/completions/alacritty.bash
                installShellCompletion --fish extra/completions/alacritty.fish

                install -dm 755 "$out/share/man/man1"
                gzip -c extra/alacritty.man > "$out/share/man/man1/alacritty.1.gz"
                gzip -c extra/alacritty-msg.man > "$out/share/man/man1/alacritty-msg.1.gz"

                install -Dm 644 alacritty.yml $out/share/doc/alacritty.yml

                install -dm 755 "$terminfo/share/terminfo/a/"
                tic -xe alacritty,alacritty-direct -o "$terminfo/share/terminfo" extra/alacritty.info
                mkdir -p $out/nix-support
                echo "$terminfo" >> $out/nix-support/propagated-user-env-packages
              '';
            });
          };
        in {
          alacritty-nightly = naersk-lib.buildPackage (attrsForNaersk // {
            pname = "alacritty-nightly";
            src = alacritty-src;
          });
          alacritty-sixel = naersk-lib.buildPackage (attrsForNaersk // {
            pname = "alacritty-sixel";
            src = alacritty-sixel-src;
          });
          alacritty-ligature = naersk-lib.buildPackage (attrsForNaersk // {
            pname = "alacritty-ligature";
            src = alacritty-ligature-src;
          });
        };
    } // flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ self.overlay ];
        };
      in rec {
        packages.alacritty-nightly = pkgs.alacritty-nightly;
        packages.alacritty-sixel = pkgs.alacritty-sixel;
        packages.alacritty-ligature = pkgs.alacritty-ligature;
        defaultPackage = pkgs.alacritty-nightly;
      });
}
