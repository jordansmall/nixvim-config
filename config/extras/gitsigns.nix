{
  plugins.gitsigns = {
    enable = true;
    settings = {
      current_line_blame = true;
      trouble = true;
    };
  };

  keymaps = [{
    key = "<leader>gp";
    action = "<CMD>Gitsigns preview_hunk<CR>";
    options.desc = "Show git hunk preview";
  }];
}
