{
  description = "alacritty nightly";

  inputs = {
    nixpkgs.url = github:nixos/nixpkgs/nixpkgs-unstable;
    flake-utils.url = github:numtide/flake-utils;
    fenix = {
      url = github:nix-community/fenix;
      inputs.nixpkgs.follows = "nixpkgs";
    };
    naersk = {
      url = github:nmattia/naersk;
      inputs.nixpkgs.follows = "nixpkgs";
    };
    alacritty-src = { url = github:alacritty/alacritty; flake = false; };
    alacritty-ligature-src = { url = github:zenixls2/alacritty/ligature; flake = false; };
  };

  outputs = { self, nixpkgs, flake-utils, fenix, naersk, alacritty-src, alacritty-ligature-src }: flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          fenix.overlay
        ];
      };
    in
    rec {
      defaultPackage = (naersk.lib.${system}.override {
        inherit (fenix.packages.${system}.latest) cargo rustc;
      }).buildPackage {
        src = alacritty-src;
        buildInputs = with pkgs; with darwin.apple_sdk.frameworks; [
          libiconv
          AppKit
          CoreGraphics
          CoreServices
          CoreText
          Foundation
          OpenGL
        ];
        overrideMain = (_: {
          postInstall = ''
            mkdir $out/Applications
            cp -r extra/osx/Alacritty.app $out/Applications
            ln -s $out/bin $out/Applications/Alacritty.app/Contents/MacOS
          '';
        });
      };
    });
}
