{ lib, pkgs, ... }: {
  config.opts = {
    updatetime = 100;
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
}
