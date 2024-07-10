{
  plugins = {
    lsp = {
      enable = true;
      servers = {
        bashls.enable = true;
        gopls.enable = true;
        kotlin-language-server.enable = true;
        nixd.enable = true;
      };
      keymaps.lspBuf = {
        "gd" = "definition";
        "gD" = "references";
        "gt" = "type_definition";
        "gi" = "implementation";
        "K" = "hover";
      };
    };
    lsp-lines = { enable = true; };
  };

  diagnostics = { virtual_lines = { only_current_line = true; }; };
}
