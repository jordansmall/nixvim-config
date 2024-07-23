{
  plugins = {
    lsp = {
      enable = true;
      servers = {
        bashls.enable = true;
        gopls.enable = true;
        kotlin-language-server.enable = true;
        nixd.enable = true;
        ansiblels.enable = true;
      };
      keymaps.lspBuf = {
        "gd" = "definition";
        "gr" = "<cmd>Telescope lsp_references<CR>";
        "gt" = "type_definition";
        "gi" = "implementation";
        "K" = "hover";
      };
    };
    lsp-lines = {
      enable = true;
      currentLine = true;
    };
    lsp-status = {
        enable = true;
      };
  };
}
