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
    copilot-chat = {
      enable = true;

    };
  };
  keymaps = [
    {
      mode = "n";
      key = "<leader>c";
      action = "+copilot";
    }
    {
      mode = "n";
      key = "<leader>co";
      action = "<CMD>CopilotChat<CR>";
    }
  ];
}
