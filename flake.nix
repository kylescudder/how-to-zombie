{
  description = "How to Zombie: co-op zombie fishing (Godot 4.7 + GodotSteam)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      forAll =
        f:
        nixpkgs.lib.genAttrs systems (
          system:
          f (
            import nixpkgs {
              inherit system;
              # steam-run is unfree. This only applies to this flake's package set.
              config.allowUnfree = true;
            }
          )
        );
      on = pkgs: pkg: nixpkgs.lib.meta.availableOn pkgs.stdenv.hostPlatform pkg;
      godotFor = pkgs: if on pkgs pkgs.godot_4_7 then pkgs.godot_4_7 else null;
      # The prebuilt GodotSteam/Steamworks libraries expect a normal Linux filesystem.
      # Steam itself only exists for x86_64 Linux.
      steamRunFor = pkgs: if pkgs.stdenv.hostPlatform.isx86_64 && pkgs.stdenv.hostPlatform.isLinux then pkgs.steam-run else null;
    in
    {
      packages = forAll (
        pkgs:
        nixpkgs.lib.optionalAttrs (godotFor pkgs != null) {
          godot = godotFor pkgs;
          default = self.packages.${pkgs.stdenv.hostPlatform.system}.play;
          # `nix run` from the repo root: installs GodotSteam if needed, then plays.
          # Extra arguments go to Godot, e.g. `nix run . -- -e` for the editor.
          play = pkgs.writeShellApplication {
            name = "how-to-zombie";
            runtimeInputs = [
              pkgs.bash
              pkgs.curl
              pkgs.unzip
            ]
            ++ nixpkgs.lib.optional (steamRunFor pkgs != null) (steamRunFor pkgs);
            text = ''
              if [ ! -f tools/godot ] || [ ! -f project.godot ]; then
                echo "Run this from the how-to-zombie checkout." >&2
                exit 1
              fi
              [ -f addons/godotsteam/godotsteam.gdextension ] || tools/install_godotsteam.sh
              GODOT="${godotFor pkgs}/bin/godot" exec tools/godot "$@"
            '';
          };
        }
      );

      devShells = forAll (pkgs: {
        default = pkgs.mkShell {
          packages = [
            pkgs.curl
            pkgs.unzip
          ]
          ++ nixpkgs.lib.optional (godotFor pkgs != null) (godotFor pkgs)
          ++ nixpkgs.lib.optional (steamRunFor pkgs != null) (steamRunFor pkgs);
          shellHook =
            if godotFor pkgs != null then
              ''
                export GODOT="${godotFor pkgs}/bin/godot"
                echo "Godot ${(godotFor pkgs).version} ready. First time: tools/setup.sh   Play: tools/godot"
              ''
            else
              ''
                echo "nixpkgs has no Godot 4.7 for this platform; install it another way (see README)."
              '';
        };
      });
    };
}
