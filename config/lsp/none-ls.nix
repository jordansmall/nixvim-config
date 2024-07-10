{
  plugins.none-ls = {
    enable = true;
    sources = {
      formatting = {
        gofmt.enable = true;
        goimports.enable = true;
        ktlint.enable = true;
        nixfmt.enable = true;
      };
    };
  };

}
