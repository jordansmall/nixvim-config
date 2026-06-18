{
  plugins.toggleterm = {
    enable = true;
    settings = {
      direction = "float";
      insert_mappings = true;
      open_mapping = "[[<c-return>]]";
      float_opts = {
        width.__raw = "math.floor(vim.o.columns * 0.9)";
        height.__raw = "math.floor(vim.o.lines * 0.9)";
      };
    };
  };
}
