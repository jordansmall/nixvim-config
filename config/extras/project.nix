{
  plugins.project-nvim = {
    enable = true;
    enableTelescope = true;
    settings = {
      # Anchor patterns used to detect project roots. Checked in order.
      patterns = [ ".git" ".hg" "Makefile" "package.json" "flake.nix" ];
      # Silently change cwd to project root on BufEnter; no echo.
      silent_chdir = true;
    };
  };
}
