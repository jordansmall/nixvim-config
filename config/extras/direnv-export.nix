{ config, lib, ... }:
{
  # direnv.vim never stops an earlier `direnv export vim` job and, on Neovim,
  # execs every stdout line collected over the whole session. After `:cd /q`
  # then `:cd /p` before the first export finished, its late "unload p" output
  # was applied and fired DirenvLoaded for the wrong environment (#87). Own the
  # trigger instead: exports are single-flight and never killed, so a slow
  # nix-direnv evaluation finishes and warms its cache; a trigger while one runs
  # reruns it once it exits, and a result applies only if its cwd is still
  # current. g:direnv_max_wait (default 5) caps how many rapid triggers can
  # postpone an export before it runs regardless of g:direnv_interval. With
  # windows on alternating `:lcd`s a result is dropped when its export exits in
  # the other window, so convergence there relies on each completed export
  # warming nix-direnv's cache.
  plugins.direnv.settings.auto = 0;

  # after/plugin: sourced after direnv.vim's plugin/direnv.vim, so the
  # :DirenvExport defined here replaces upstream's.
  extraFiles."after/plugin/direnv-export.lua".text = ''
    local generation = 0
    local job = nil
    local pending = false
    local triggers = 0
    local timer = assert(vim.uv.new_timer())

    local function echo_lines(text)
      if vim.g.direnv_silent_load and vim.g.direnv_silent_load ~= 0 then return end
      for line in vim.gsplit(text or "", "\n", { plain = true, trimempty = true }) do
        vim.api.nvim_echo({ { line } }, true, {})
      end
    end

    local function export(gen)
      -- Queued by a timer that was superseded before this ran: never spawn.
      if gen ~= generation then return end
      -- Reset whenever the timer fires, as upstream does, even if nothing spawns
      -- (e.g. no executable), or the count sticks at max_wait.
      triggers = 0
      -- Single-flight: a running export is never killed; rerun once it exits.
      if job then
        pending = true
        return
      end

      local cmd = vim.g.direnv_cmd or "${lib.getExe config.dependencies.direnv.package}"
      if vim.fn.executable(cmd) == 0 then
        vim.api.nvim_echo({ {
          "No Direnv executable, add it to your PATH or set correct g:direnv_cmd",
        } }, true, {})
        return
      end

      -- The child inherits the current environment, which is how direnv knows
      -- what is loaded.
      local cwd = vim.fn.getcwd()
      job = vim.system({ cmd, "export", "vim" }, { text = true, cwd = cwd },
        vim.schedule_wrap(function(result)
          job = nil
          -- Single-flight: nothing else changed the environment while this ran,
          -- so it is valid while its cwd is current; gen would starve it.
          local apply_ok, apply_err = true, nil
          if vim.fn.getcwd() == cwd then
            -- A throwing export line or DirenvLoaded handler must not skip the
            -- rerun below. The rerun spawns after applying, because its child
            -- inherits the environment just set.
            apply_ok, apply_err = pcall(function()
              echo_lines(result.stderr)
              if result.stdout and result.stdout ~= "" then vim.cmd(result.stdout) end
              vim.fn["direnv#post_direnv_load"]()
            end)
          end
          if pending then
            pending = false
            export(generation)
          end
          if not apply_ok then error(apply_err, 0) end
        end))
    end

    local function schedule()
      -- Bump at trigger time so an already-queued timer callback goes stale.
      generation = generation + 1
      -- The restarted timer re-decides: spawn, or set pending if a job still runs.
      pending = false
      timer:stop()
      triggers = triggers + 1
      -- Mirrors upstream's g:direnv_max_wait: continuous triggers closer than
      -- the interval would otherwise restart the timer forever, so once
      -- max_wait of them have postponed, the next one exports now instead.
      if triggers > (vim.g.direnv_max_wait or 5) then
        export(generation)
        return
      end
      local gen = generation
      timer:start(vim.g.direnv_interval or 500, 0, vim.schedule_wrap(function() export(gen) end))
    end

    local group = vim.api.nvim_create_augroup("direnv_export", { clear = true })
    vim.api.nvim_create_autocmd({ "VimEnter", "DirChanged" }, {
      group = group,
      desc = "Debounced direnv export",
      callback = schedule,
    })

    vim.api.nvim_create_user_command("DirenvExport", schedule, {
      nargs = 0,
      force = true,
      desc = "Run direnv export (debounced)",
    })
  '';
}
