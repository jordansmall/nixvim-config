{
  plugins.persistence = {
    enable = true;
    settings = {
      # Sessions saved per git branch.
      branch = true;
      # Always save even with a single buffer open.
      need = 0;
    };
  };
}
