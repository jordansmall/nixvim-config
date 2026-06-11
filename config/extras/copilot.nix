{ lib, ... }:
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
  };

  # Append the copilot source to nvim-cmp's source list.
  # Uses lib.mkAfter so cmp.nix owns the main list and copilot slots in at the end.
  plugins.cmp.settings.sources = lib.mkAfter [
    { name = "copilot"; }
  ];

  # Append the copilot statusline widget to lualine's lualine_x section.
  # Uses lib.mkAfter so lualine.nix owns the base sections and copilot adds itself.
  plugins.lualine.settings.options.sections.lualine_x = lib.mkAfter [
    {
      name.__raw = ''
        function()
          local icon = " "
          local status = require("copilot.api").status.data
          return icon .. (status.message or " ")
        end,

        cond = function()
         local ok, clients = pcall(vim.lsp.get_clients, { name = "copilot", bufnr = 0 })
         return ok and #clients > 0
        end,
      '';
    }
  ];

  keymaps = [
    {
      mode = "n";
      key = "<leader>c";
      action = "+copilot";
    }
  ];
}
