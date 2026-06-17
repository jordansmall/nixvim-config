{
  plugins.auto-session = {
    enable = true;
    settings = {
      # Save and restore a session when project.nvim changes cwd.
      cwd_change_handling = true;
      # Name sessions per git branch so switching branches starts fresh.
      use_git_branch = true;
      # Don't create noisy sessions when opening Neovim from generic dirs.
      suppressed_dirs = [ "~" "~/Downloads" "/" "/tmp" ];
    };
  };
}
