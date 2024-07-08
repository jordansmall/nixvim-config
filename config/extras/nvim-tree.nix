{
	plugins.nvim-tree = {
		enable = true;
		openOnSetupFile = true;
		autoReloadOnWrite = true;
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
  ];
}
