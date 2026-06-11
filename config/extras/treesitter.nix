{ lib, config, ... }:
lib.mkIf config.features.treesitter {
  plugins = {
    treesitter = {
      enable = true;
      nixGrammars = true;
      indent.enable = true;
      #settings.ensure_installed = [ "all" ] ;
    };
    treesitter-context = {
      enable = true;
      settings = { max_lines = 2; };
    };
    treesitter-textobjects = {
      enable = true;
      settings.lsp_interop.enable = true;
    };
    rainbow-delimiters = { enable = true; };
  };
}
