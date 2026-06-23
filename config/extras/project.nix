{
  globals.project_history_no_data_notified = 1;

  plugins.project-nvim = {
    enable = true;
    enableTelescope = true;
    settings = {
      # Anchor patterns used to detect project roots. Checked in order.
      patterns = [ ".git" ".hg" "Makefile" "package.json" "flake.nix" ];
      # Keep history writable in restricted/sandboxed environments (e.g. flake checks)
      # by falling back to TMPDIR when stdpath('data') is unavailable.
      history.save_dir.__raw = ''
        (function()
          local data = vim.fn.stdpath("data")
          if vim.fn.isdirectory(data) == 1 and vim.fn.filewritable(data) == 2 then
            return data
          end
          return os.getenv("TMPDIR") or "/tmp"
        end)()
      '';
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
