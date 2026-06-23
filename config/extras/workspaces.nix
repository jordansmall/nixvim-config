{
  extraConfigLua = ''
    -- Returns true if there is at least one real, listed buffer that is neither
    -- an empty scratch buffer nor a neo-tree panel. Used after a project
    -- switch to decide whether to auto-open telescope find_files.
    local function has_real_listed_bufs()
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted then
          local ft = vim.bo[buf].filetype
          local name = vim.api.nvim_buf_get_name(buf)
          local is_neotree = ft == "neo-tree"
          local is_empty_scratch = false
          if name == "" then
            local lines = vim.api.nvim_buf_get_lines(buf, 0, 1, false)
            is_empty_scratch = (#lines == 0 or lines[1] == "")
          end
          if not is_neotree and not is_empty_scratch then
            return true
          end
        end
      end
      return false
    end

    local function reinit_lsp_for_root(root)
      local resolved_root = vim.fn.resolve(vim.fn.expand(root))
      local clients_to_stop = {}

      for _, client in ipairs(vim.lsp.get_clients()) do
        local client_root = client.config and client.config.root_dir
        if client_root then
          local resolved_client_root = vim.fn.resolve(vim.fn.expand(client_root))
          if resolved_client_root == resolved_root
            or vim.startswith(resolved_client_root, resolved_root .. "/") then
            clients_to_stop[#clients_to_stop + 1] = client
          end
        end
      end

      if #clients_to_stop > 0 then
        vim.lsp.stop_client(clients_to_stop)
      end

      vim.schedule(function()
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
          if vim.api.nvim_buf_is_valid(buf)
            and vim.bo[buf].buflisted
            and vim.bo[buf].filetype ~= "" then
            local name = vim.api.nvim_buf_get_name(buf)
            local in_root = name == ""
              or vim.startswith(vim.fn.resolve(vim.fn.fnamemodify(name, ":p")), resolved_root .. "/")
            if in_root then
              vim.api.nvim_buf_call(buf, function()
                vim.cmd("do FileType")
              end)
            end
          end
        end
      end)
    end

    -- Source a persistence session file safely and return whether it contained
    -- real project files.
    local function load_session_for(root)
      local p = require('persistence')
      local session_file = p.current()
      if vim.fn.filereadable(session_file) == 0 then
        session_file = p.current({ branch = false })
      end
      if not session_file or vim.fn.filereadable(session_file) == 0 then
        return false
      end

      local lines = vim.fn.readfile(session_file)

      -- Pre-scan: does this session have any real files?
      local has_real_files = false
      for _, line in ipairs(lines) do
        if line:match("^badd ") and not line:match("[Nn]eo%-[Tt]ree") then
          has_real_files = true
          break
        end
      end

      -- Filter unsafe tab commands and neo-tree references.
      local filtered = {}
      for _, line in ipairs(lines) do
        local skip = line:match("^%s*silent!?%s+tabonly%s*$")
          or line:match("^%s*tabonly%s*$")
          or line:match("^%s*tab%a")
          or line:match("[Nn]eo%-[Tt]ree")
        if not skip then
          table.insert(filtered, line)
        end
      end

      local tmp = vim.fn.tempname() .. ".vim"
      vim.fn.writefile(filtered, tmp)
      vim.cmd("silent! source " .. vim.fn.fnameescape(tmp))
      vim.fn.delete(tmp)

      -- Synchronous cleanup: unlist neo-tree buffers and any buffers outside
      -- root that snuck in from an old session.
      local real_root = vim.fn.resolve(vim.fn.expand(root))
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted then
          local name = vim.api.nvim_buf_get_name(buf)
          local ft = vim.bo[buf].filetype
          if ft == "neo-tree" then
            vim.bo[buf].buflisted = false
          elseif name ~= "" then
            local resolved = vim.fn.resolve(vim.fn.fnamemodify(name, ":p"))
            if not vim.startswith(resolved, real_root .. "/") then
              vim.bo[buf].buflisted = false
            end
          end
        end
      end

      return has_real_files
    end

    local function switch_project(root)
      if vim.fn.isdirectory(root) == 0 then
        vim.notify('switch_project: invalid directory — ' .. tostring(root), vim.log.levels.ERROR)
        return
      end

      -- Early exit: already on this project in the current tab.
      if vim.fn.resolve(vim.fn.getcwd()) == vim.fn.resolve(root) then
        return
      end

      -- 1. Close neo-tree BEFORE saving so it is absent from the session file.
      pcall(function()
        require("neo-tree.command").execute({ action = "close" })
      end)

      -- 2. Save the session with neo-tree absent from the window layout.
      require('persistence').save()

      -- 3. Re-use an existing tab if this project is already open.
      for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
        local tabnr = vim.api.nvim_tabpage_get_number(tabpage)
        if vim.fn.getcwd(-1, tabnr) == root then
          vim.api.nvim_set_current_tabpage(tabpage)
          vim.schedule(function()
            require("neo-tree.command").execute({ action = "show", dir = root, toggle = false })
            vim.defer_fn(function()
              reinit_lsp_for_root(root)
            end, 300)
          end)
          return
        end
      end

      -- 4. Open a new tab and set the tab-local cwd.
      --    vim.g.sp_switching suppresses the DirChanged neo-tree handler while
      --    we load the session; we open neo-tree explicitly afterwards.
      vim.cmd("tabnew")
      local scratch = vim.api.nvim_get_current_buf()
      vim.g.sp_switching = true
      local ok, result = pcall(function()
        vim.cmd("tcd " .. vim.fn.fnameescape(root))
        return load_session_for(root)
      end)
      vim.g.sp_switching = false

      -- 5. Restore the session. Always clear the switching guard.
      local has_real_bufs = ok and result
      if not ok then
        vim.notify(
          "switch_project: session restore failed — " .. tostring(result),
          vim.log.levels.WARN
        )
      end

      -- 6. Delete the unnamed scratch buffer created by tabnew.
      if vim.api.nvim_buf_is_valid(scratch)
        and vim.api.nvim_buf_get_name(scratch) == "" then
        pcall(vim.api.nvim_buf_delete, scratch, { force = false })
      end

      -- 7. Show neo-tree in the sidebar, then open find_files if no real
      --    project buffers exist.
      vim.schedule(function()
        require("neo-tree.command").execute({ action = "show", dir = root, toggle = false })
        if not has_real_bufs and not has_real_listed_bufs() then
          vim.defer_fn(function()
            require('telescope.builtin').find_files()
          end, 50)
        end
        vim.defer_fn(function()
          reinit_lsp_for_root(root)
        end, 300)
      end)
    end

    local function project_picker()
      local actions = require('telescope.actions')
      local state = require('telescope.actions.state')
      local finders = require('telescope.finders')
      local pickers = require('telescope.pickers')
      local conf = require('telescope.config').values
      local project_nvim = require('project')
      local ok_projects, recent_projects = pcall(project_nvim.get_recent_projects, true)
      if not ok_projects or type(recent_projects) ~= 'table' then
        recent_projects = {}
      end
      recent_projects = vim.fn.reverse(vim.deepcopy(recent_projects))

      pickers.new({}, {
        prompt_title = 'Switch Project',
        results_title = 'Projects',
        finder = finders.new_table({
          results = recent_projects,
          entry_maker = function(path)
            local expanded = vim.fn.expand(path)
            return {
              value = expanded,
              display = vim.fn.fnamemodify(expanded, ':~'),
              ordinal = expanded,
            }
          end,
        }),
        sorter = conf.generic_sorter({}),
        previewer = false,
        attach_mappings = function(prompt_bufnr)
          actions.select_default:replace(function()
            local entry = state.get_selected_entry(prompt_bufnr)
            actions.close(prompt_bufnr)
            if entry then
              switch_project(entry.value)
            end
          end)
          return true
        end,
      }):find()
    end

    local function add_project(preset_dir)
      local default_dir = preset_dir or vim.fn.getcwd()
      local raw = vim.fn.input({
        prompt = 'Add project: ',
        default = default_dir,
        completion = 'dir',
      })
      if not raw or raw == "" then
        return
      end

      local path = vim.fn.resolve(vim.fn.expand(raw))
      if vim.fn.isdirectory(path) == 0 then
        vim.notify('ProjectAdd: not a directory — ' .. path, vim.log.levels.ERROR)
        return
      end

      switch_project(path)
    end

    local function remove_project()
      local ok, telescope = pcall(require, 'telescope')
      if not ok then
        vim.notify('ProjectRemove: telescope is unavailable', vim.log.levels.ERROR)
        return
      end
      local ok_ext = pcall(function()
        telescope.extensions.projects.projects({})
      end)
      if not ok_ext then
        vim.notify('ProjectRemove: telescope projects extension is unavailable', vim.log.levels.ERROR)
        return
      end
      vim.notify('Project picker opened. Press d to remove selected project.', vim.log.levels.INFO)
    end

    vim.api.nvim_create_user_command('ProjectPicker', function()
      project_picker()
    end, { desc = 'Switch project' })

    vim.api.nvim_create_user_command('ProjectAdd', function(opts)
      add_project(opts.args ~= "" and opts.args or nil)
    end, { nargs = '?', complete = 'dir', desc = 'Add project and switch' })

    vim.api.nvim_create_user_command('ProjectRemove', function()
      remove_project()
    end, { desc = 'Open picker and remove project with d' })
  '';
}
