{
  # Formatting pipeline
  # Priority order:
  # 1) conform-nvim (save trigger) runs first. With `format_on_save.lsp_format = "prefer"` it
  #    will use LSP formatting when available, otherwise falls back to its configured
  #    formatters.
  # 2) none-ls registers additional formatters (per-filetype) that LSP-aware tooling or
  #    manual invocations can call into.
  # 3) LSP servers themselves provide formatting as a last fallback.

  # -------------------------------
  # conform-nvim (save trigger)
  # -------------------------------
  plugins.conform-nvim = {
    enable = true;
    settings = {
      format_on_save.lsp_format = "prefer";
    };
  };

  # -------------------------------
  # none-ls formatters (by filetype)
  # -------------------------------
  # These formatters are provided by none-ls (declared active in lsp/none-ls.nix)
  # and complement LSP formatting for filetypes without a dedicated LSP formatter.
  plugins.none-ls.sources.formatting = {
    gofmt.enable = true;
    goimports.enable = true;
    ktlint.enable = true;
    nixfmt.enable = true;
    shfmt.enable = true;
    markdownlint.enable = true;
    shellharden.enable = true;
  };
}
