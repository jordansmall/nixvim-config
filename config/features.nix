{ lib, ... }:
{
  options.features = {
    copilot = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable GitHub Copilot integration (copilot-lua, cmp source, lualine widget).";
    };

    treesitter = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable treesitter, treesitter-context, treesitter-textobjects, and rainbow-delimiters.";
    };

    lazygit = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable LazyGit floating window integration.";
    };

    fidget = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable fidget.nvim LSP progress notifications. Disabled by default.";
    };
  };
}
