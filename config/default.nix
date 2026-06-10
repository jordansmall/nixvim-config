{
  # Import all your configuration modules here
  imports = [
    ./plugins-simple.nix
    ./extras/bufferline.nix
    ./extras/cmp.nix
    ./formatting
    ./extras/copilot.nix
    ./extras/gitsigns.nix
    #    ./extras/lightline.nix
    ./extras/neo-tree.nix
    ./extras/treesitter.nix
    ./extras/lazygit.nix
    ./extras/lualine.nix
    # ./extras/which-key.nix  # consolidated into plugins-simple.nix
    #./extras/barbar.nix
    # ./extras/tmux-navigator.nix  # consolidated into plugins-simple.nix
    # ./extras/dressing.nix  # consolidated into plugins-simple.nix
    # ./extras/fzf.nix  # consolidated into plugins-simple.nix
    # ./lsp/ionide.nix  # consolidated into plugins-simple.nix
    ./lsp/none-ls.nix
    #./lsp/fidget.nix
    # ./lsp/friendly-snippets.nix  # consolidated into plugins-simple.nix
    ./lsp
    # ./lsp/trouble.nix  # consolidated into plugins-simple.nix
    ./utils/blankline.nix
    # ./utils/wilder.nix  # consolidated into plugins-simple.nix
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
