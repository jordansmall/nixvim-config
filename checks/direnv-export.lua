-- Headless Neovim spec for the `direnv-export` flake check: a `direnv export
-- vim` job superseded by a newer one (e.g. `:cd /q` then `:cd /p` back before
-- the first finished) must not apply its output or fire `User DirenvLoaded`,
-- because the environment it was computed for is no longer the current one.
--
-- direnv is replaced by a fake command whose per-directory delay and output
-- the spec controls through `.delay` and `.out` files. It writes `.finished`
-- only after its delay, which shows whether a superseded job was killed, and
-- appends a line to `.spawned` per run so spawns can be counted.

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

    if exists(q .. "/.finished") then
      fail("a superseded export was not killed: it ran to completion")
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
    -- Back to p2 while q2's export runs; the trigger kills it before p2's
    -- has spawned.
    vim.cmd.cd(vim.fn.fnameescape(p2))
    if not vim.wait(5000, function() return #seen >= 1 end, 10) then
      fail("debounce-window: no DirenvLoaded after returning to the first directory")
      return
    end
    vim.wait(1000)

    if exists(q2 .. "/.finished") then
      fail("debounce-window: a superseded export was not killed: it ran to completion")
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
  -- supersedes it. That queued export is stale and must not spawn: it would
  -- overwrite the tracked job (so it can no longer be killed), and the
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
