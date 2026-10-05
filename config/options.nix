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
  };

  # CursorHold fires after every typing pause at updatetime=100ms, so it only
  # checks buffers visible in this tabpage. Per-buffer checktime reloads
  # synchronously, so without nested = true FileChangedShellPost is skipped.
  config.autoCmd = [
    {
      event = "FocusGained";
      desc = "Reload all buffers if files changed on disk (supports git operations)";
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
      event = "BufEnter";
      nested = true;
      desc = "Reload entered buffer if its file changed on disk";
      pattern = "*";
      callback.__raw = ''
        function(args)
          if vim.fn.mode() ~= "c" then
            vim.cmd("checktime " .. args.buf)
          end
        end
      '';
    }
    {
      event = [ "CursorHold" "CursorHoldI" ];
      nested = true;
      desc = "Reload visible buffers if their files changed on disk";
      pattern = "*";
      callback.__raw = ''
        function()
          if vim.fn.mode() == "c" then
            return
          end
          local seen = {}
          for _, buf in ipairs(vim.fn.tabpagebuflist()) do
            if not seen[buf] then
              seen[buf] = true
              vim.cmd("checktime " .. buf)
            end
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
