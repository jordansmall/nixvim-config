{
  plugins.neo-tree = {
    enable = true;
    defaultComponentConfigs = {
      modified = {
        highlight = "NeoTreeModified";
        symbol = "[+] ";
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
