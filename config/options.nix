{ lib, pkgs, ... }: {
  config.opts = {
    updatetime = 100;
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
}
