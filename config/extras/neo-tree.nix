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
        require("neo-tree.command").execute({ dir = vim.fn.getcwd() })
      end
    '';
  }];
}
