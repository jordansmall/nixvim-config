{
  # direnv.vim applies its async export and then fires `User DirenvLoaded`.
  # LSP servers started earlier keep the environment they were spawned with, so
  # restart only those spawned under an environment that differs from the
  # current one (DirenvLoaded also fires at startup and on no-op re-exports).
  # The whole environ is compared (minus DIRENV_*, which is direnv bookkeeping
  # that changes on a bare .envrc touch), so any other change, e.g. a plugin
  # setting vim.env, also restarts clients once.
  # Restarts are limited to clients under the same .envrc as the cwd direnv
  # exported for (tabs with different :tcd re-export on every tab switch).
  # Independent of the project switcher's own restart in workspaces.nix.
  autoCmd = [
    {
      event = "User";
      pattern = "DirenvLoaded";
      desc = "Restart LSP clients whose environment differs from direnv's";
      callback.__raw = ''
        (function()
          local function environ()
            local env = {}
            for k, v in pairs(vim.fn.environ()) do
              if k:sub(1, 7) ~= "DIRENV_" then env[k] = v end
            end
            return env
          end

          -- Environment of every client spawned since the last DirenvLoaded:
          -- direnv.vim exports and fires it in one callback, so the env only
          -- changes here. LspAttach comes after initialize, too late to
          -- snapshot, and per-server configs override before_init.
          local spawned_with = environ()

          -- direnv loads the nearest .envrc upward from the cwd, so that file
          -- identifies the environment a directory belongs to (nil: none).
          local function envrc_for(dir)
            local found = vim.fs.find(".envrc", { upward = true, path = dir, type = "file" })[1]
            return found and (vim.uv.fs_realpath(found) or found)
          end

          -- A rootless client is placed by the directories of its buffers.
          local function client_dirs(client)
            local dirs, seen = {}, {}
            local function add(dir)
              if not seen[dir] then
                seen[dir] = true
                table.insert(dirs, dir)
              end
            end
            for _, folder in ipairs(client.workspace_folders or {}) do
              add(vim.uri_to_fname(folder.uri))
            end
            if client.root_dir then add(client.root_dir) end
            if #dirs == 0 then
              for buf in pairs(client.attached_buffers) do
                local name = vim.api.nvim_buf_get_name(buf)
                -- URI buffers (fugitive://, oil://) have no directory; dirname
                -- would yield a URI that fs.find walks up to the cwd.
                if name ~= "" and not name:match("^%a[%w+.-]*://") then add(vim.fs.dirname(name)) end
              end
            end
            return dirs
          end

          local function in_scope(client, cwd_envrc)
            for _, dir in ipairs(client_dirs(client)) do
              if envrc_for(dir) == cwd_envrc then return true end
            end
            return false
          end

          return function()
            local current = environ()
            local cwd_envrc = envrc_for(vim.fn.getcwd())
            local function differs(old)
              for k, v in pairs(current) do
                if old[k] ~= v then return true end
              end
              for k in pairs(old) do
                if current[k] == nil then return true end
              end
              return false
            end

            local stale, bufs = {}, {}
            -- _uninitialized is a private filter; without it 0.11 hides
            -- clients that are still initializing.
            for _, client in ipairs(vim.lsp.get_clients({ _uninitialized = true })) do
              if not client:is_stopped() then
                -- Pinned before the scope check: a client skipped now keeps
                -- its own spawn env instead of inheriting a later spawned_with.
                client._direnv_env = client._direnv_env or spawned_with
                if in_scope(client, cwd_envrc) and differs(client._direnv_env) then
                  table.insert(stale, client)
                  for buf in pairs(client.attached_buffers) do bufs[buf] = true end
                end
              end
            end
            spawned_with = current
            if #stale == 0 then return end

            for _, client in ipairs(stale) do client:stop() end
            vim.schedule(function()
              for buf in pairs(bufs) do
                if vim.api.nvim_buf_is_valid(buf)
                  and vim.bo[buf].buflisted
                  and vim.bo[buf].filetype ~= "" then
                  vim.api.nvim_buf_call(buf, function() vim.cmd("do FileType") end)
                end
              end
            end)
          end
        end)()
      '';
    }
  ];
}
