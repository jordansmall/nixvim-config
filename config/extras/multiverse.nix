{ pkgs, multiverse-nvim, ... }:
let
  # lastModifiedDate is YYYYMMDDHHMMSS; nixpkgs versions use YYYY-MM-DD.
  d = multiverse-nvim.lastModifiedDate;
  date = "${builtins.substring 0 4 d}-${builtins.substring 4 2 d}-${builtins.substring 6 2 d}";
  multiverse = pkgs.vimUtils.buildVimPlugin {
    pname = "multiverse.nvim";
    version = "0-unstable-${date}";
    src = multiverse-nvim;
    # lua/integrations/telescope.lua requires telescope.* at load time, which
    # the build's require check exercises; that check only puts direct
    # dependencies on the rtp, so telescope's plenary must be listed too.
    # neo-tree and CopilotChat are only required lazily inside plugin
    # callbacks, so they are not needed.
    dependencies = with pkgs.vimPlugins; [ telescope-nvim plenary-nvim ];
  };
in {
  extraPlugins = [ multiverse ];
  # MultiverseTerminal shells out to zellij and warns when it is missing.
  extraPackages = [ pkgs.zellij ];
  extraConfigLua = ''
    -- multiverse's initialize uses a non-recursive mkdir under stdpath("data")
    -- and notifies at ERROR level on failure, which breaks fresh HOMEs.
    vim.fn.mkdir(vim.fn.stdpath("data"), "p")
    require("multiverse").setup({ title = true })
  '';
}
