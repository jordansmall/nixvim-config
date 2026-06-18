{ lib, pkgs, ... }: {
  config.opts = {
    updatetime = 100;

    # Automatically reload a buffer when the underlying file changes on disk
    # (e.g. after git pull / checkout).  autoread alone is passive; the
    # autoCmd below calls checktime to actively trigger the reload.
    autoread = true;
    timeoutlen = 300;
    fileencoding = "utf-8";

    number = true;
    relativenumber = true;

    autoindent = true;
    expandtab = true;
    smartindent = true;
    shiftwidth = 2;
    tabstop = 2;

    ignorecase = true;
    smartcase = true;

    swapfile = false;
    undofile = true;

    # Limit what mksession saves so persistence.nvim only snapshots the current
    # tab's window layout and buffers.  Omitting "tabpages" is critical: with it
    # present, sourcing a session file recreates the full tab structure of the
    # saved session and re-lists every buffer from every tab, completely
    # bypassing scope.nvim's per-tab buflisted isolation.
    sessionoptions = "buffers,curdir,folds,help,winsize,winpos,terminal,localoptions";
  };

  # Trigger autoread whenever focus returns to Neovim or we enter a buffer.
  # Without these events, autoread is passive and never fires on its own.
  config.autoCmd = [
    {
      event = [ "FocusGained" "BufEnter" "CursorHold" "CursorHoldI" ];
      desc = "Reload buffer if file changed on disk (supports git operations)";
      pattern = "*";
      callback.__raw = ''
        function()
          if vim.fn.mode() ~= "c" then
            vim.cmd("checktime")
          end
        end
      '';
    }
    {
      # FileChangedShellPost fires only after an unmodified buffer has actually
      # been reloaded from disk — the perfect hook for a reload notification.
      event = "FileChangedShellPost";
      desc = "Notify when an unmodified buffer is auto-reloaded from disk";
      pattern = "*";
      callback.__raw = ''
        function()
          local fname = vim.fn.expand("<afile>:~:.")
          vim.notify(
            fname .. " reloaded from disk",
            vim.log.levels.INFO,
            { title = "Buffer auto-reloaded" }
          )
        end
      '';
    }
  ];
}
