{
  plugins = {
    treesitter = {
      enable = true;
      nixGrammars = true;
      settings = { indent.enable = true; };
    };
    treesitter-context = {
      enable = true;
      settings = { max_lines = 2; };
    };
    treesitter-textobjects = {
      enable = true;
      lspInterop.enable = true;
    };
    rainbow-delimiters = {
      enable = true;
    };
  };
}
