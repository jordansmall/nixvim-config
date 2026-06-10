{ pkgs, ... }:

{
  # Consolidated simple plugin enables
  # This file merges many one-liner plugin config files into a single
  # module to reduce fragmentation. It is intentionally minimal: only
  # enables and trivial options are set here. More complex plugin files
  # remain as standalone modules and are imported from config/default.nix.

  # UI / UX helpers
  plugins.autoclose = { enable = true; };
  plugins."which-key" = { enable = true; };
  plugins."tmux-navigator" = { enable = true; };
  plugins.dressing = { enable = true; };

  # FZF integration (simple profile enable)
  plugins.fzf = {
    enable = true;
    profile = "default";
  };

  # Wilder (command-line completion helper)
  plugins.wilder = { enable = true; modes = [ ":" "/" "?" ]; };

  # Snippets, LSP helpers, and small extras
  plugins."friendly-snippets" = { enable = true; };
  plugins.trouble = { enable = true; };

  # Ionide (F#) helper: was a tiny file that exposed extraPlugins using pkgs
  # keep it here as an extraPlugins entry so the vimPlugins package is still
  # added when pkgs is available.
  extraPlugins = with pkgs.vimPlugins; [ Ionide-vim ];

  # Orphaned files removed from the repo (were never imported by default.nix):
  # - neogit — orphaned, was never imported
  # - nvim-tree — orphaned, was never imported
  # - harpoon  — orphaned, was never imported

  # Preserved commented-out plugin placeholders (left as comments so reviewers
  # can see they were intentionally not enabled here):
  # ./extras/lightline.nix       # previously commented-out in default.nix
  # ./extras/barbar.nix         # previously commented-out in default.nix
  # ./lsp/fidget.nix           # previously commented-out in default.nix
}
