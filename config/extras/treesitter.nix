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
  };
}
