-- Headless Neovim spec for the `direnv-export` flake check: a `direnv export
-- vim` job superseded by a newer one (e.g. `:cd /q` then `:cd /p` back before
-- the first finished) must not apply its output or fire `User DirenvLoaded`,
-- because the environment it was computed for is no longer the current one.
--
-- Exports must also keep completing under sustained triggers: ones arriving
-- slower than the debounce interval (each lands mid-export), faster than it
-- (g:direnv_max_wait must cap the postponing), and alternating `:lcd` windows
-- whose cwd differs from the running job's. Exports are single-flight: a
-- trigger while one runs never spawns a second or kills it, and the
-- (max_wait + 1)th rapid trigger exports immediately. A trigger landing after
-- the timer set pending defers the rerun to the restarted debounce
-- (pending-cleared).
--
-- direnv is replaced by a fake command whose per-directory delay and output
-- the spec controls through `.delay` and `.out` files. It writes `.finished`
-- only after its delay, which shows a superseded job ran to completion rather
-- than being killed, and appends a line to `.spawned` per run so spawns can
-- be counted.

-- Same reason as in direnv-lsp.lua: copilot's client would be restarted by the
-- DirenvLoaded handler and its exit is reported on stderr on macOS.
local copilot_ok, copilot = pcall(require, "copilot.command")
if copilot_ok then
  copilot.disable()
end

local failures = {}

local function fail(msg)
  table.insert(failures, msg)
end

local function read(path)
  local f = io.open(path)
  if not f then
    return nil
  end
  local content = f:read("*a")
  f:close()
  return content
end

local function exists(path)
  return vim.uv.fs_stat(path) ~= nil
end

