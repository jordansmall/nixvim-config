{
# Import all your configuration modules here
  imports = [ 
    ./extras/bufferline.nix
    ./extras/cmp.nix
    ./extras/treesitter.nix
    ./extras/lightline.nix
    ./extras/nvim-tree.nix
    ./lsp/default.nix
    ./extras/gitsigns.nix
    ./extras/autoclose.nix
    ./extras/which-key.nix
    ./extras/copilot.nix
    ./extras/barbar.nix
    ./extras/tmux-navigator.nix
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

{
  # Format file
    key = "<leader>e";
    action = "<CMD>NvimTreeToggle<CR>";
    options.desc = "Toggle Nvim Tree";
  }

  ];
}
