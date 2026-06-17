{
  # Import all your configuration modules here
  imports = [
    ./features.nix
    ./keymaps.nix
    ./plugins-simple.nix
    ./extras/bufferline.nix
    ./extras/cmp.nix
    ./formatting.nix
    ./extras/copilot.nix
    ./extras/gitsigns.nix
    ./extras/neo-tree.nix
    ./extras/project.nix
    ./extras/workspaces.nix
    ./extras/session.nix
    ./extras/telescope.nix
    ./extras/treesitter.nix
    ./extras/lazygit.nix
    ./extras/lualine.nix
    ./lsp/none-ls.nix
    #./lsp/fidget.nix
    ./lsp
    ./utils/blankline.nix
    ./utils/navic.nix
    ./utils/toggleterm.nix
    ./options.nix
  ];

  colorschemes.catppuccin.enable = true;

  plugins.web-devicons.enable = true;

  globals.mapleader = " ";
}
