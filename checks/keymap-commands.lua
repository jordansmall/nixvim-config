-- Headless Neovim spec for the `keymap-commands` flake check: every mapping
-- whose right-hand side runs an Ex command must name a command that exists.
-- Catches keymaps left pointing at a command/global a refactor removed.

local function rhs_command(rhs)
  if not rhs or rhs == "" then
    return nil
  end
  local cmd = rhs:match("^<[Cc][Mm][Dd]>(.-)<[Cc][Rr]>$")
  if not cmd then
    cmd = rhs:match("^:(.-)<[Cc][Rr]>$")
  end
  if cmd then
    -- Strip leading key-notation tokens (e.g. <C-U>) that remap plugins
    -- prepend before the Ex command itself, such as vim-tmux-navigator's
    -- `:<C-U>TmuxNavigatePrevious<CR>`.
    local stripped = cmd:gsub("^<[^<>]+>", "")
    while stripped ~= cmd do
      cmd = stripped
      stripped = cmd:gsub("^<[^<>]+>", "")
    end
  end
  return cmd
end

local function lua_global_call(cmdtext)
  return cmdtext:match("^lua%s+([%a_][%w_]*)%s*%(")
end

local function check_mapping(failures, mode, map)
  local cmdtext = rhs_command(map.rhs)
  if not cmdtext then
    return
  end
  local global_name = lua_global_call(cmdtext)
  if global_name then
    if _G[global_name] == nil then
      table.insert(failures, string.format(
        "%s %s -> <cmd>lua %s()<cr> calls undefined global %q",
        mode, map.lhs, global_name, global_name))
    end
  else
    local command_name = cmdtext:match("^(%S+)")
    -- Punctuation-only Ex commands (&, &&, <, >, @, #, =, !, ~, ...)
    -- are part of Vim's command grammar, not named commands a refactor
    -- can remove; exists() doesn't resolve them reliably, so skip them.
    if command_name and command_name:match("^%a") and vim.fn.exists(":" .. command_name) == 0 then
      table.insert(failures, string.format(
        "%s %s -> %q is not a known command", mode, map.lhs, command_name))
    end
  end
end

local function check_keymaps()
  local failures = {}
  for _, mode in ipairs({ "n", "i", "v", "x", "s", "o", "t", "c" }) do
    for _, map in ipairs(vim.api.nvim_get_keymap(mode)) do
      -- Scoped per-mapping so one unexpected error is reported alongside
      -- the other findings instead of discarding the whole walk.
      local map_ok, map_err = pcall(check_mapping, failures, mode, map)
      if not map_ok then
        table.insert(failures, string.format(
          "%s %s -> error while checking: %s", mode, map.lhs, tostring(map_err)))
      end
    end
  end
  return failures
end

-- Proves check_keymaps() actually flags bad rhs targets before trusting it
-- to validate the real keymaps below; temp maps are removed either way.
local function run_self_test()
  local cases = {
    { lhs = "<Plug>KeymapCommandsSelfTestBogusCmd",
      rhs = "<cmd>KeymapCommandsSelfTestNoSuchCommand12345<cr>", expect_flagged = true },
    { lhs = "<Plug>KeymapCommandsSelfTestGoodCmd",
      rhs = "<cmd>echo<cr>", expect_flagged = false },
    { lhs = "<Plug>KeymapCommandsSelfTestBogusGlobal",
      rhs = "<cmd>lua KeymapCommandsSelfTestUndefinedGlobal12345()<cr>", expect_flagged = true },
    { lhs = "<Plug>KeymapCommandsSelfTestBareColon",
      rhs = ":KeymapCommandsSelfTestNoSuchCommand54321<cr>", expect_flagged = true },
    { lhs = "<Plug>KeymapCommandsSelfTestColonCU",
      rhs = ":<C-U>KeymapCommandsSelfTestNoSuchCommand54321<cr>", expect_flagged = true },
    { lhs = "<Plug>KeymapCommandsSelfTestColonGoodCmd",
      rhs = ":echo<cr>", expect_flagged = false },
  }

  for _, case in ipairs(cases) do
    vim.api.nvim_set_keymap("n", case.lhs, case.rhs, {})
  end

  local self_ok, self_failures = pcall(check_keymaps)

  for _, case in ipairs(cases) do
    pcall(vim.api.nvim_del_keymap, "n", case.lhs)
  end

  if not self_ok then
    io.stderr:write("keymap-commands self-test crashed: " .. tostring(self_failures) .. "\n")
    os.exit(1)
  end

  for _, case in ipairs(cases) do
    local flagged = false
    for _, failure in ipairs(self_failures) do
      if failure:find(case.lhs, 1, true) then
        flagged = true
        break
      end
    end
    if flagged ~= case.expect_flagged then
      io.stderr:write(string.format(
        "keymap-commands self-test failed for %s: expected flagged=%s, got flagged=%s\n",
        case.lhs, tostring(case.expect_flagged), tostring(flagged)))
      os.exit(1)
    end
  end
end

run_self_test()

local ok, failures = pcall(check_keymaps)
if not ok then
  io.stderr:write("keymap-commands spec crashed: " .. tostring(failures) .. "\n")
  os.exit(1)
end

if #failures > 0 then
  for _, failure in ipairs(failures) do
    io.stderr:write(failure .. "\n")
  end
  io.stderr:write(string.format("%d keymap(s) reference missing commands\n", #failures))
  os.exit(1)
end

os.exit(0)
