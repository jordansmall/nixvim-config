{
  # Import all your configuration modules here
  imports = [
    ./extras/autoclose.nix
    ./extras/bufferline.nix
    ./extras/cmp.nix
    ./extras/conform-nvim.nix
    ./extras/copilot.nix
    ./extras/gitsigns.nix
    #    ./extras/lightline.nix
    ./extras/neo-tree.nix
    ./extras/treesitter.nix
    ./extras/lazygit.nix
    ./extras/lualine.nix
    ./extras/which-key.nix
    #./extras/barbar.nix
    ./extras/tmux-navigator.nix
    ./extras/dressing.nix
    ./extras/fzf.nix
    ./lsp/ionide.nix
    ./lsp/none-ls.nix
    #./lsp/fidget.nix
    ./lsp/friendly-snippets.nix
    ./lsp
    ./lsp/trouble.nix
    ./utils/telescope.nix
    ./utils/blankline.nix
    ./utils/wilder.nix
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
