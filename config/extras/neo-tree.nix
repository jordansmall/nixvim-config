{
  plugins.neo-tree = {
    enable = true;
    settings = {
      sources = ["filesystem" "buffers" "git_status" "document_symbols"];

      default_component_configs = {
        modified = {
          highlight = "NeoTreeModified";
          symbol = "[+] ";
        };
      };
      indent = {
        with_expanders = true;
        expander_collapsed = "";
        expander_expanded = " ";
        expander_highlight = "NeoTreeExpander";
      };
      git_status = {
        symbols = {
          added = " ";
          conflict = "󰩌 ";
          deleted = "󱂥";
          ignored = " ";
          modified = " ";
          renamed = "󰑕";
          staged = "󰩍";
          unstaged = "";
          untracked = "";
        };
      };
      filesystem = {
        # Scroll the tree to the current file and highlight it.
        follow_current_file = {
          enabled = true;
          # Collapse directories you've navigated away from — keeps the tree
          # scoped to the active project rather than accumulating open dirs.
          leave_dirs_open = false;
        };
        # Auto-refresh when files appear or disappear on disk (e.g. after a
        # nix build or git checkout).
        use_libuv_file_watcher = true;
      };
    };
  };

  # Re-root neo-tree whenever project.nvim silently changes cwd.
  # Without this the tree stays anchored to the previous project root.
  autoCmd = [{
    event = "DirChanged";
    desc = "Re-root neo-tree to match the new project root";
    callback.__raw = ''
      function()
        -- Suppress during project switches: tcd fires DirChanged before the
        -- session is loaded.  If neo-tree opens here it either goes full-screen
        -- (only the scratch buffer exists yet) or gets wiped by `silent only`
        -- in the session file.  switch_project opens neo-tree explicitly after
        -- the session is restored instead.
        if _G._sp_switching then return end
        require("neo-tree.command").execute({ dir = vim.fn.getcwd() })
      end
    '';
  }];
}
