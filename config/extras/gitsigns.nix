{
  plugins.gitsigns = {
    enable = true;
    settings = {
      current_line_blame = true;
      trouble = true;
      signcolumn = true;
      numhl = false;
      linehl = false;
      word_diff = false;
      watch_gitdir = { follow_files = true; };
      auto_attach = true;
      attach_to_untracked = true;
      current_line_blame_opts = {
        virt_text = true;
        virt_text_pos = "eol";
        delay = 1000;
      };

      signs = {
        add = { text = " "; };
        change = { text = " "; };
        delete = { text = " "; };
        untracked = { text = ""; };
        topdelete = { text = "󱂥 "; };
        changedelete = { text = "󱂧 "; };
      };

      current_line_blame_formatter =
        "<author>, <author_time:%Y-%m-%d> - <summary>";
      sign_priority = 6;
      update_debounce = 100;
      status_formatter = null; # Use default
      max_file_length = 40000;
      preview_config = {
        border = "single";
        style = "minimal";
        relative = "cursor";
        row = 0;
        col = 1;
      };
    };
  };

  keymaps = [{
    key = "<leader>gp";
    action = "<CMD>Gitsigns preview_hunk<CR>";
    options.desc = "Show git hunk preview";
  }];
}
