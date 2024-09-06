{
  plugins.neo-tree = {
    enable = true;
    sources = ["filesystem" "buffers" "git_status" "document_symbols"];

    defaultComponentConfigs = {
      modified = {
        highlight = "NeoTreeModified";
        symbol = "[+] ";
      };
      indent = {
        withExpanders = true;
        expanderCollapsed = "";
        expanderExpanded = " ";
        expanderHighlight = "NeoTreeExpander";
      };
      gitStatus = {
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

  keymaps = [
    {
      action = "<C-w>h";
      key = "<C-h>";
      mode = [ "n" ];
    }
    {
      action = "<C-w>j";
      key = "<C-j>";
      mode = [ "n" ];
    }
    {
      action = "<C-w>k";
      key = "<C-k>";
      mode = [ "n" ];
    }
    {
      action = "<C-w>l";
      key = "<C-l>";
      mode = [ "n" ];
    }
    {
      key = "<leader>e";
      action = "<CMD>Neotree toggle<CR>";
      options.desc = "Toggle Nvim Tree";
    }
  ];

}
