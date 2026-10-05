{
  description = "A nixvim configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixvim.url = "github:nix-community/nixvim";
    flake-parts.url = "github:hercules-ci/flake-parts";
    multiverse-nvim = {
      url = "github:codymikol/multiverse.nvim";
      flake = false;
    };
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
              inherit (inputs) multiverse-nvim;
            };
          };
          nvim = nixvim'.makeNixvimWithModule nixvimModule;
          mkHeadlessCheck = name: spec:
            pkgs.runCommand "${name}-check" { nativeBuildInputs = [ nvim ]; } ''
              set +e
              output=$(HOME=$(realpath .) nvim -mn --headless -c "luafile ${spec}" 2>&1 >/dev/null)
              status=$?
              set -e
              if [ "$status" -ne 0 ] || [ -n "$output" ]; then
                echo "$output"
                exit 1
              fi
              touch $out
            '';
        in {
          checks = {
            # Run `nix flake check .` to verify that your config is not broken
            default =
              nixvimLib.check.mkTestDerivationFromNixvimModule (nixvimModule // {
                module = {
                  imports = [ nixvimModule.module ];
                  # The check quits with `+q` from an unregistered cwd, where
                  # multiverse's VimLeavePre save notifies "No universe found"
                  # and any stderr output fails the check.
                  extraConfigLuaPost = ''
                    vim.api.nvim_del_augroup_by_name("multiverse_on_exit")
                  '';
                };
              });

            # Headless keymap audit: fails if any keymap's rhs runs an Ex
            # command that doesn't exist, or binds to a `<cmd>lua Global()<cr>`
            # global at all (ADR 0002: bind to user commands instead).
            keymap-commands =
              mkHeadlessCheck "keymap-commands" ./checks/keymap-commands.lua;

            # Headless spec: `User DirenvLoaded` restarts LSP clients only when
            # the environment changed, and they reattach to listed buffers.
            direnv-lsp = mkHeadlessCheck "direnv-lsp" ./checks/direnv-lsp.lua;

            # Headless spec: a `direnv export vim` job superseded by a newer one
            # is dropped, so it neither applies its output nor fires DirenvLoaded.
            direnv-export = mkHeadlessCheck "direnv-export" ./checks/direnv-export.lua;

            # Headless spec: multiverse.nvim's commands and <leader>p keymaps
            # exist, and the project switcher it replaced is gone.
            multiverse = mkHeadlessCheck "multiverse" ./checks/multiverse.lua;

            # Headless spec: checktime is scoped per event (FocusGained: all
            # buffers, BufEnter: entered buffer, CursorHold*: visible buffers),
            # skipped in command-line mode, and reloads notify.
            autoread = mkHeadlessCheck "autoread" ./checks/autoread.lua;
          };

          packages = {
            # Lets you run `nix run .` to start nixvim
            default = nvim;
          };
        devShells.default = import ./shell.nix { inherit pkgs; };
        };
    };
}
