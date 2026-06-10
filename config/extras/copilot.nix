{
  plugins = {
    copilot-lua = {
      enable = true;
      settings = {
        panel.enabled = false;
        suggestion.enabled = false;

        filetypes = {
          yaml = false;
          markdown = false;
          help = false;
          gleam = false;
          gitcommit = false;
          gitrebase = false;
          "." = false;
        };
      };
    };
  };
  keymaps = [
    {
      mode = "n";
      key = "<leader>c";
      action = "+copilot";
    }
  ];
}
