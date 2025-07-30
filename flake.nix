{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    sf-pro = {
      url = "https://devimages-cdn.apple.com/design/resources/download/SF-Pro.dmg";
      flake = false;
    };
    sf-compact = {
      url = "https://devimages-cdn.apple.com/design/resources/download/SF-Compact.dmg";
      flake = false;
    };
    sf-mono = {
      url = "https://devimages-cdn.apple.com/design/resources/download/SF-Mono.dmg";
      flake = false;
    };
    sf-arabic = {
      url = "https://devimages-cdn.apple.com/design/resources/download/SF-Arabic.dmg";
      flake = false;
    };
    sf-armenian = {
      url = "https://devimages-cdn.apple.com/design/resources/download/SF-Armenian.dmg";
      flake = false;
    };
    sf-georgian = {
      url = "https://devimages-cdn.apple.com/design/resources/download/SF-Georgian.dmg";
      flake = false;
    };
    sf-hebrew = {
      url = "https://devimages-cdn.apple.com/design/resources/download/SF-Hebrew.dmg";
      flake = false;
    };
    ny = {
      url = "https://devimages-cdn.apple.com/design/resources/download/NY.dmg";
      flake = false;
    };
  };

  outputs =
    { nixpkgs, ... }@inputs:
    let
      inherit (nixpkgs) lib;

      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];

      forEachSystem = f: lib.genAttrs systems (system: f { pkgs = import nixpkgs { inherit system; }; });
    in
    {
      packages = forEachSystem (
        { pkgs }:
        let
          unpack = pkgName: ''
            runHook preUnpack

            undmg $src
            7z x "${pkgName}"
            7z x "Payload~"

            rm -rf "*.pkg" "*.dmg" "Payload~" ".background.png"

            runHook postUnpack
          '';

          utils = with pkgs; [
            undmg
            p7zip
          ];

          installPhase = ''
            runHook preInstall

            find . -name "*.otf" -exec install -Dt $out/share/fonts/opentype {} +
            find . -name "*.ttf" -exec install -Dt $out/share/fonts/truetype {} +

            runHook postInstall
          '';

          makeAppleFont =
            name: pkgName: src:
            pkgs.stdenvNoCC.mkDerivation {
              inherit installPhase name src;
              nativeBuildInputs = utils;
              unpackPhase = unpack pkgName;
            };

          makeAppleNerdFont =
            name: pkgName: src:
            pkgs.stdenvNoCC.mkDerivation {
              inherit name src installPhase;

              nativeBuildInputs =
                utils
                ++ (with pkgs; [
                  parallel
                  nerd-font-patcher
                ]);

              unpackPhase = unpack pkgName;

              buildPhase = ''
                runHook preBuild

                echo "Patching fonts..."
                find . -name "*.ttf" -o -name "*.otf" -print0 |
                  parallel --will-cite -j $NIX_BUILD_CORES -0 nerd-font-patcher --no-progressbars -c {}

                rm -rf Library

                runHook postBuild
              '';
            };

          fontPackages = {
            ny = "NY Fonts.pkg";
            sf-arabic = "SF Arabic Fonts.pkg";
            sf-armenian = "SF Armenian Fonts.pkg";
            sf-compact = "SF Compact Fonts.pkg";
            sf-georgian = "SF Georgian Fonts.pkg";
            sf-hebrew = "SF Hebrew Fonts.pkg";
            sf-mono = "SF Mono Fonts.pkg";
            sf-pro = "SF Pro Fonts.pkg";
          };
        in
        lib.listToAttrs (
          lib.concatMap (inputName: [
            {
              name = inputName;
              value = makeAppleFont inputName fontPackages.${inputName} inputs.${inputName};
            }
            {
              name = "${inputName}-nerd";
              value = makeAppleNerdFont "${inputName}-nerd" fontPackages.${inputName} inputs.${inputName};
            }
          ]) (lib.attrNames fontPackages)
        )
      );
    };
}
