{
  plugins = {
    luasnip.enable = true;
    cmp-buffer = {
      enable = true;
    };

    cmp-emoji = { enable = true; }; 
    cmp-nvim-lsp = { enable = true; };
    cmp-path = { enable = true; };
    cmp_luasnip = { enable = true; };

    cmp = {
      enable = true;
      autoEnableSources = true;
      settings = {
        snippet.expand = ''
          function(args)
          require('luasnip').ls_expand(args.body)
          end
          '';

        window = {
          completion = {
            winhighlight =
              "FloatBorder:CmpBorder,Normal:CmpPmenu,CursorLine:CmpSel,Search:PmenuSel";
            scrollbar = false;
            sidePadding = 0;
            border = [ "╭" "─" "╮" "│" "╯" "─" "╰" "│" ];
          };

          settings.documentation = {
            border = [ "╭" "─" "╮" "│" "╯" "─" "╰" "│" ];
            winhighlight =
              "FloatBorder:CmpBorder,Normal:CmpPmenu,CursorLine:CmpSel,Search:PmenuSel";
          };
        };
        mapping = {
          "<C-n>" = "cmp.mapping.select_next_item()";
          "<C-p>" = "cmp.mapping.select_prev_item()";
          "<C-j>" = "cmp.mapping.select_next_item()";
          "<C-k>" = "cmp.mapping.select_prev_item()";
          "<C-d>" = "cmp.mapping.scroll_docs(-4)";
          "<C-f>" = "cmp.mapping.scroll_docs(4)";
          "<C-Space>" = "cmp.mapping.complete()";
          "<S-Tab>" = "cmp.mapping.close()";
          "<Tab>" =
            # lua 
            ''
            function(fallback)
            local line = vim.api.nvim_get_current_line()
            if line:match("^%s*$") then
              fallback()
                elseif cmp.visible() then
                cmp.confirm({ behavior = cmp.ConfirmBehavior.Insert, select = true })
            else
              fallback()
                end
                end
            '';
        };
      };
    };

  };
}
