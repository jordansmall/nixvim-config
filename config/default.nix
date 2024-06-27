{
# Import all your configuration modules here
  imports = [ 
    ./extras/bufferline.nix
    ./extras/cmp.nix
    ./extras/treesitter.nix
    ./extras/lightline.nix
    ./lsp/default.nix
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
