-- Headless Neovim spec for the `multiverse` flake check: setup() registers
-- the Multiverse commands, the <leader>p keymaps target them, the terminal
-- keymaps (<leader>t in normal mode only, <C-Return> in normal and terminal
-- mode) toggle MultiverseTerminal, zellij (which MultiverseTerminal shells
-- out to) is on PATH, and the project switcher, project.nvim,
-- persistence.nvim, scope.nvim and toggleterm are gone.

local failures = {}

local function fail(msg)
  table.insert(failures, msg)
end

local function check_commands()
  for _, name in ipairs({
    "MultiverseList",
    "MultiverseAdd",
    "MultiverseRemove",
    "MultiverseAlternate",
    "MultiverseLog",
    "MultiverseTerminal",
  }) do
    -- exists() returns 2 for user-defined commands, 0 when missing.
    if vim.fn.exists(":" .. name) ~= 2 then
      fail(string.format("command :%s does not exist", name))
    end
  end

  if vim.fn.executable("zellij") ~= 1 then
    fail("zellij is not on Neovim's PATH")
  end
end

local function mapping(lhs, mode)
  return vim.fn.maparg(lhs, mode or "n", false, true)
end

-- which-key may install its own placeholder mapping on a group prefix.
local function is_which_key_trigger(map)
  return (map.desc or ""):find("which-key-trigger", 1, true) ~= nil
end

local function check_keymaps()
  for lhs, expected in pairs({
    ["<leader>pp"] = "<cmd>multiverselist<cr>",
    ["<leader>pa"] = "<cmd>multiverseadd<cr>",
    -- Prompt mapping: no <CR>, so the user can type the universe name.
    ["<leader>pr"] = ":multiverseremove ",
    ["<leader>p<tab>"] = "<cmd>multiversealternate<cr>",
    ["<leader>pl"] = "<cmd>multiverselog<cr>",
  }) do
    local map = mapping(lhs)
    if vim.tbl_isempty(map) then
      fail(string.format("keymap %s is not mapped", lhs))
    elseif (map.rhs or ""):lower() ~= expected then
      fail(string.format("keymap %s rhs is %q, expected %q (case-insensitive)", lhs, map.rhs or "", expected))
    end
  end

  for lhs, modes in pairs({
    ["<leader>t"] = { n = "<cmd>multiverseterminal<cr>" },
    ["<C-Return>"] = {
      n = "<cmd>multiverseterminal<cr>",
      t = "<c-\\><c-n><cmd>multiverseterminal<cr>",
    },
  }) do
    for mode, expected in pairs(modes) do
      local map = mapping(lhs, mode)
      if vim.tbl_isempty(map) then
        fail(string.format("keymap %s is not mapped in mode %s", lhs, mode))
      elseif (map.rhs or ""):lower() ~= expected then
        fail(string.format("keymap %s (mode %s) rhs is %q, expected %q (case-insensitive)", lhs, mode, map.rhs or "", expected))
      end
    end
  end

  -- A Space-prefixed terminal-mode map makes Neovim hold every typed space for
  -- timeoutlen and swallow fast-typed " t" (git tag, npm test).
  if not vim.tbl_isempty(mapping("<leader>t", "t")) then
    fail("keymap <leader>t must not be mapped in terminal mode")
  end

  for _, lhs in ipairs({ "<leader>fp", "<leader>p" }) do
    local map = mapping(lhs)
    if not vim.tbl_isempty(map) and not is_which_key_trigger(map) then
      fail(string.format("keymap %s should be unmapped but maps to %q", lhs, map.rhs or ""))
    end
  end
end

local function check_removed()
  for _, name in ipairs({ "ProjectPicker", "ProjectAdd", "ProjectRemove" }) do
    if vim.fn.exists(":" .. name) ~= 0 then
      fail(string.format("command :%s should have been removed", name))
    end
  end

  for _, name in ipairs({ "project_nvim", "persistence", "scope", "toggleterm" }) do
    for _, pattern in ipairs({ "lua/" .. name .. ".lua", "lua/" .. name .. "/init.lua" }) do
      if #vim.api.nvim_get_runtime_file(pattern, false) > 0 then
        fail(string.format("lua module %q is still on the runtimepath (%s)", name, pattern))
      end
    end
  end

  if _G.ToggleProjectTerm ~= nil then
    fail("ToggleProjectTerm should have been removed")
  end

  local default = vim.api.nvim_get_option_info2("sessionoptions", {}).default
  if vim.o.sessionoptions ~= default then
    fail(string.format("sessionoptions is %q, expected built-in default %q", vim.o.sessionoptions, default))
  end

  -- direnv.vim legitimately uses DirChanged, so match only the removed
  -- neo-tree re-root autocmd, by its desc.
  for _, autocmd in ipairs(vim.api.nvim_get_autocmds({ event = "DirChanged" })) do
    if (autocmd.desc or ""):find("Re-root neo-tree", 1, true) then
      fail("neo-tree DirChanged re-root autocmd should have been removed")
    end
  end
end

for _, scenario in ipairs({
  { "commands", check_commands },
  { "keymaps", check_keymaps },
  { "removed", check_removed },
}) do
  local ok, err = pcall(scenario[2])
  if not ok then
    fail(string.format("multiverse spec crashed in %s scenario: %s", scenario[1], tostring(err)))
  end
end

if #failures > 0 then
  for _, failure in ipairs(failures) do
    io.stderr:write(failure .. "\n")
  end
  os.exit(1)
end

os.exit(0)
