{
  plugins.project-nvim = {
    enable = true;
    enableTelescope = true;
    settings = {
      # Anchor patterns used to detect project roots. Checked in order.
      patterns = [ ".git" ".hg" "Makefile" "package.json" "flake.nix" ];
      # Do not auto-chdir on BufEnter; workspace switcher manages cwd explicitly.
      silent_chdir = false;
    };
  };
}
