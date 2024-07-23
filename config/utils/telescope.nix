{
  plugins.telescope = {
    enable = true;
    keymaps = {
      "<leader>ff" = "find_files";
      "<leader>fg" = "live_grep";
      "<leader>gs" = "git_status";
      "<leader>cd" = "lsp_definitions";
      "<C-p>" = {
        action = "git_files";
        options = { desc = "Telescope Git Files"; };
      };
    };
    extensions.fzf-native = { enable = true; };
  };
}
