{
  plugins.project-nvim = {
    enable = true;
    enableTelescope = true;
    settings = {
      # Anchor patterns used to detect project roots. Checked in order.
      patterns = [ ".git" ".hg" "Makefile" "package.json" "flake.nix" ];
      # Suppress the chdir notification; workspace switcher manages cwd explicitly.
      silent_chdir = true;
    };
  };
}
