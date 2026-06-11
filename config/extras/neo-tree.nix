{
  plugins.neo-tree = {
    enable = true;
    settings = {
      sources = ["filesystem" "buffers" "git_status" "document_symbols"];

      default_component_configs = {
        modified = {
          highlight = "NeoTreeModified";
          symbol = "[+] ";
        };
      };
      indent = {
        with_expanders = true;
        expander_collapsed = "";
        expander_expanded = " ";
        expander_highlight = "NeoTreeExpander";
      };
      git_status = {
        symbols = {
          added = " ";
          conflict = "󰩌 ";
          deleted = "󱂥";
          ignored = " ";
          modified = " ";
          renamed = "󰑕";
          staged = "󰩍";
          unstaged = "";
          untracked = "";
        };
      };
    };
  };
}
