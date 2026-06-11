{
  # Import all your configuration modules here
  imports = [
    ./features.nix
    ./plugins-simple.nix
    ./extras/bufferline.nix
    ./extras/cmp.nix
    ./formatting.nix
    ./extras/copilot.nix
    ./extras/gitsigns.nix
    ./extras/neo-tree.nix
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
      mode = "n";
      key = "Y";
      action = ''"*y'';
    }
    {
      mode = "v";
      key = "Y";
      action = ''"*y'';
      options = { desc = "Copy to system clipboard"; };
    }
    {
      mode = "n";
      key = "YY";
      action = ''^"*y$'';
      options = { desc = "Copy to system clipboard"; };
    }
    {
      mode = "n";
      key = "<leader>qq";
      action = "<cmd>qa<cr>";
      options = { desc = "Quit All"; };
    }

  ];
}
