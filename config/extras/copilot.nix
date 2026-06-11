{ lib, config, ... }:
lib.mkIf config.features.copilot {
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

    copilot-cmp.enable = true;
  };

  # Append the copilot source to nvim-cmp's source list.
  # Uses lib.mkAfter so cmp.nix owns the main list and copilot slots in at the end.
  plugins.cmp.settings.sources = lib.mkAfter [
    { name = "copilot"; }
  ];

  # Append the copilot statusline widget to lualine's lualine_x section.
  # Uses lib.mkAfter so lualine.nix owns the base sections and copilot adds itself.
  plugins.lualine.settings.sections.lualine_x = lib.mkAfter [
    {
      __unkeyed-1.__raw = ''
        function()
          local icon = " "
          local status = require("copilot.api").status.data
          return icon .. (status.message or " ")
        end
      '';
      cond.__raw = ''
        function()
          local ok, clients = pcall(vim.lsp.get_clients, { name = "copilot", bufnr = 0 })
          return ok and #clients > 0
        end
      '';
    }
  ];
}
