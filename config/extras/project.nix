{
  plugins.project-nvim = {
    enable = true;
    enableTelescope = true;
    settings = {
      # Anchor patterns used to detect project roots. Checked in order.
      patterns = [ ".git" ".hg" "Makefile" "package.json" "flake.nix" ];
      # Suppress the chdir notification; workspace switcher manages cwd explicitly.
      silent_chdir = true;
      # Skip project.nvim root detection for Telescope and other non-file buffers.
      # Extends the upstream defaults (help, nofile, nowrite, terminal) with the
      # two buffer types Telescope creates: `prompt` (input bar) and `quickfix`.
      disable_on = {
        bt = [ "help" "nofile" "nowrite" "terminal" "prompt" "quickfix" ];
      };
    };
  };
}
