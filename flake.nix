{
  description = "alacritty nightly";

  inputs = {
    nixpkgs.url = github:nixos/nixpkgs/nixpkgs-unstable;
    flake-utils.url = github:numtide/flake-utils;
    naersk = {
      url = github:nix-community/naersk;
      inputs.nixpkgs.follows = "nixpkgs";
    };
    alacritty-src = { url = github:alacritty/alacritty; flake = false; };
    alacritty-ligature-src = { url = github:zenixls2/alacritty/ligature; flake = false; };
  };

  outputs =
    { self
    , nixpkgs
    , flake-utils
    , naersk
    , alacritty-src
    , alacritty-ligature-src
    }: flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs {
        inherit system;
      };

      naersk-lib = (naersk.lib.${system}.override {
        inherit (pkgs) cargo rustc;
      });

      attrsForNaersk = {
        buildInputs = with pkgs; [ libiconv ]
          ++ pkgs.lib.optionals (system == "x86_64-darwin") (with pkgs.darwin.apple_sdk.frameworks; [
          AppKit
          CoreGraphics
          CoreServices
          CoreText
          Foundation
          OpenGL
        ]);
        overrideMain = (_: {
          postInstall = ''
            mkdir $out/Applications
            cp -r extra/osx/Alacritty.app $out/Applications
            ln -s $out/bin $out/Applications/Alacritty.app/Contents/MacOS
          '';
        });
      };

    in
    rec {
      packages.alacritty-nightly = naersk-lib.buildPackage (attrsForNaersk // { src = alacritty-src; });
      packages.alacritty-ligature = naersk-lib.buildPackage (attrsForNaersk // { src = alacritty-ligature-src; });

      defaultPackage = packages.alacritty-nightly;

      overlay = final: prev: {
        alacritty = packages.alacritty-nightly;
        alacritty-ligature = packages.alacritty-ligature;
      };
    });
}
