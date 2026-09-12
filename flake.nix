{
  description = "A nixvim configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixvim.url = "github:nix-community/nixvim";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = { nixvim, flake-parts, ... }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems =
        [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];

      perSystem = { system, ... }:
        let
          # Upstream re-cut the v3.0.4 tag (bundled copilot/js dropped now that
          # copilot-language-server is packaged separately), so the hash in
          # generated.nix no longer matches. Drop once nixpkgs regenerates it.
          #
          # extend, not `//`: copilot-cmp and copilot-lualine resolve copilot-lua
          # through the vimPlugins fixpoint, so a top-level merge would leave
          # them building the stale source.
          copilotLuaHashFix = _: prev: {
            vimPlugins = prev.vimPlugins.extend (
              _: vprev: {
                copilot-lua = vprev.copilot-lua.overrideAttrs (_: {
                  src = prev.fetchFromGitHub {
                    owner = "zbirenbaum";
                    repo = "copilot.lua";
                    tag = "v3.0.4";
                    hash = "sha256-kDQOm7/N6T7wOw1JlkcxNMnQrDE4oTRyGCZkvT8HZQw=";
                  };
                });
              }
            );
          };
          pkgs = import inputs.nixpkgs {
            inherit system;
            overlays = [ copilotLuaHashFix ];
            config.allowUnfreePredicate = pkg:
              builtins.elem (inputs.nixpkgs.lib.getName pkg) [
                "cmp-emoji"
                "scope.nvim"
                # Pulled in by copilot.lua; GitHub Copilot License.
                "copilot-language-server"
              ];
          };
          nixvimLib = nixvim.lib.${system};
          nixvim' = nixvim.legacyPackages.${system};
          nixvimModule = {
            inherit pkgs;
            module = import ./config; # import the module directly
            # You can use `extraSpecialArgs` to pass additional arguments to your module files
            extraSpecialArgs = {
              # inherit (inputs) foo;
            };
          };
          nvim = nixvim'.makeNixvimWithModule nixvimModule;
        in {
          checks = {
            # Run `nix flake check .` to verify that your config is not broken
            default =
              nixvimLib.check.mkTestDerivationFromNixvimModule nixvimModule;
          };

          packages = {
            # Lets you run `nix run .` to start nixvim
            default = nvim;
          };
        devShells.default = import ./shell.nix { inherit pkgs; };
        };
    };
}
