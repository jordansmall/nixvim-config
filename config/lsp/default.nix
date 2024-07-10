{
  plugins = {
    lsp = {
      enable = true;
      servers = {
        bashls.enable = true;
        gopls.enable = true;
        kotlin-language-server.enable = true;
        nil-ls.enable = true;
      };
      keymaps.lspBuf = {
        "gd" = "definition";
        "gD" = "references";
        "gt" = "type_definition";
        "gi" = "implementation";
        "K" = "hover";
      };
    };
    lsp-lines = {
      enable = true;
    };
    lsp-format = {
      enable = true;
    };
    lsp-status = {
      enable = true;
    };
  };

  diagnostics = {
    virtual_lines = {
      only_current_line = true;
    };
  };
}
