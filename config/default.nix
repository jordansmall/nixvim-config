{
# Import all your configuration modules here
  imports = [ 
    ./extras/bufferline.nix
    ./extras/cmp.nix
    ./extras/treesitter.nix
    ./extras/lightline.nix
    ./extras/neo-tree.nix
    ./lsp/default.nix
    ./lsp/none-ls.nix
    ./lsp/trouble.nix
    ./extras/gitsigns.nix
    ./extras/neogit.nix
    ./extras/autoclose.nix
    ./extras/which-key.nix
    ./extras/copilot.nix
    ./extras/barbar.nix
    ./extras/tmux-navigator.nix
    ./extras/dressing.nix
    ./extras/fzf.nix
    ./utils/telescope.nix
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
