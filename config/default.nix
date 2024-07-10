{
# Import all your configuration modules here
  imports = [ 
    ./extras/autoclose.nix
    ./extras/bufferline.nix
    ./extras/cmp.nix
    ./extras/copilot.nix
    ./extras/gitsigns.nix
    ./extras/lightline.nix
    ./extras/neo-tree.nix
    ./extras/treesitter.nix
    ./extras/neogit.nix
    ./extras/which-key.nix
    #./extras/barbar.nix
    ./extras/tmux-navigator.nix
    ./extras/dressing.nix
    ./extras/fzf.nix
    ./lsp/fidget.nix
    ./lsp/ionide.nix
    ./lsp/none-ls.nix
    ./lsp/trouble.nix
    ./utils/telescope.nix
    ./utils/blankline.nix
    ./options.nix
  ];

  colorschemes.catppuccin.enable = true;

  globals.mapleader = " ";

  keymaps = [
  # File
  {
    mode = "n";
    key = "<leader>f";
    action = "+find/file";
  }
  {
  # Format file
    key = "<leader>fm";
    action = "<CMD>lua vim.lsp.buf.format()<CR>";
    options.desc = "Format the current buffer";
  }

  ];
}
