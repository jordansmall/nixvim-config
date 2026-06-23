{
  plugins.neo-tree = {
    enable = true;
    settings = {
      sources = ["filesystem" "buffers" "git_status" "document_symbols"];
      log_to_file = false;

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
        group_empty_dirs = true;
        window.mappings."<cr>".__raw = ''
          function(state)
            local node = state.tree:get_node()
            if node.type ~= "directory" or node:is_expanded() then
              require("neo-tree.sources.filesystem.commands").open(state)
              return
            end
            local fs       = require("neo-tree.sources.filesystem")
            local renderer = require("neo-tree.ui.renderer")

            -- group_empty_dirs replaces the original node with a new grouped node
            -- whose id is the deepest path in the single-child chain.  Resolve the
            -- current logical node by falling back to the replacement sibling.
            local function resolve(n)
              if state.tree:get_node(n:get_id()) then return n end
              for _, sibling in ipairs(state.tree:get_nodes(n:get_parent_id()) or {}) do
                if vim.startswith(sibling:get_id(), n:get_id()) then
                  return sibling
                end
              end
            end

            local function expand_node(n, cb)
              if n.loaded == false then
                fs.toggle_directory(state, n, nil, false, false, cb)
              else
                if not n:is_expanded() then
                  fs.toggle_directory(state, n)
                end
                cb()
              end
            end

            local function after_expand(n)
              local current = resolve(n)
              if not current then return end

              -- The resolved node may itself be a collapsed grouped node created by
              -- group_empty_dirs — expand it before inspecting children.
              if not current:is_expanded() then
                expand_node(current, function() after_expand(current) end)
                return
              end

              local children = state.tree:get_nodes(current:get_id())
              if children and #children == 1 and children[1].type == "directory" then
                expand_node(children[1], function() after_expand(children[1]) end)
              else
                renderer.focus_node(state, current:get_id())
              end
            end

            expand_node(node, function() after_expand(node) end)
          end
        '';
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
        if vim.g.sp_switching then return end
        require("neo-tree.command").execute({ dir = vim.fn.getcwd() })
      end
    '';
  }];
}
