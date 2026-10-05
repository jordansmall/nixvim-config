{ config, lib, ... }:
{
  # direnv.vim never stops an earlier `direnv export vim` job and, on Neovim,
  # execs every stdout line collected over the whole session. After `:cd /q`
  # then `:cd /p` before the first export finished, its late "unload p" output
  # was applied and fired DirenvLoaded for the wrong environment (#87). Own the
  # trigger instead: only the newest export is allowed to apply its output.
  plugins.direnv.settings.auto = 0;

  # after/plugin: sourced after direnv.vim's plugin/direnv.vim, so the
  # :DirenvExport defined here replaces upstream's.
  extraFiles."after/plugin/direnv-export.lua".text = ''
    local generation = 0
    local job = nil
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

      local cmd = vim.g.direnv_cmd or "${lib.getExe config.dependencies.direnv.package}"
      if vim.fn.executable(cmd) == 0 then
        vim.api.nvim_echo({ {
          "No Direnv executable, add it to your PATH or set correct g:direnv_cmd",
        } }, true, {})
        return
      end

      -- The child inherits the current environment, which is how direnv knows
      -- what is loaded; a superseded job's output is relative to a stale one.
      job = vim.system({ cmd, "export", "vim" }, { text = true, cwd = vim.fn.getcwd() },
        vim.schedule_wrap(function(result)
          if gen ~= generation then return end
          job = nil
          echo_lines(result.stderr)
          if result.stdout and result.stdout ~= "" then vim.cmd(result.stdout) end
          vim.fn["direnv#post_direnv_load"]()
        end))
    end

    local function schedule()
      -- Supersede at trigger time, not spawn time: an export finishing during
      -- the debounce window is already stale.
      generation = generation + 1
      if job then
        job:kill(15)
        job = nil
      end
      timer:stop()
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
