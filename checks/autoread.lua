-- Headless Neovim spec for the `autoread` flake check: external file changes
-- are reloaded per event (FocusGained: every buffer; BufEnter: the entered
-- buffer; CursorHold/CursorHoldI: the current tab page only), nothing is
-- checked while in command-line mode, and each reload is announced via
-- vim.notify.

local failures = {}

-- Headless vim.notify writes to stderr, which the check treats as failure.
local notifications = {}
vim.notify = function(msg, level, opts)
  table.insert(notifications, { msg = msg, level = level, opts = opts })
end

local function fail(msg)
  table.insert(failures, msg)
end

local function write(path, lines)
  local f = assert(io.open(path, "w"))
  f:write(table.concat(lines, "\n") .. "\n")
  f:close()
end

-- Two file-backed buffers: A in the current window, B in a window on another
-- tab page (bare `:checktime` skips buffers that are in no window). Both files
-- are then rewritten with a different size, so the change is detected
-- regardless of mtime granularity.
local function setup_buffers()
  local pa, pb = vim.fn.tempname(), vim.fn.tempname()
  write(pa, { "a" })
  write(pb, { "b" })
  vim.cmd("edit " .. vim.fn.fnameescape(pb))
  local b = vim.api.nvim_get_current_buf()
  vim.cmd("edit " .. vim.fn.fnameescape(pa))
  local a = vim.api.nvim_get_current_buf()
  vim.cmd("tabnew")
  vim.cmd("buffer " .. b)
  vim.cmd("tabfirst")
  write(pa, { "a changed", "more" })
  write(pb, { "b changed", "more" })
  return a, b
end

local function first_line(buf)
  return vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
end

local function check_notified(event, buf)
  local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":~:.")
  for _, call in ipairs(notifications) do
    if call.msg == name .. " reloaded from disk" and call.opts and call.opts.title == "Buffer auto-reloaded" then
      return
    end
  end
  fail(event .. " reload did not notify \"<file> reloaded from disk\"")
end

-- Fires `event` from inside command-line mode (via a temporary <F2> mapping) and
-- returns the mode() the autocmd saw, so a scenario cannot pass vacuously.
local function doautocmd_in_cmdline(event)
  local seen_mode
  vim.keymap.set("c", "<F2>", function()
    seen_mode = vim.fn.mode()
    vim.cmd("doautocmd " .. event)
  end)
  -- `silent`: headless nvim otherwise echoes the typed ":" to stderr.
  vim.cmd("silent call feedkeys(\":\\<F2>\\<C-c>\", \"xt\")")
  vim.keymap.del("c", "<F2>")
  return seen_mode
end

-- Each scenario fires its event in `fire`, then `verify` runs after the main
-- loop has had a turn: a bare `:checktime` issued from an autocmd is postponed
-- to the main loop, which never spins while this script runs synchronously.
-- A scenario with `ready` is polled until it holds (or ~2s pass) before
-- verifying: the verify timer can land in the same event batch as `fire`,
-- ahead of the postponed check (seen on aarch64-darwin).
local scenarios = {
  {
    name = "cursorhold",
    fire = function()
      notifications = {}
      local a, b = setup_buffers()
      vim.cmd("doautocmd CursorHold")
      return { a = a, b = b }
    end,
    verify = function(ctx)
      if first_line(ctx.a) ~= "a changed" then
        fail("CursorHold did not reload the visible buffer")
      end
      if first_line(ctx.b) ~= "b" then
        fail("CursorHold reloaded a buffer outside the current tab page")
      end
      check_notified("CursorHold", ctx.a)
    end,
  },
  {
    name = "focusgained",
    fire = function()
      notifications = {}
      local a, b = setup_buffers()
      vim.cmd("doautocmd FocusGained")
      return { a = a, b = b }
    end,
    ready = function(ctx)
      return first_line(ctx.a) == "a changed" and first_line(ctx.b) == "b changed"
    end,
    verify = function(ctx)
      if first_line(ctx.a) ~= "a changed" then
        fail("FocusGained did not reload the visible buffer")
      end
      if first_line(ctx.b) ~= "b changed" then
        fail("FocusGained did not reload the buffer in another tab page")
      end
      check_notified("FocusGained", ctx.a)
    end,
  },
  {
    name = "bufenter",
    fire = function()
      notifications = {}
      local a, b = setup_buffers()
      vim.cmd("doautocmd BufEnter")
      return { a = a, b = b }
    end,
    verify = function(ctx)
      if first_line(ctx.a) ~= "a changed" then
        fail("BufEnter did not reload the entered buffer")
      end
      if first_line(ctx.b) ~= "b" then
        fail("BufEnter reloaded a buffer other than the entered one")
      end
      check_notified("BufEnter", ctx.a)
    end,
  },
  {
    name = "cursorholdi",
    fire = function()
      notifications = {}
      local a, b = setup_buffers()
      vim.cmd("doautocmd CursorHoldI")
      return { a = a, b = b }
    end,
    verify = function(ctx)
      if first_line(ctx.a) ~= "a changed" then
        fail("CursorHoldI did not reload the visible buffer")
      end
      if first_line(ctx.b) ~= "b" then
        fail("CursorHoldI reloaded a buffer outside the current tab page")
      end
      check_notified("CursorHoldI", ctx.a)
    end,
  },
  {
    name = "cursorhold-cmdline",
    fire = function()
      notifications = {}
      local a, b = setup_buffers()
      local mode = doautocmd_in_cmdline("CursorHold")
      return { a = a, b = b, mode = mode }
    end,
    verify = function(ctx)
      if ctx.mode ~= "c" then
        fail("cursorhold-cmdline scenario did not run in command-line mode (mode() = " .. tostring(ctx.mode) .. ")")
      end
      if first_line(ctx.a) ~= "a" then
        fail("CursorHold reloaded a buffer while in command-line mode")
      end
    end,
  },
  {
    name = "bufenter-cmdline",
    fire = function()
      notifications = {}
      local a, b = setup_buffers()
      local mode = doautocmd_in_cmdline("BufEnter")
      return { a = a, b = b, mode = mode }
    end,
    verify = function(ctx)
      if ctx.mode ~= "c" then
        fail("bufenter-cmdline scenario did not run in command-line mode (mode() = " .. tostring(ctx.mode) .. ")")
      end
      if first_line(ctx.a) ~= "a" then
        fail("BufEnter reloaded a buffer while in command-line mode")
      end
    end,
  },
}

local function finish()
  if #failures > 0 then
    for _, failure in ipairs(failures) do
      io.stderr:write(failure .. "\n")
    end
    os.exit(1)
  end

  os.exit(0)
end

local function run(index)
  local scenario = scenarios[index]
  if not scenario then
    finish()
    return
  end

  local ok, ctx = pcall(scenario.fire)
  if not ok then
    fail(string.format("autoread spec crashed firing %s scenario: %s", scenario.name, tostring(ctx)))
    ctx = nil
  end

  local attempts = 0
  local function settle()
    attempts = attempts + 1
    if ctx and scenario.ready and attempts < 40 and not scenario.ready(ctx) then
      vim.defer_fn(settle, 50)
      return
    end
    if ctx then
      local verified, err = pcall(scenario.verify, ctx)
      if not verified then
        fail(string.format("autoread spec crashed verifying %s scenario: %s", scenario.name, tostring(err)))
      end
    end
    run(index + 1)
  end

  vim.defer_fn(settle, 50)
end

-- Safety net so a stalled main loop fails the check instead of hanging it.
vim.defer_fn(function()
  io.stderr:write("autoread spec timed out\n")
  os.exit(1)
end, 5000)

run(1)
