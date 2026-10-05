-- Headless Neovim spec for the `direnv-lsp` flake check: when direnv.vim
-- fires `User DirenvLoaded`, LSP clients started with a different environment
-- must be restarted and reattach to listed buffers; clients whose environment
-- is unchanged must be left running.

-- copilot.lua starts its client from a vim.schedule queued at setup; disable
-- it before that runs. The restart under test would otherwise stop copilot,
-- and on macOS its exit (code 143) is reported on stderr, failing the check.
local copilot_ok, copilot = pcall(require, "copilot.command")
if copilot_ok then
  copilot.disable()
end

local failures = {}

local function fail(msg)
  table.insert(failures, msg)
end

local SERVER_NAME = "direnv-lsp-spec-server"
local FILETYPE = "direnvlspspec"

-- While `hold_initialize` is set, `initialize` replies are parked in
-- `held_initializes` so a client can be observed mid-handshake; the spec
-- releases them with `release_initializes()`.
local hold_initialize = false
local held_initializes = {}

local function release_initializes()
  hold_initialize = false
  local pending = held_initializes
  held_initializes = {}
  for _, reply in ipairs(pending) do
    reply()
  end
end

-- In-process server: no external binary needed.
local function fake_cmd(dispatchers)
  local closing = false
  local srv = {}
  function srv.request(method, _, callback)
    if method == "initialize" then
      local function reply()
        -- A held reply must not drive initialize-success (and LspAttach) on a
        -- client that was terminated while waiting.
        if closing then
          return
        end
        callback(nil, { capabilities = {} })
      end
      if hold_initialize then
        table.insert(held_initializes, reply)
      else
        reply()
      end
    elseif method == "shutdown" then
      -- Real servers answer asynchronously; replying inline hides races
      -- between client:stop() and anything scheduled after it.
      vim.schedule(function()
        callback(nil, nil)
      end)
    end
    return true, 1
  end
  function srv.notify(method)
    if method == "exit" then
      closing = true
      dispatchers.on_exit(0, 0)
    end
    return true
  end
  function srv.is_closing()
    return closing
  end
  function srv.terminate()
    closing = true
    dispatchers.on_exit(0, 0)
  end
  return srv
end

-- Sentinel for `vim.b.spec_root`: start the client without a root_dir.
local ROOTLESS = "<rootless>"
-- `vim.b.spec_folders` lists directories to pass as the client's workspace_folders.

vim.api.nvim_create_autocmd("FileType", {
  pattern = FILETYPE,
  callback = function(args)
    local root = vim.b[args.buf].spec_root or vim.fn.getcwd()
    local folders
    for _, dir in ipairs(vim.b[args.buf].spec_folders or {}) do
      folders = folders or {}
      table.insert(folders, { uri = vim.uri_from_fname(dir), name = dir })
    end
    vim.lsp.start({
      name = SERVER_NAME,
      cmd = fake_cmd,
      root_dir = root ~= ROOTLESS and root or nil,
      workspace_folders = folders,
    }, { bufnr = args.buf })
  end,
})

local function spec_clients(bufnr)
  return vim.lsp.get_clients({ name = SERVER_NAME, bufnr = bufnr })
end