local function run()
  -- realpath: macOS tempdirs sit behind a symlink and cwd reports the resolved path.
  local base = vim.fn.tempname() .. "-export"
  vim.fn.mkdir(base, "p")
  base = vim.uv.fs_realpath(base)
  local saved_cwd = vim.fn.getcwd()

  local fake = base .. "/fake-direnv"
  vim.fn.writefile({
    "#!/bin/sh",
    'echo >> "$PWD/.spawned"',
    'sleep "$(cat "$PWD/.delay" 2>/dev/null || echo 0)"',
    'touch "$PWD/.finished"',
    'cat "$PWD/.out" 2>/dev/null',
    "exit 0",
  }, fake)
  vim.fn.setfperm(fake, "rwxr-xr-x")

  local function make_dir(name, delay, out)
    local dir = base .. "/" .. name
    vim.fn.mkdir(dir, "p")
    vim.fn.writefile({ tostring(delay) }, dir .. "/.delay")
    vim.fn.writefile(out, dir .. "/.out")
    return dir
  end
  local p = make_dir("p", 0, {})
  local q = make_dir("q", 0.5, { "unlet $SPEC_X" })

  vim.g.direnv_cmd = fake
  vim.g.direnv_interval = 20
  vim.env.SPEC_X = "p"

  local ok, err = pcall(function()
    vim.cmd.cd(vim.fn.fnameescape(p))
    if not vim.wait(5000, function() return exists(p .. "/.spawned") end, 10) then
      fail("no export was spawned for :cd into the first directory (spec setup broken)")
      return
    end
    -- Let that export finish before observing DirenvLoaded.
    vim.wait(300)

    local loaded = {}
    vim.api.nvim_create_autocmd("User", {
      pattern = "DirenvLoaded",
      callback = function()
        table.insert(loaded, vim.env.SPEC_X or "<unset>")
      end,
    })

    -- Slow export for q is in flight when we come back to p, whose export
    -- prints nothing (the environment is still p's).
    vim.cmd.cd(vim.fn.fnameescape(q))
    if not vim.wait(5000, function() return exists(q .. "/.spawned") end, 10) then
      fail("no export was spawned for :cd into the slow directory (spec setup broken)")
      return
    end
    vim.cmd.cd(vim.fn.fnameescape(p))
    if not vim.wait(5000, function() return #loaded >= 1 end, 10) then
      fail("no DirenvLoaded after returning to the first directory")
      return
    end
    -- Past the slow export's sleep, so a stale result would have landed.
    vim.wait(800)

    if not exists(q .. "/.finished") then
      fail("a superseded export was killed: it never ran to completion")
    end
    if vim.env.SPEC_X ~= "p" then
      fail(string.format(
        "a superseded export was applied: SPEC_X is %s, expected \"p\"",
        tostring(vim.env.SPEC_X)))
    end
    if #loaded ~= 1 then
      fail(string.format(
        "expected exactly one DirenvLoaded, got %d (SPEC_X at each: [%s])",
        #loaded, table.concat(loaded, ",")))
    elseif loaded[1] ~= "p" then
      fail(string.format("DirenvLoaded fired with SPEC_X=%s, expected \"p\"", loaded[1]))
    end
  end)

  local loads = 0
  vim.api.nvim_create_autocmd("User", {
    pattern = "DirenvLoaded",
    callback = function()
      loads = loads + 1
    end,
  })

  -- cd into a fresh directory and let its automatic export finish, so the
  -- explicit `:DirenvExport` under test is the only one still to come.
  local function enter(dir)
    vim.cmd.cd(vim.fn.fnameescape(dir))
    if not vim.wait(5000, function() return exists(dir .. "/.spawned") end, 10) then
      error("no export was spawned for :cd (spec setup broken)", 0)
    end
    vim.wait(300)
  end

  local function export_and_wait()
    local before = loads
    vim.cmd.DirenvExport()
    return vim.wait(5000, function() return loads > before end, 10)
  end

  local ok2, err2 = pcall(function()
    -- A no-op export must not replay an earlier export's output over a
    -- variable the user has since changed.
    vim.env.SPEC_Y = nil
    -- Empty while entering, so only the explicit export can set SPEC_Y.
    local own = make_dir("own", 0, {})
    enter(own)
    vim.fn.writefile({ "let $SPEC_Y = 'direnv'" }, own .. "/.out")
    if not export_and_wait() then
      fail("own-stdout: no DirenvLoaded after the first :DirenvExport")
      return
    end
    if vim.env.SPEC_Y ~= "direnv" then
      fail(string.format("own-stdout: SPEC_Y is %s, expected \"direnv\"", tostring(vim.env.SPEC_Y)))
    end

    vim.fn.writefile({}, own .. "/.out")
    vim.env.SPEC_Y = "user"
    if not export_and_wait() then
      fail("own-stdout: no DirenvLoaded after the second :DirenvExport")
      return
    end
    if vim.env.SPEC_Y ~= "user" then
      fail(string.format(
        "own-stdout: a no-op export replayed old output: SPEC_Y is %s, expected \"user\"",
        tostring(vim.env.SPEC_Y)))
    end
  end)

  -- Neovim delivers a large stdout in partial-line chunks; a line split across
  -- them must still be exec'd whole.
  local ok3, err3 = pcall(function()
    vim.env.SPEC_BIG = nil
    vim.env.SPEC_TAIL = nil
    local big_len = 200 * 1024
    local big = make_dir("big", 0, {})
    enter(big)
    vim.fn.writefile({
      "let $SPEC_BIG = '" .. string.rep("x", big_len) .. "'",
      "let $SPEC_TAIL = 'ok'",
    }, big .. "/.out")
    if not export_and_wait() then
      fail("large-output: no DirenvLoaded after :DirenvExport")
      return
    end
    local got = #(vim.env.SPEC_BIG or "")
    if got ~= big_len then
      fail(string.format("large-output: SPEC_BIG has length %d, expected %d", got, big_len))
    end
    if vim.env.SPEC_TAIL ~= "ok" then
      fail(string.format("large-output: SPEC_TAIL is %s, expected \"ok\"", tostring(vim.env.SPEC_TAIL)))
    end
  end)

  -- The superseding trigger can land while the old export is still running but
  -- before the new one has spawned (the debounce window); the old export must
  -- already count as stale then.
  local ok4, err4 = pcall(function()
    -- The 200 KiB value left by the previous scenario would make spawning fail with E2BIG.
    vim.env.SPEC_BIG = nil
    local p2 = make_dir("p2", 0, {})
    local q2 = make_dir("q2", 0.3, { "unlet $SPEC_X" })
    vim.g.direnv_interval = 600
    vim.env.SPEC_X = "p"

    enter(p2)
    if not exists(p2 .. "/.finished") then
      fail("debounce-window: a completed export left no .finished marker (spec setup broken)")
      return
    end
    local seen = {}
    vim.api.nvim_create_autocmd("User", {
      pattern = "DirenvLoaded",
      callback = function()
        table.insert(seen, vim.env.SPEC_X or "<unset>")
      end,
    })

    vim.cmd.cd(vim.fn.fnameescape(q2))
    if not vim.wait(5000, function() return exists(q2 .. "/.spawned") end, 10) then
      fail("debounce-window: no export was spawned for the slow directory (spec setup broken)")
      return
    end
    -- Back to p2 while q2's export runs; the trigger supersedes it before p2's
    -- has spawned, and it must still run to completion unapplied.
    vim.cmd.cd(vim.fn.fnameescape(p2))
    if not vim.wait(5000, function() return #seen >= 1 end, 10) then
      fail("debounce-window: no DirenvLoaded after returning to the first directory")
      return
    end
    vim.wait(1000)

    if not exists(q2 .. "/.finished") then
      fail("debounce-window: a superseded export was killed: it never ran to completion")
    end
    if vim.env.SPEC_X ~= "p" then
      fail(string.format(
        "debounce-window: a superseded export was applied: SPEC_X is %s, expected \"p\"",
        tostring(vim.env.SPEC_X)))
    end
    if #seen ~= 1 then
      fail(string.format(
        "debounce-window: expected exactly one DirenvLoaded, got %d (SPEC_X at each: [%s])",
        #seen, table.concat(seen, ",")))
    elseif seen[1] ~= "p" then
      fail(string.format("debounce-window: DirenvLoaded fired with SPEC_X=%s, expected \"p\"", seen[1]))
    end
  end)
  vim.g.direnv_interval = 20

  -- The debounce timer can fire and queue its export just before a DirChanged
  -- supersedes it. That queued export is stale and must not spawn, or the
  -- restarted timer would then spawn a second export for the same directory.
  local ok5, err5 = pcall(function()
    local r = make_dir("r", 0, {})
    local seen = 0
    vim.api.nvim_create_autocmd("User", {
      pattern = "DirenvLoaded",
      callback = function()
        seen = seen + 1
      end,
    })
    -- Started before the exporter's timer with the same timeout, so libuv
    -- fires it first and its queued call runs ahead of the queued export.
    local racer = assert(vim.uv.new_timer())
    racer:start(vim.g.direnv_interval, 0, vim.schedule_wrap(function()
      vim.cmd.DirenvExport()
    end))
    vim.cmd.cd(vim.fn.fnameescape(r))
    vim.wait(500)
    racer:close()

    local spawns = #vim.fn.readfile(r .. "/.spawned")
    if spawns ~= 1 then
      fail(string.format("stale-queued-export: expected 1 export spawn, got %d", spawns))
    end
    if seen ~= 1 then
      fail(string.format("stale-queued-export: expected exactly one DirenvLoaded, got %d", seen))
    end
  end)

  -- Triggers spaced wider than the debounce interval but closer than an
  -- export's duration land during every running export. Each result must still
  -- be applied once its export exits, or nothing is applied until the triggers
  -- stop (starvation).
  local group6 = vim.api.nvim_create_augroup("spec_sustained_triggers", { clear = true })
  local ok6, err6 = pcall(function()
    local slow = make_dir("slow", 0.3, { "let $SPEC_B = 'b'" })
    vim.env.SPEC_B = nil
    vim.g.direnv_interval = 20

    local before = loads
    vim.cmd.cd(vim.fn.fnameescape(slow))
    if not vim.wait(5000, function() return loads > before end, 10) then
      fail("sustained-triggers: no DirenvLoaded for the first export (spec setup broken)")
      return
    end
    vim.env.SPEC_B = nil
    -- The export above left it behind; only one from the storm may recreate it.
    vim.fn.delete(slow .. "/.finished")

    local storming = true
    local during = 0
    local finished_at_load, spec_b_at_load
    vim.api.nvim_create_autocmd("User", {
      group = group6,
      pattern = "DirenvLoaded",
      callback = function()
        if storming then
          during = during + 1
          if during == 1 then
            finished_at_load = exists(slow .. "/.finished")
            spec_b_at_load = vim.env.SPEC_B
          end
        end
      end,
    })

    local ticks = 0
    local storm = assert(vim.uv.new_timer())
    storm:start(100, 100, vim.schedule_wrap(function()
      ticks = ticks + 1
      if ticks > 12 then
        storming = false
        storm:stop()
        storm:close()
        return
      end
      vim.cmd.DirenvExport()
    end))
    -- The storm (1.2 s) plus time for the last export to finish and apply.
    vim.wait(2200)

    if during < 1 then
      fail("sustained-triggers: condition B starvation: no DirenvLoaded while triggers kept arriving")
    else
      if not finished_at_load then
        fail("sustained-triggers: the in-storm DirenvLoaded fired before its export ran to completion")
      end
      if spec_b_at_load ~= "b" then
        fail(string.format(
          "sustained-triggers: SPEC_B was %s at the in-storm DirenvLoaded, expected \"b\"",
          tostring(spec_b_at_load)))
      end
    end
  end)
  vim.api.nvim_del_augroup_by_id(group6)

  -- Triggers arriving closer together than the debounce interval keep
  -- restarting its timer, so without a cap no export runs until they stop.
  local group7 = vim.api.nvim_create_augroup("spec_rapid_triggers", { clear = true })
  local ok7, err7 = pcall(function()
    local rapid = make_dir("rapid", 0, { "let $SPEC_A = 'a'" })
    vim.env.SPEC_A = nil
    vim.g.direnv_interval = 500

    enter(rapid)
    vim.env.SPEC_A = nil

    local storming = true
    local during = 0
    local ticks = 0
    local ticks_at_first_load
    vim.api.nvim_create_autocmd("User", {
      group = group7,
      pattern = "DirenvLoaded",
      callback = function()
        if storming then
          during = during + 1
          ticks_at_first_load = ticks_at_first_load or ticks
        end
      end,
    })

    local storm = assert(vim.uv.new_timer())
    storm:start(20, 20, vim.schedule_wrap(function()
      ticks = ticks + 1
      if ticks > 50 then
        storming = false
        storm:stop()
        storm:close()
        return
      end
      vim.cmd.DirenvExport()
    end))
    -- The storm (1 s) plus time for the trailing export to finish and apply.
    vim.wait(2300)

    if during < 1 then
      fail("rapid-triggers: condition A starvation: no DirenvLoaded while triggers kept arriving (max-wait cap missing)")
    else
      -- The cap fires on trigger max_wait + 1; the slack covers the 0-delay
      -- export running and applying. The debounce alone would not export until
      -- after the storm's last trigger, so this tells the cap from the debounce.
      -- Counting triggers rather than time keeps it independent of tick delays.
      local limit = (vim.g.direnv_max_wait or 5) + 1 + 15
      if ticks_at_first_load > limit then
        fail(string.format(
          "rapid-triggers: the first in-storm export applied after %d triggers, expected at most %d (max-wait cap too slow)",
          ticks_at_first_load, limit))
      end
    end
    if vim.env.SPEC_A ~= "a" then
      fail(string.format("rapid-triggers: SPEC_A is %s, expected \"a\"", tostring(vim.env.SPEC_A)))
    end
  end)
  vim.api.nvim_del_augroup_by_id(group7)
  vim.g.direnv_interval = 20

  -- A trigger that lands while an export runs must not spawn a second one
  -- alongside it; the rerun waits until the running export has exited.
  local ok8, err8 = pcall(function()
    local single = make_dir("single", 0.5, {})
    vim.g.direnv_interval = 20

    vim.cmd.cd(vim.fn.fnameescape(single))
    if not vim.wait(5000, function() return exists(single .. "/.spawned") end, 10) then
      fail("single-flight: no export was spawned for :cd (spec setup broken)")
      return
    end

    local function spawns()
      return #vim.fn.readfile(single .. "/.spawned")
    end

    -- Spaced wider than the interval, so each trigger's timer fires mid-export.
    for _ = 1, 5 do
      vim.cmd.DirenvExport()
      vim.wait(60)
      if not exists(single .. "/.finished") and spawns() > 1 then
        fail(string.format(
          "single-flight: a second export spawned while the first was still running (%d spawns)",
          spawns()))
        return
      end
    end

    if not vim.wait(5000, function() return exists(single .. "/.finished") end, 10) then
      fail("single-flight: the slow export never finished (spec setup broken)")
      return
    end
    if not vim.wait(5000, function() return spawns() >= 2 end, 10) then
      fail("single-flight: no rerun after the running export exited")
    end
    -- Let the rerun finish before the directory is deleted.
    vim.wait(700)
  end)
  vim.g.direnv_interval = 20

  -- Upstream exports once its counter has reached g:direnv_max_wait, so
  -- max_wait triggers may postpone an export and the next one runs it.
  local ok9, err9 = pcall(function()
    local cap = make_dir("cap", 0, {})
    vim.g.direnv_interval = 2000

    -- The :cd is itself a trigger; its export spawns once the interval passes
    -- and resets the count.
    enter(cap)
    local function spawns()
      return #vim.fn.readfile(cap .. "/.spawned")
    end
    local base_spawns = spawns()

    local max_wait = vim.g.direnv_max_wait or 5
    for _ = 1, max_wait do
      vim.cmd.DirenvExport()
    end
    vim.wait(200)
    if spawns() ~= base_spawns then
      fail(string.format(
        "max-wait: %d triggers exported already (%d spawns, expected %d); only the one after them may",
        max_wait, spawns(), base_spawns))
      return
    end

    vim.cmd.DirenvExport()
    if not vim.wait(1000, function() return spawns() > base_spawns end, 10) then
      fail("max-wait: the trigger after max_wait postponed ones did not export immediately")
    end
    vim.wait(300)
  end)
  vim.g.direnv_interval = 20

  -- Upstream resets its counter whenever the timer fires. A missing executable
  -- must not leave the count stuck at max_wait, or every later trigger skips
  -- the debounce and reports the missing executable immediately.
  local ok10, err10 = pcall(function()
    local echoes = 0
    local real_echo = vim.api.nvim_echo
    -- Headless Neovim writes echoed messages to stderr, which fails the check.
    vim.api.nvim_echo = function()
      echoes = echoes + 1
    end
    local inner_ok, inner_err = pcall(function()
      vim.g.direnv_cmd = base .. "/no-such-direnv"
      vim.g.direnv_interval = 20

      -- Each trigger's timer fires before the next trigger.
      for _ = 1, (vim.g.direnv_max_wait or 5) + 2 do
        vim.cmd.DirenvExport()
        vim.wait(80)
      end
      if echoes == 0 then
        fail("missing-executable: no report for the missing executable (spec setup broken)")
        return
      end

      local before = echoes
      vim.cmd.DirenvExport()
      if echoes ~= before then
        fail("missing-executable: a trigger skipped the debounce and reported immediately")
      end
      vim.wait(80)
    end)
    vim.api.nvim_echo = real_echo
    if not inner_ok then
      error(inner_err, 0)
    end
  end)
  vim.g.direnv_cmd = fake
  vim.g.direnv_interval = 20

  -- Applying a result can throw (a bad export line, a DirenvLoaded handler);
  -- the rerun queued by a trigger during the export must still happen.
  local ok11, err11 = pcall(function()
    local boom = make_dir("boom", 0.3, { "lua error('boom')" })
    vim.g.direnv_interval = 20

    -- A throw in a scheduled callback is written to stderr, which fails the
    -- check; collect it instead. The exit callback is wrapped when an export
    -- spawns, so this is in place before the first one.
    local errors = {}
    local real_wrap = vim.schedule_wrap
    vim.schedule_wrap = function(fn)
      return real_wrap(function(...)
        local call_ok, call_err = pcall(fn, ...)
        if not call_ok then
          table.insert(errors, tostring(call_err))
        end
      end)
    end
    local inner_ok, inner_err = pcall(function()
      vim.cmd.cd(vim.fn.fnameescape(boom))
      if not vim.wait(5000, function() return exists(boom .. "/.spawned") end, 10) then
        fail("apply-throws: no export was spawned for :cd (spec setup broken)")
        return
      end
      -- Lands while that export runs, so its timer sets pending.
      vim.cmd.DirenvExport()

      local function spawns()
        return #vim.fn.readfile(boom .. "/.spawned")
      end
      if not vim.wait(5000, function() return spawns() >= 2 end, 10) then
        fail("apply-throws: the rerun queued during the export was lost when applying its result threw")
      end
      -- Let the rerun finish before the directory is deleted.
      vim.wait(700)

      if not (errors[1] or ""):find("boom", 1, true) then
        fail("apply-throws: the apply error was swallowed instead of re-raised: "
          .. vim.inspect(errors))
      end
    end)
    vim.schedule_wrap = real_wrap
    if not inner_ok then
      error(inner_err, 0)
    end
  end)
  vim.g.direnv_interval = 20

  -- The motivating case for single-flight: windows with different `:lcd`
  -- directories fire DirChanged with alternating cwds, rarely matching the
  -- running job's. Exports must still run to completion instead of being
  -- killed by the next trigger, and never overlap.
  local ok12, err12 = pcall(function()
    local alt_a = make_dir("alt-a", 0.3, {})
    local alt_b = make_dir("alt-b", 0.3, {})
    vim.g.direnv_interval = 20

    local function spawns(dir)
      local lines = exists(dir .. "/.spawned") and vim.fn.readfile(dir .. "/.spawned") or {}
      return #lines
    end

    local first_win = vim.api.nvim_get_current_win()
    local second_win
    local inner_ok, inner_err = pcall(function()
      vim.cmd.lcd(vim.fn.fnameescape(alt_a))
      if not vim.wait(5000, function() return exists(alt_a .. "/.finished") end, 10) then
        fail("alternating-lcd: no export finished for the first window (spec setup broken)")
        return
      end
      vim.cmd.split()
      second_win = vim.api.nvim_get_current_win()
      vim.cmd.lcd(vim.fn.fnameescape(alt_b))
      if not vim.wait(5000, function() return exists(alt_b .. "/.finished") end, 10) then
        fail("alternating-lcd: no export finished for the second window (spec setup broken)")
        return
      end
      vim.wait(300)

      vim.fn.delete(alt_a .. "/.finished")
      vim.fn.delete(alt_b .. "/.finished")
      local base_spawns = spawns(alt_a) + spawns(alt_b)

      -- Each switch changes cwd and fires DirChanged.
      local storm_ms = 1300
      for _ = 1, storm_ms / 100 do
        vim.wait(100)
        vim.cmd.wincmd("p")
      end

      if not (exists(alt_a .. "/.finished") or exists(alt_b .. "/.finished")) then
        fail("alternating-lcd: no export ran to completion while triggers kept arriving (killed or starved)")
      end
      -- Single-flight: back-to-back 0.3 s exports, plus slack for the first
      -- spawn and the one rerun a boundary trigger can queue.
      local storm_spawns = spawns(alt_a) + spawns(alt_b) - base_spawns
      local max_spawns = math.floor(storm_ms / 300) + 2
      if storm_spawns > max_spawns then
        fail(string.format(
          "alternating-lcd: %d exports spawned during a %d ms storm, expected at most %d (single-flight broken)",
          storm_spawns, storm_ms, max_spawns))
      end
      -- Let any in-flight export exit before the directories are deleted.
      vim.wait(800)
    end)
    if second_win and vim.api.nvim_win_is_valid(second_win) then
      vim.api.nvim_win_close(second_win, true)
    end
    if vim.api.nvim_win_is_valid(first_win) then
      vim.api.nvim_set_current_win(first_win)
    end
    -- Global :cd also drops the window-local directory.
    vim.cmd.cd(vim.fn.fnameescape(saved_cwd))
    if not inner_ok then
      error(inner_err, 0)
    end
  end)
  vim.g.direnv_interval = 20

  -- A trigger that lands after the debounce timer has set pending must clear
  -- it: the restarted timer decides alone, so the exit handler must not also
  -- rerun and skip the debounce.
  local ok13, err13 = pcall(function()
    local interval = 600
    local cleared = make_dir("pending-cleared", 1.2, {})
    vim.g.direnv_interval = interval

    vim.cmd.cd(vim.fn.fnameescape(cleared))
    if not vim.wait(5000, function() return exists(cleared .. "/.spawned") end, 10) then
      fail("pending-cleared: no export was spawned for :cd (spec setup broken)")
      return
    end

    -- Timeline from the spawn, leaving ~250-300 ms of slack to every ordering:
    -- this trigger's timer fires at ~650 ms and sets pending (job still
    -- running); the next trigger at ~900 ms restarts the debounce to ~1500 ms;
    -- the job exits at ~1200 ms, inside that interval.
    vim.wait(50)
    vim.cmd.DirenvExport()
    vim.wait(850)
    vim.cmd.DirenvExport()
    local second_trigger = vim.uv.hrtime()
    if exists(cleared .. "/.finished") then
      fail("pending-cleared: the first export finished before the second trigger (spec timing broken)")
      return
    end
    -- If the job outlived the restarted interval, the restarted timer would
    -- also spawn exactly 2 and the scenario would test nothing.
    vim.wait(5000, function() return exists(cleared .. "/.finished") end, 10)
    if (vim.uv.hrtime() - second_trigger) / 1e6 >= interval then
      fail("pending-cleared: the first export finished after the restarted debounce fired (spec timing broken)")
      return
    end

    -- The restarted timer's spawn (~600 ms after the second trigger) must run
    -- and finish before counting.
    vim.wait(2500)
    local count = #vim.fn.readfile(cleared .. "/.spawned")
    if count ~= 2 then
      fail(string.format(
        "pending-cleared: %d exports spawned, expected exactly 2 (a stale pending reran the export before the restarted debounce)",
        count))
    end
  end)
  vim.g.direnv_interval = 20

  vim.cmd.cd(vim.fn.fnameescape(saved_cwd))
  vim.fn.delete(base, "rf")
  if not ok then
    error(err, 0)
  end
  if not ok2 then
    error(err2, 0)
  end
  if not ok3 then
    error(err3, 0)
  end
  if not ok4 then
    error(err4, 0)
  end
  if not ok5 then
    error(err5, 0)
  end
  if not ok6 then
    error(err6, 0)
  end
  if not ok7 then
    error(err7, 0)
  end
  if not ok8 then
    error(err8, 0)
  end
  if not ok9 then
    error(err9, 0)
  end
  if not ok10 then
    error(err10, 0)
  end
  if not ok11 then
    error(err11, 0)
  end
  if not ok12 then
    error(err12, 0)
  end
  if not ok13 then
    error(err13, 0)
  end
end

local ok, err = pcall(run)
if not ok then
  fail("direnv-export spec crashed: " .. tostring(err))
end

if #failures > 0 then
  for _, failure in ipairs(failures) do
    io.stderr:write(failure .. "\n")
  end
  os.exit(1)
end

os.exit(0)
