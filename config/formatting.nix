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
  # These are formatters provided by "none-ls"; they complement LSP formatting and are
  # available for filetypes where no LSP formatter exists or when conform falls back.
  plugins.none-ls = {
    enable = true;
    sources = {
      formatting = {
        gofmt.enable = true;
        goimports.enable = true;
        ktlint.enable = true;
        nixfmt.enable = true;
        shfmt.enable = true;
        markdownlint.enable = true;
        shellharden.enable = true;
      };
    };
  };
}
