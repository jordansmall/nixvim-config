{ pkgs, ... }: {
  # Import all your configuration modules here
  imports = [
    ./extras/autoclose.nix
    ./extras/bufferline.nix
    ./extras/cmp.nix
    ./extras/conform-nvim.nix
    ./extras/copilot.nix
    ./extras/gitsigns.nix
    ./extras/lightline.nix
    ./extras/neo-tree.nix
    ./extras/treesitter.nix
    ./extras/lazygit.nix
    ./extras/which-key.nix
    #./extras/barbar.nix
    ./extras/tmux-navigator.nix
    ./extras/dressing.nix
    ./extras/fzf.nix
    ./lsp/ionide.nix
    ./lsp/none-ls.nix
    ./lsp/fidget.nix
    ./lsp/friendly-snippets.nix
    ./lsp/trouble.nix
    ./utils/telescope.nix
    ./utils/blankline.nix
    ./utils/wilder.nix
    ./options.nix
  ];

  colorschemes.catppuccin.enable = true;

  globals.mapleader = " ";

  extraPlugins = [
    (pkgs.vimUtils.buildVimPlugin {
      name = "gh-nvim";
      src = pkgs.fetchFromGitHub {
        owner = "ldelossa";
        repo = "gh.nvim";
        rev = "ebbaac254ef7dd6f85b439825fbce82d0dc84515";
        hash = "sha256-5MWv/TpJSJfPY3y2dC1f2T/9sP4wn0kZ0Sed5OOFM5c=";
      };
    })
  ];

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
