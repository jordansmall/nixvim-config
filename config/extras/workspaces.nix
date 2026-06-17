{
  extraConfigLua = ''
    local _log = io.open("/tmp/sp-debug.log", "a")
    local function log(msg)
      if _log then _log:write(os.date("%H:%M:%S") .. " " .. msg .. "\n"); _log:flush() end
    end

    local function listed_bufs()
      local t = {}
      for _, b in ipairs(vim.api.nvim_list_bufs()) do
        if vim.bo[b].buflisted then
          t[#t+1] = string.format("buf%d(%s)", b, vim.fn.fnamemodify(vim.api.nvim_buf_get_name(b), ":t"))
        end
      end
      return #t > 0 and table.concat(t, ", ") or "(none)"
    end

    local _project_finder_cache = nil

    -- Defer any write_history calls that fire during get_recent_projects so
    -- they never block the picker open path. Runs once after plugins load.
    -- Use VimEnter here because this config does not use lazy.nvim's LazyDone
    -- event.
    vim.api.nvim_create_autocmd("VimEnter", {
      once = true,
      callback = function()
        local ok, history = pcall(function()
          return require('project').util.history
        end)
        if not ok or not history then return end

        local orig = history.get_recent_projects
        history.get_recent_projects = function(...)
          -- Temporarily replace write_history with a deferred version so any
          -- stale-entry cleanup triggered inside get_recent_projects does not
          -- block synchronously.  Restore in both success and error paths.
          local orig_write = history.write_history
          history.write_history = function(...)
            local args = { ... }
            vim.defer_fn(function() orig_write(unpack(args)) end, 500)
          end
          local ok, result = pcall(orig, ...)
          history.write_history = orig_write   -- restore regardless of outcome
          if not ok then error(result, 2) end
          return result
        end
      end,
    })

    -- Source a persistence session file safely and return whether it contained
    -- real project files.
    --
    -- Safety filters applied to every line before sourcing:
    --   tabonly / silent tabonly  — would close all other project tabs
    --   tabnext / tabprev / tabdo / etc.
    --       — fire TabLeave + TabEnter, corrupting scope.nvim's buffer lists
    --   neo-tree references — we open neo-tree explicitly after restore
    --
    -- Returns true if the session had at least one real (non-neo-tree) badd
    -- line.  This is determined by scanning the file BEFORE sourcing it
    -- because post-load buffer state is unreliable: scope.nvim may relist
    -- the wrong tab's buffers mid-source.
    function load_session_for(root)
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
        local skip = line:match("tabonly")
                  or line:match("^tab%a")
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
      -- root that snuck in from an old session.  Must be synchronous so
      -- persistence.save() on the next switch sees a clean list.
      local real_root = vim.fn.resolve(vim.fn.expand(root))
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted then
          local name = vim.api.nvim_buf_get_name(buf)
          local ft   = vim.bo[buf].filetype
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

    function switch_project(root)
      log("switch_project called — root=" .. root)

      -- Early exit: already on this project in the current tab.
      if vim.fn.resolve(vim.fn.getcwd()) == vim.fn.resolve(root) then
        log("  already on this project, ignoring")
        return
      end

      log("  listed before close+save: " .. listed_bufs())

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
          log("  reusing existing tab " .. tabnr)
          vim.api.nvim_set_current_tabpage(tabpage)
          vim.schedule(function()
            require("neo-tree.command").execute({ action = "show", dir = root, toggle = false })
          end)
          return
        end
      end

      -- 4. Open a new tab and set the tab-local cwd.
      --    _G._sp_switching suppresses the DirChanged neo-tree handler while
      --    we load the session; we open neo-tree explicitly afterwards.
      log("  opening new tab")
      vim.cmd("tabnew")
      local scratch = vim.api.nvim_get_current_buf()
      _G._sp_switching = true
      vim.cmd("tcd " .. vim.fn.fnameescape(root))

      -- 5. Restore the session. Returns true if real project files were present.
      local has_real_bufs = load_session_for(root)
      _G._sp_switching = false
      log("  has_real_bufs=" .. tostring(has_real_bufs) .. "  listed after restore: " .. listed_bufs())

      -- 6. Delete the unnamed scratch buffer created by tabnew.
      if vim.api.nvim_buf_is_valid(scratch)
        and vim.api.nvim_buf_get_name(scratch) == "" then
        pcall(vim.api.nvim_buf_delete, scratch, { force = false })
      end
      log("  listed after scratch delete: " .. listed_bufs())

      -- 7. Show neo-tree in the sidebar, then open find_files if no real
      --    project buffers exist.  vim.schedule lets the window layout settle
      --    before neo-tree inserts its split.
      _project_finder_cache = nil
      vim.schedule(function()
        require("neo-tree.command").execute({ action = "show", dir = root, toggle = false })
        if not has_real_bufs then
          require('telescope.builtin').find_files()
        end
      end)
    end

    -- Custom project picker: reuses project.nvim's finder so the project list
    -- stays in sync, but replaces select_default with switch_project.
    -- :Telescope projects is not used because ahmedkhalf/project.nvim hard-codes
    -- its select_default to find_project_files with no public override hook.
    function ProjectPicker()
      local actions = require('telescope.actions')
      local state   = require('telescope.actions.state')
      local pickers = require('telescope.pickers')
      local conf    = require('telescope.config').values
      local util    = require('telescope._extensions.projects.util')

      pickers.new({}, {
        prompt_title  = 'Switch Project',
        results_title = 'Projects',
        finder        = (function()
                          if not _project_finder_cache then
                            _project_finder_cache = util.create_finder()
                          end
                          return _project_finder_cache
                        end)(),
        sorter        = conf.generic_sorter({}),
        previewer     = false,
        attach_mappings = function(prompt_bufnr)
          actions.select_default:replace(function()
            local entry = state.get_selected_entry(prompt_bufnr)
            actions.close(prompt_bufnr)
            if entry then
              switch_project(vim.fn.expand(entry.value))
            end
          end)
          return true
        end,
      }):find()
    end

    -- Register a directory as a project.nvim project and immediately switch to it.
    -- Prompts for the directory (defaulting to cwd) via vim.fn.input.
    function AddProject(preset_dir)
      local default_dir = preset_dir or vim.fn.getcwd()
      local raw = vim.fn.input({
        prompt     = 'Add project: ',
        default    = default_dir,
        completion = 'dir',
      })
      if raw == ''' then return end

      local path = vim.fn.resolve(vim.fn.expand(raw))
      if vim.fn.isdirectory(path) == 0 then
        vim.notify('AddProject: not a directory — ' .. path, vim.log.levels.ERROR)
        return
      end

      local putil   = require('project').util
      path          = putil.strip_slash(path)
      local history = putil.history
      history.read_history()

      -- Insert into session_projects if not already present; write_history
      -- deduplicates across session + recent so this is safe even if the
      -- project already lives in recent_projects.
      local legacy = history.legacy or false
      if not vim.tbl_contains(history.session_projects or {}, function(v)
        return (legacy and v or v.path) == path
      end, { predicate = true }) then
        local name = vim.fs.joinpath(
          vim.fn.fnamemodify(path, ':h:t'),
          vim.fn.fnamemodify(path, ':t'))
        table.insert(history.session_projects,
          legacy and path or { path = path, name = name })
        history.write_history()
      end

      _project_finder_cache = nil
      switch_project(path)
    end

    -- Open a Telescope picker listing all registered projects; select one to
    -- deregister (remove) it from project.nvim's history.
    function RemoveProject()
      local actions = require('telescope.actions')
      local state   = require('telescope.actions.state')
      local pickers = require('telescope.pickers')
      local conf    = require('telescope.config').values
      local util    = require('telescope._extensions.projects.util')
      local putil   = require('project').util

      pickers.new({}, {
        prompt_title  = 'Remove Project',
        results_title = 'Projects',
        finder        = (function()
                          if not _project_finder_cache then
                            _project_finder_cache = util.create_finder()
                          end
                          return _project_finder_cache
                        end)(),
        sorter        = conf.generic_sorter({}),
        previewer     = false,
        attach_mappings = function(prompt_bufnr)
          actions.select_default:replace(function()
            local entry = state.get_selected_entry(prompt_bufnr)
            actions.close(prompt_bufnr)
            if entry then
              -- entry.value is tilde-form; expand to absolute then strip slash
              local path = putil.rstrip('/', vim.fn.fnamemodify(
                vim.fn.expand(entry.value), ':p'))
              -- prompt=true shows a confirmation dialog before deleting
               putil.history.delete_project(path, true)
               _project_finder_cache = nil
            end
          end)
          return true
        end,
      }):find()
    end
  '';
}
