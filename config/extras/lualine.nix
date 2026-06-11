{
  plugins.lualine = {
    enable = true;
    settings = {
      options = {
        theme = "catppuccin";
        disabledFiletypes = { statusline = [ "startup" "alpha" ]; };
        extensions = [ "fzf" "neo-tree" ];
        globalstatus = true;

        sections = {
          lualine_a = [{
            name = "mode";
            #icon = " ";
          }];
          lualine_b = [
            { name = "branch"; }
            {
              name = "diff";
              extraConfig = {
                symbols = {
                  #added = " ";
                  #modified = " ";
                  #removed = " ";
                };
              };
            }
          ];
          lualine_c = [
            {
              name = "diagnostics";
              extraConfig = {
                sources = [ "nvim_lsp" ];
                symbols = {
                  #error = " ";
                  #warn = " ";
                  #info = " ";
                  #hint = "󰝶 ";
                };
              };
            }
            {
              name = "filetype";
              extraConfig = {
                icon_only = true;
                separator = "";
                padding = {
                  left = 1;
                  right = 0;
                };
              };
            }
            {
              name = "filename";
              extraConfig = { path = 1; };
            }
          ];
          lualine_x = [
            { name = "navic"; }
          ];
          lualine_y = [{ name = "progress"; }];
          lualine_z = [{ name = "location"; }];
        };
      };
    };
  };
}
