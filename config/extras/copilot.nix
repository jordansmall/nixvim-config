{
  plugins.copilot-lua = {
    enable = true;
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
}