local function run()
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_set_current_buf(buf)
  vim.bo[buf].filetype = FILETYPE

  if not vim.wait(5000, function() return #spec_clients(buf) == 1 end, 20) then
    fail("fake LSP client never attached to the listed buffer (spec setup broken)")
    return
  end
  local old = spec_clients(buf)[1]
  local old_id = old.id

  -- DirenvLoaded also fires at startup and on no-op re-exports; neither an
  -- identical environment nor a change to direnv's own DIRENV_* bookkeeping
  -- may restart anything.
  local function survives(label)
    vim.api.nvim_exec_autocmds("User", { pattern = "DirenvLoaded" })
    local gone = vim.wait(500, function()
      return old:is_stopped() or vim.lsp.get_client_by_id(old_id) == nil
    end, 20)
    if gone then
      fail(string.format("client %d was stopped by DirenvLoaded with %s", old_id, label))
      return false
    end
    local list = spec_clients(buf)
    if #list ~= 1 or list[1].id ~= old_id then
      fail(string.format("client set changed after DirenvLoaded with %s", label))
      return false
    end
    return true
  end

  if not survives("an unchanged environment") then
    return
  end
  local saved_diff = vim.env.DIRENV_DIFF
  vim.env.DIRENV_DIFF = "changed-bookkeeping"
  local bookkeeping_survived = survives("only DIRENV_DIFF changed")
  vim.env.DIRENV_DIFF = saved_diff
  if not bookkeeping_survived then
    return
  end

  vim.env.LSP_SPEC_EXPORTED = "changed"
  vim.api.nvim_exec_autocmds("User", { pattern = "DirenvLoaded" })

  local function reattached()
    local list = spec_clients(buf)
    return #list == 1 and list[1].id ~= old_id and not list[1]:is_stopped()
  end
  local restarted = vim.wait(5000, reattached, 20)

  if vim.lsp.get_client_by_id(old_id) ~= nil then
    fail(string.format("old client %d was not stopped after DirenvLoaded", old_id))
  end
  if not restarted then
    local ids = {}
    for _, c in ipairs(spec_clients(buf)) do
      table.insert(ids, tostring(c.id))
    end
    fail(string.format(
      "no new %s client attached after DirenvLoaded (old id %d, attached ids: [%s])",
      SERVER_NAME, old_id, table.concat(ids, ",")))
  end
end

-- `root` is the client's root_dir (default: cwd); `name` names the buffer;
-- `folders` lists the client's workspace folders.
local function new_spec_buffer(root, name, folders)
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_set_current_buf(buf)
  if name then
    vim.api.nvim_buf_set_name(buf, name)
  end
  vim.b[buf].spec_root = root
  vim.b[buf].spec_folders = folders
  vim.bo[buf].filetype = FILETYPE
  return buf
end

-- Scenarios share the server name and root_dir, so a leftover client would be
-- reused instead of a fresh one being spawned.
local function stop_all_spec_clients()
  release_initializes()
  -- A failed scenario can leave a restart's scheduled reattach pending; let it
  -- run now so it cannot spawn a client after the stop below.
  vim.wait(100)
  for _, client in ipairs(vim.lsp.get_clients({ name = SERVER_NAME, _uninitialized = true })) do
    client:stop(true)
  end
  if not vim.wait(5000, function()
    return #vim.lsp.get_clients({ name = SERVER_NAME, _uninitialized = true }) == 0
  end, 20) then
    fail("could not stop leftover spec clients between scenarios")
    return false
  end
  return true
end

local function wait_for_replacement(buf, old_id)
  return vim.wait(5000, function()
    local list = spec_clients(buf)
    return #list == 1 and list[1].id ~= old_id and not list[1]:is_stopped()
  end, 20)
end

-- A client spawned under the pre-direnv environment can still be answering
-- `initialize` when DirenvLoaded fires; it must be restarted all the same.
local function run_initializing_client()
  local label = "[client initializing during DirenvLoaded] "
  if not stop_all_spec_clients() then
    return
  end

  hold_initialize = true
  local buf = new_spec_buffer()

  if not vim.wait(5000, function()
    return #vim.lsp.get_clients({ name = SERVER_NAME, _uninitialized = true }) == 1
  end, 20) then
    fail(label .. "no client spawned for the new buffer (spec setup broken)")
    release_initializes()
    return
  end
  local old = vim.lsp.get_clients({ name = SERVER_NAME, _uninitialized = true })[1]
  local old_id = old.id
  if old.initialized or #held_initializes ~= 1 then
    fail(label .. "initialize was not held (spec setup broken)")
    release_initializes()
    return
  end

  vim.env.LSP_SPEC_EXPORTED = "changed-while-initializing"
  vim.api.nvim_exec_autocmds("User", { pattern = "DirenvLoaded" })
  -- Release only after DirenvLoaded, and for every client, so the replacement
  -- can initialize and attach normally.
  release_initializes()

  local replaced = wait_for_replacement(buf, old_id)
  if vim.lsp.get_client_by_id(old_id) ~= nil then
    fail(string.format(
      "%sclient %d spawned under the old environment was not stopped after DirenvLoaded",
      label, old_id))
  end
  if not replaced then
    local ids = {}
    for _, c in ipairs(spec_clients(buf)) do
      table.insert(ids, tostring(c.id))
    end
    fail(string.format(
      "%sno new %s client attached after DirenvLoaded (old id %d, attached ids: [%s])",
      label, SERVER_NAME, old_id, table.concat(ids, ",")))
  end
end

-- Unsetting an exported variable is an environment change too.
local function run_removed_variable()
  local label = "[removed variable] "
  if not stop_all_spec_clients() then
    return
  end

  local buf = new_spec_buffer()
  if not vim.wait(5000, function() return #spec_clients(buf) == 1 end, 20) then
    fail(label .. "fake LSP client never attached (spec setup broken)")
    return
  end
  local first_id = spec_clients(buf)[1].id

  vim.env.LSP_SPEC_REMOVED = "set"
  vim.api.nvim_exec_autocmds("User", { pattern = "DirenvLoaded" })
  if not wait_for_replacement(buf, first_id) then
    fail(string.format("%sno restart after the variable was added (old id %d)", label, first_id))
    return
  end
  local second_id = spec_clients(buf)[1].id

  vim.env.LSP_SPEC_REMOVED = nil
  vim.api.nvim_exec_autocmds("User", { pattern = "DirenvLoaded" })
  if not wait_for_replacement(buf, second_id) then
    fail(string.format("%sno restart after the variable was removed (old id %d)", label, second_id))
  end
end

-- direnv.vim re-exports on every DirChanged, so with tabs :tcd'd into different
-- projects each tab switch fires DirenvLoaded. A client may only be restarted
-- when the nearest .envrc above it is the one direnv just exported. The tree is
-- built here so the result does not depend on what lies above $TMPDIR (in the
-- Nix sandbox cwd and $TMPDIR are both /build).
--   base/p/.envrc  base/p/src/  base/p/svc/.envrc  base/plain/
local function run_envrc_scope(label, scenario)
  label = "[" .. label .. "] "
  if not stop_all_spec_clients() then
    return
  end

  local saved_cwd = vim.fn.getcwd()
  local saved_env = vim.env.LSP_SPEC_SCOPE
  -- realpath: macOS tempdirs sit behind a symlink and cwd reports the resolved path.
  local base = vim.fn.tempname() .. "-scope"
  vim.fn.mkdir(base .. "/p/src", "p")
  vim.fn.mkdir(base .. "/p/svc", "p")
  vim.fn.mkdir(base .. "/plain", "p")
  vim.fn.writefile({}, base .. "/p/.envrc")
  vim.fn.writefile({}, base .. "/p/svc/.envrc")
  base = vim.uv.fs_realpath(base)

  local ok, err = pcall(function()
    local function cd(dir)
      vim.cmd.cd(vim.fn.fnameescape(dir))
    end
    local function fire()
      vim.api.nvim_exec_autocmds("User", { pattern = "DirenvLoaded" })
    end

    -- Sync the module's remembered spawn environment with the one set here.
    cd(base .. "/plain")
    vim.env.LSP_SPEC_SCOPE = "x"
    fire()

    local function attached(buf)
      if not vim.wait(5000, function() return #spec_clients(buf) == 1 end, 20) then
        fail(label .. "fake LSP client never attached (spec setup broken)")
        return nil
      end
      return spec_clients(buf)[1]
    end

    local function stopped(old, old_id)
      return vim.wait(500, function()
        return old:is_stopped() or vim.lsp.get_client_by_id(old_id) == nil
      end, 20)
    end

    scenario({
      label = label,
      base = base,
      cd = cd,
      fire = fire,
      attached = attached,
      -- Fires DirenvLoaded and fails if the client was stopped or replaced.
      assert_survives = function(old, buf, when)
        fire()
        if stopped(old, old.id) or spec_clients(buf)[1] ~= old then
          fail(string.format("%sclient %d (root %s) was restarted %s",
            label, old.id, old.root_dir, when))
          return false
        end
        return true
      end,
      assert_restarts = function(old, buf, when)
        fire()
        if not wait_for_replacement(buf, old.id) then
          fail(string.format("%sclient %d (root %s) was not restarted %s",
            label, old.id, tostring(old.root_dir), when))
          return false
        end
        return true
      end,
    })
  end)

  vim.cmd.cd(vim.fn.fnameescape(saved_cwd))
  vim.env.LSP_SPEC_SCOPE = saved_env
  vim.fn.delete(base, "rf")
  if not ok then
    error(err, 0)
  end
end

-- cwd below the client's root resolves to the same .envrc.
local function run_descendant_cwd()
  run_envrc_scope("cwd below client root", function(t)
    local buf = new_spec_buffer(t.base .. "/p")
    local old = t.attached(buf)
    if not old then return end
    t.cd(t.base .. "/p/src")
    vim.env.LSP_SPEC_SCOPE = "y"
    t.assert_restarts(old, buf, "after DirenvLoaded in a subdirectory of its root")
  end)
end

-- Switching tabs between a project and a directory without .envrc fires
-- DirenvLoaded with each tab's environment; the project's client must neither
-- be restarted with the bare environment nor again when switching back. Real
-- tabs with :tcd, since the cwd follows the current tab.
local function run_tab_switch()
  run_envrc_scope("tab switch", function(t)
    local project_tab = vim.api.nvim_get_current_tabpage()
    local ok, err = pcall(function()
      vim.cmd.tcd(vim.fn.fnameescape(t.base .. "/p"))
      local buf = new_spec_buffer(t.base .. "/p")
      local old = t.attached(buf)
      if not old then return end

      vim.cmd.tabnew()
      vim.cmd.tcd(vim.fn.fnameescape(t.base .. "/plain"))
      vim.env.LSP_SPEC_SCOPE = "y"
      if not t.assert_survives(old, buf, "by DirenvLoaded fired for a directory without .envrc") then
        return
      end
      vim.api.nvim_set_current_tabpage(project_tab)
      if vim.fn.getcwd() ~= t.base .. "/p" then
        fail(t.label .. "tab-local cwd was not restored on switching back (spec setup broken)")
        return
      end
      vim.env.LSP_SPEC_SCOPE = "x"
      t.assert_survives(old, buf, "when switching back to an environment equal to its own")
    end)
    -- Leave one tab; :cd in run_envrc_scope's cleanup then resets this tab's cwd.
    vim.api.nvim_set_current_tabpage(project_tab)
    vim.cmd.tabonly({ bang = true })
    if not ok then
      error(err, 0)
    end
  end)
end

-- A nested .envrc is a different environment than the one above it.
local function run_nested_envrc()
  run_envrc_scope("nested .envrc", function(t)
    local buf = new_spec_buffer(t.base .. "/p/svc")
    local old = t.attached(buf)
    if not old then return end
    t.cd(t.base .. "/p")
    vim.env.LSP_SPEC_SCOPE = "y"
    t.assert_survives(old, buf, "by DirenvLoaded for the parent .envrc")
  end)
end

-- Clients without a root_dir are placed by their buffers' paths.
local function run_rootless_client()
  run_envrc_scope("rootless client", function(t)
    local buf = new_spec_buffer(ROOTLESS, t.base .. "/p/file.txt")
    local old = t.attached(buf)
    if not old then return end
    if old.root_dir ~= nil then
      fail(t.label .. "client has a root_dir (spec setup broken)")
      return
    end
    t.cd(t.base .. "/p")
    vim.env.LSP_SPEC_SCOPE = "y"
    t.assert_restarts(old, buf, "after DirenvLoaded for its buffer's .envrc")
  end)
end

-- A buffer such as fugitive:// or oil:// has no directory to place the client
-- by; it must not be mistaken for the cwd.
local function run_rootless_uri_buffer()
  run_envrc_scope("rootless client on a URI buffer", function(t)
    local buf = new_spec_buffer(ROOTLESS, "fake://host/file.txt")
    local old = t.attached(buf)
    if not old then return end
    if old.root_dir ~= nil then
      fail(t.label .. "client has a root_dir (spec setup broken)")
      return
    end
    t.cd(t.base .. "/p")
    vim.env.LSP_SPEC_SCOPE = "y"
    t.assert_survives(old, buf, "by DirenvLoaded although it is only attached to a URI buffer")
  end)
end

-- A secondary workspace folder under the cwd's .envrc puts the client in scope
-- even when its root_dir lies elsewhere.
local function run_secondary_workspace_folder()
  run_envrc_scope("secondary workspace folder", function(t)
    local buf = new_spec_buffer(t.base .. "/plain", nil, { t.base .. "/plain", t.base .. "/p" })
    local old = t.attached(buf)
    if not old then return end
    t.cd(t.base .. "/p")
    vim.env.LSP_SPEC_SCOPE = "y"
    t.assert_restarts(old, buf, "after DirenvLoaded for its secondary workspace folder")
  end)
end

for _, scenario in ipairs({
  { "main", run },
  { "initializing-client", run_initializing_client },
  { "removed-variable", run_removed_variable },
  { "descendant-cwd", run_descendant_cwd },
  { "tab-switch", run_tab_switch },
  { "nested-envrc", run_nested_envrc },
  { "rootless-client", run_rootless_client },
  { "rootless-uri-buffer", run_rootless_uri_buffer },
  { "secondary-workspace-folder", run_secondary_workspace_folder },
}) do
  local ok, err = pcall(scenario[2])
  if not ok then
    fail(string.format("direnv-lsp spec crashed in %s scenario: %s", scenario[1], tostring(err)))
  end
end

if #failures > 0 then
  for _, failure in ipairs(failures) do
    io.stderr:write(failure .. "\n")
  end
  os.exit(1)
end

os.exit(0)
