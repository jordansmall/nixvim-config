{
  plugins = {
    bufferline = {
      enable = true;

      settings = {
        options = {
          buffer_close_icon = "󰱝 ";
          close_icon = " ";
          mode = "buffers";
          modified_icon = "󰔯 ";
          diagnostics = "nvim_lsp";
          offsets = [{
            filetype = "neo-tree";
            text = "Neo-tree";
            highlight = "Directory";
            text_align = "left";
          }];
        };
      };
    };
  };
}
