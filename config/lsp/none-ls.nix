{
  plugins.none-ls = {
    enable = true;
    sources = {
      completion.luasnip.enable = true;
      code_actions.refactoring.enable = true;
      diagnostics = {
        golangci_lint.enable = true;
        ktlint.enable = true;
        statix.enable = true;
      };
      # formatting sources moved to config/formatting.nix
    };
  };

}
