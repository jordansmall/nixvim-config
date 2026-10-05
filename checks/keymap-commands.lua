-- Headless Neovim spec for the `keymap-commands` flake check: every mapping
-- whose right-hand side runs an Ex command must name a command that exists.
-- Catches keymaps left pointing at a command a refactor removed, and flags
-- any `<cmd>lua Name()<cr>` rhs outright (ADR 0002: keymaps bind to user
-- commands, never to Lua globals), whether or not the global exists.

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
    -- nvim_get_keymap escapes a literal `<` as `<lt>`, which would turn a
    -- `'<,'>` range into `'<lt>,'>` and parse as `:ltag`.
    cmd = cmd:gsub("<[Ll][Tt]>", "<")
  end
  return cmd
end

-- Index just past the unescaped `delim` that closes a field starting at `i`,
-- or nil when the field is unterminated.
local function skip_field(text, i, delim)
  while i <= #text do
    local c = text:sub(i, i)
    if c == "\\" then
      i = i + 2
    elseif c == delim then
      return i + 1
    else
      i = i + 1
    end
  end
  return nil
end

local CHAR_CLASSES = {
  alnum = true, alpha = true, blank = true, cntrl = true, digit = true,
  graph = true, lower = true, print = true, punct = true, space = true,
  upper = true, xdigit = true, ["return"] = true, tab = true, escape = true,
  backspace = true, ident = true, keyword = true, fname = true,
}

-- Mirrors nvim's skip_anyof: `i` is just past the `[`; returns the index of
-- the closing `]`, or #text + 1 when the collection is unterminated.
local function skip_collection(text, i)
  local function at(n)
    return text:sub(n, n)
  end
  if at(i) == "^" then
    i = i + 1
  end
  if at(i) == "]" or at(i) == "-" then
    i = i + 1
  end
  while i <= #text and at(i) ~= "]" do
    local c = at(i)
    if c == "-" then
      i = i + 1
      if i <= #text and at(i) ~= "]" then
        i = i + 1
      end
    elseif c == "\\" and i < #text and ("]^-n\\nrtebdoxuU"):find(at(i + 1), 1, true) then
      i = i + 2
    elseif c == "[" then
      local name = text:match("^%[:(%a+):%]", i)
      local other = text:match("^%[([=.]).[=.]%]", i)
      if name and CHAR_CLASSES[name] then
        i = i + #name + 4
      elseif other and at(i + 3) == other then
        i = i + 5
      else
        i = i + 1
      end
    else
      i = i + 1
    end
  end
  return i
end

-- Like skip_field for a regex pattern (mirrors nvim's skip_regexp): a `[...]`
-- collection may hold the delimiter, and an unterminated one swallows the rest.
local function skip_pattern(text, i, delim)
  -- skip_regexp tracks only `\v` and `\V` (not `\m`/`\M`).
  -- Levels: 1 = \V, 2 = \M, 3 = on (default), 4 = \v.
  local magic = 3
  while i <= #text do
    local c = text:sub(i, i)
    local next_char = text:sub(i + 1, i + 1)
    if c == delim then
      return i + 1
    elseif (c == "[" and magic >= 3) or (c == "\\" and next_char == "[" and magic <= 2) then
      -- For `\[` this starts at the `[` itself, as nvim's skip_anyof does.
      i = skip_collection(text, i + 1)
      if i > #text then
        return nil
      end
      i = i + 1
    elseif c == "\\" and next_char ~= "" then
      if next_char == "v" then
        magic = 4
      elseif next_char == "V" then
        magic = 1
      end
      i = i + 2
    else
      i = i + 1
    end
  end
  return nil
end

-- Returns the index just past a leading range (1 when there is none).
local function range_end(segment)
  local i = 1
  while true do
    local c = segment:sub(i, i)
    if c == "'" then
      i = i + 2
    elseif c == "/" or c == "?" then
      -- An unterminated pattern runs to the end of the segment.
      i = skip_pattern(segment, i + 1, c) or (#segment + 1)
    elseif c == "\\" and segment:sub(i + 1, i + 1):match("[/?&]") then
      i = i + 2
    elseif c ~= "" and c:match("[%d%s.$%%,;+*-]") then
      i = i + 1
    else
      break
    end
  end
  return i
end

local function after_first_bar(text, from)
  local bar = text:find("|", from or 1, true)
  return bar and text:sub(bar + 1) or nil
end

-- Returns the text after the first `|` outside a string, skipping `||`.
local function after_expr(args)
  local i = 1
  while i <= #args do
    local c = args:sub(i, i)
    if c == "'" then
      -- `''` inside a string is an escaped quote, not the end.
      local close = args:find("'", i + 1, true)
      while close and args:sub(close + 1, close + 1) == "'" do
        close = args:find("'", close + 2, true)
      end
      if not close then
        return nil
      end
      i = close + 1
    elseif c == '"' then
      i = i + 1
      while i <= #args and args:sub(i, i) ~= '"' do
        i = i + (args:sub(i, i) == "\\" and 2 or 1)
      end
      i = i + 1
    elseif c == "|" then
      if args:sub(i + 1, i + 1) == "|" then
        i = i + 2
      else
        return args:sub(i + 1)
      end
    else
      i = i + 1
    end
  end
  return nil
end

-- Returns nil when an unterminated replacement swallows the bar at runtime.
local function after_substitute(args)
  local delim = args:sub(1, 1)
  if delim == "" or delim:match('[%w\\"|%s]') then
    return after_first_bar(args)
  end
  local pattern_end = skip_pattern(args, 2, delim)
  local replacement_end = pattern_end and skip_field(args, pattern_end, delim)
  if not replacement_end then
    return nil
  end
  -- do_sub parses flags and a count; a `"` after them is a comment.
  local rest = args:sub(replacement_end):match("^&?[cegiInp#lr]*%d*%s*(.*)$")
  if rest:sub(1, 1) == '"' then
    return nil
  end
  return after_first_bar(rest)
end

local function after_sort(args)
  local i = 1
  while i <= #args do
    local c = args:sub(i, i)
    if c == "|" then
      return args:sub(i + 1)
    elseif c == '"' then
      -- A comment runs to the end of the line.
      return nil
    elseif c:match("[%a%s]") then
      i = i + 1
    else
      -- nvim tests for the bar before it takes a pattern delimiter.
      i = skip_pattern(args, i + 1, c)
      if not i then
        return nil
      end
    end
  end
  return nil
end

local function after_match(args)
  local first = args:sub(1, 1)
  if first == "" then
    return nil
  end
  -- ex_match ends at a leading terminator (`|` or `"`, which is no comment
  -- here), or at `none` followed by white space, a bar, a quote or the end,
  -- before it looks for a group or pattern.
  if first == "|" or first == '"' then
    return after_first_bar(args)
  end
  if args:sub(1, 4):lower() == "none" and args:sub(5, 5):match('^[%s|"]?$') then
    return after_first_bar(args)
  end
  local rest = args:match("^%S*%s*(.*)$")
  local pattern_end = rest ~= "" and skip_pattern(rest, 2, rest:sub(1, 1))
  if not pattern_end then
    return nil
  end
  return after_first_bar(rest, pattern_end)
end

-- ex_help ends at the first bar followed by text other than another bar.
local function after_help(args)
  local bar = args:find("|[^|]")
  return bar and args:sub(bar + 1) or nil
end

-- Returns nil when the pattern is unterminated.
local function after_catch(args)
  local first = args:sub(1, 1)
  if first == "" or first == "|" or first == '"' then
    return after_first_bar(args)
  end
  local pattern_end = skip_pattern(args, 2, first)
  return pattern_end and after_first_bar(args, pattern_end)
end

-- ex_wincmd takes one argument char (two after `g` or Ctrl-G), which may itself
-- be `|`; only a bar following it separates commands, anything else stops.
local function after_wincmd(args)
  local first = args:sub(1, 1)
  local width = (first == "g" or first == "\7") and 2 or 1
  return args:sub(width + 1):match("^%s*|(.*)$")
end

-- Commands that find their own trailing `|` at runtime have no EX_TRLBAR, so
-- nvim_parse_cmd returns no nextcmd for them. Each splitter takes the raw args
-- and returns the text after the separating bar, or nil to stop the walk. The
-- walk also stops at any command missing here; syntax/ownsyntax (sub-command
-- grammar) and the `:function` listing forms are deliberately unmodelled.
local OWN_BAR_COMMANDS = {
  substitute = after_substitute,
  sort = after_sort,
  match = after_match,
  ["&"] = after_first_bar,
  help = after_help,
  catch = after_catch,
  ["~"] = after_first_bar,
  wincmd = after_wincmd,
}
-- These parse their argument as an expression.
for _, name in ipairs({
  "call", "echo", "echon", "echomsg", "echoerr", "execute", "eval", "let",
  "const", "unlet", "lockvar", "unlockvar", "return", "throw", "if", "elseif",
  "while", "for", "delfunction", "cexpr", "cgetexpr", "caddexpr", "lexpr",
  "lgetexpr", "laddexpr",
}) do
  OWN_BAR_COMMANDS[name] = after_expr
end

-- nvim_parse_cmd unescapes `\\` and `\ ` in args, which throws off the
-- splitters' escape and quote tracking, so recover the raw argument text: the
-- longest segment suffix that nvim re-parses to the same args.
local function raw_args(segment, parsed)
  local want = parsed.args or {}
  local prefix = parsed.cmd .. (parsed.bang and "! " or " ")
  for i = 1, #segment do
    if not segment:sub(i, i):match("%s") then
      local ok, reparsed = pcall(vim.api.nvim_parse_cmd, prefix .. segment:sub(i), {})
      if ok and vim.deep_equal(reparsed.args or {}, want) then
        return segment:sub(i)
      end
    end
  end
  return table.concat(want, " ")
end

local function check_mapping(failures, mode, map)
  local cmdtext = rhs_command(map.rhs)
  if not cmdtext then
    return
  end
  -- nvim_parse_cmd honours `\|` and bar-consuming commands (normal, lua, !),
  -- but not commands that find their own bar; OWN_BAR_COMMANDS splits those.
  while cmdtext and cmdtext:find("%S") do
    local segment = cmdtext:match("^[%s:]*(.-)%s*$")
    local parse_ok, parsed = pcall(vim.api.nvim_parse_cmd, segment, {})
    if not parse_ok then
      -- Headless has no marks/lines for a range to resolve against (E20,
      -- E486 etc.), so retry without it to still validate the command name.
      local start = range_end(segment)
      if start > 1 then
        local rest = segment:sub(start)
        if not rest:find("%S") then
          -- A bare range (e.g. `?foo?`) is valid; nothing follows to check.
          break
        end
        parse_ok, parsed = pcall(vim.api.nvim_parse_cmd, rest, {})
      end
      if not parse_ok then
        table.insert(failures, string.format(
          "%s %s -> %q is not a valid Ex command: %s",
          mode, map.lhs, segment, tostring(parsed)))
        break
      end
    end
    if parsed.cmd == "lua" then
      local global_name = table.concat(parsed.args or {}, " "):match("^([%a_][%w_]*)%s*%(")
      -- `require` is Lua's module loader, not a config-defined global; plugins
      -- such as plenary bind `<cmd>lua require(...)<cr>` by default.
      if global_name and global_name ~= "require" then
        table.insert(failures, string.format(
          "%s %s -> <cmd>lua %s()<cr> binds to a Lua global; ADR 0002 requires a user command",
          mode, map.lhs, global_name))
      end
      -- `:lua` consumes the rest of the line, so nothing follows it.
      break
    end
    -- nvim_parse_cmd may still report a nextcmd for these (e.g. :echo splits
    -- at a bar inside a string), so the splitter takes precedence.
    local split = OWN_BAR_COMMANDS[parsed.cmd]
    if split then
      cmdtext = split(raw_args(segment, parsed))
    else
      cmdtext = parsed.nextcmd
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
    { lhs = "<Plug>KcTestBogusCmd",
      rhs = "<cmd>KeymapCommandsSelfTestNoSuchCommand12345<cr>", expect_flagged = true },
    { lhs = "<Plug>KcTestGoodCmd",
      rhs = "<cmd>echo<cr>", expect_flagged = false },
    { lhs = "<Plug>KcTestBogusGlobal",
      rhs = "<cmd>lua KeymapCommandsSelfTestUndefinedGlobal12345()<cr>", expect_flagged = true },
    -- Flagged even though the global exists: ADR 0002 forbids the binding itself.
    { lhs = "<Plug>KcTestDefinedGlobal",
      rhs = "<cmd>lua KeymapCommandsSelfTestDefinedGlobal()<cr>", expect_flagged = true },
    -- A modifier in front of `lua` must not hide the global from the check.
    { lhs = "<Plug>KcTestModifierGlobal",
      rhs = "<cmd>silent lua KeymapCommandsSelfTestDefinedGlobal()<cr>", expect_flagged = true },
    { lhs = "<Plug>KcTestRequire",
      rhs = "<cmd>lua require('vim.inspect')<cr>", expect_flagged = false },
    { lhs = "<Plug>KcTestBareColon",
      rhs = ":KeymapCommandsSelfTestNoSuchCommand54321<cr>", expect_flagged = true },
    { lhs = "<Plug>KcTestColonCU",
      rhs = ":<C-U>KeymapCommandsSelfTestNoSuchCommand54321<cr>", expect_flagged = true },
    { lhs = "<Plug>KcTestColonGoodCmd",
      rhs = ":echo<cr>", expect_flagged = false },
    { lhs = "<Plug>KcTestBang",
      rhs = "<cmd>bdelete!<cr>", expect_flagged = false },
    { lhs = "<Plug>KcTestChainGood",
      rhs = "<cmd>bdelete|bnext<cr>", expect_flagged = false },
    { lhs = "<Plug>KcTestChainBad",
      rhs = "<cmd>bdelete|KeymapCommandsSelfTestNoSuchCmdXyz<cr>", expect_flagged = true },
    { lhs = "<Plug>KcTestChainSpacedBad",
      rhs = "<cmd>bdelete | KeymapCommandsSelfTestNoSuchCmdXyz<cr>", expect_flagged = true },
    { lhs = "<Plug>KcTestChainBarKeyBad",
      rhs = "<cmd>bdelete<Bar>KeymapCommandsSelfTestNoSuchCmdXyz<cr>", expect_flagged = true },
    -- bdelete takes arguments, so an escaped bar is a literal argument char.
    { lhs = "<Plug>KcTestEscapedBar",
      rhs = "<cmd>bdelete\\|KeymapCommandsSelfTestNoSuchCmdXyz<cr>", expect_flagged = false },
    { lhs = "<Plug>KcTestLuaBar",
      rhs = "<cmd>lua vim.print(1) | vim.print(2)<cr>", expect_flagged = false },
    { lhs = "<Plug>KcTestNormalBar",
      rhs = "<cmd>normal! a|b<cr>", expect_flagged = false },
    { lhs = "<Plug>KcTestColonChainBad",
      rhs = ":bdelete|KeymapCommandsSelfTestNoSuchCmdXyz<cr>", expect_flagged = true },
    { lhs = "<Plug>KcTestAbbrev",
      rhs = "<cmd>bd<cr>", expect_flagged = false },
    -- Expression commands carry no bar syntax nvim_parse_cmd can see.
    { lhs = "<Plug>KcTestCallChainBad",
      rhs = "<cmd>call KeymapCommandsSelfTestNoFn()|KeymapCommandsSelfTestNoSuchCmdXyz<cr>", expect_flagged = true },
    -- The string and `||` must not end the expression; the last bar does.
    { lhs = "<Plug>KcTestEchoBarsBad",
      rhs = "<cmd>echo \"a|b\" || 0|KeymapCommandsSelfTestNoSuchCmdXyz<cr>", expect_flagged = true },
    { lhs = "<Plug>KcTestEchoStringsGood",
      rhs = "<cmd>echo \"a|b\"|echo 'c''|d'<cr>", expect_flagged = false },
    { lhs = "<Plug>KcTestRangeChainBad",
      rhs = "<cmd>bdelete|%KeymapCommandsSelfTestNoSuchCmdXyz<cr>", expect_flagged = true },
    { lhs = "<Plug>KcTestRangeChainGood",
      rhs = "<cmd>%bd|e#|bd#<cr>", expect_flagged = false },
    -- Marks are unset headless, so the range must not cause a false failure.
    { lhs = "<Plug>KcTestMarkRangeGood",
      rhs = ":'<,'>sort<cr>", expect_flagged = false },
    { lhs = "<Plug>KcTestMarkRangeChainBad",
      rhs = "<cmd>bdelete|'<,'>KeymapCommandsSelfTestNoSuchCmdXyz<cr>", expect_flagged = true },
    -- Search and visual-area ranges can't resolve headless either (E486, E20).
    { lhs = "<Plug>KcTestSearchRangeGood",
      rhs = ":/TODO/d<cr>", expect_flagged = false },
    { lhs = "<Plug>KcTestBackSearchRangeOnlyGood",
      rhs = ":?foo?<cr>", expect_flagged = false },
    { lhs = "<Plug>KcTestVisualAreaRangeGood",
      rhs = ":*sort<cr>", expect_flagged = false },
    { lhs = "<Plug>KcTestSearchRangeChainBad",
      rhs = "<cmd>bdelete|/x/KeymapCommandsSelfTestNoSuchCmdXyz<cr>", expect_flagged = true },
    { lhs = "<Plug>KcTestModifierBad",
      rhs = "<cmd>silent KeymapCommandsSelfTestNoSuchCmdXyz<cr>", expect_flagged = true },
    -- Commands without a trailing-bar flag find their own `|` at runtime, so
    -- nvim_parse_cmd gives no nextcmd for them either.
    { lhs = "<Plug>KcTestSubstituteChainBad",
      rhs = "<cmd>%s/\\s\\+$//e|KeymapCommandsSelfTestNoSuchCmdXyz<cr>", expect_flagged = true },
    { lhs = "<Plug>KcTestSubstituteChainGood",
      rhs = "<cmd>%s/x//e|nohlsearch<cr>", expect_flagged = false },
    { lhs = "<Plug>KcTestSubstituteEscapedBarBad",
      rhs = "<cmd>%s/a\\|b/c/|KeymapCommandsSelfTestNoSuchCmdXyz<cr>", expect_flagged = true },
    -- An unterminated replacement swallows the bar, so nothing follows to check.
    { lhs = "<Plug>KcTestSubstituteUnterminatedGood",
      rhs = "<cmd>s/a/b|KeymapCommandsSelfTestNoSuchCmdXyz<cr>", expect_flagged = false },
    -- A `[...]` collection hides the delimiter from the pattern, not the replacement.
    { lhs = "<Plug>KcTestSubstituteCollectionGood",
      rhs = "<cmd>s/[/]/x|KeymapCommandsSelfTestNoSuchCmdXyz/<cr>", expect_flagged = false },
    -- `\V` makes a bare `[` literal, so the pattern ends at the first `/`.
    { lhs = "<Plug>KcTestSubstituteVeryNoMagicBracketBad",
      rhs = "<cmd>s/\\V[/x/|KeymapCommandsSelfTestNoSuchCmdXyz<cr>", expect_flagged = true },
    -- Under `\V` it is `\[` that opens a collection, hiding the `/`.
    { lhs = "<Plug>KcTestSubstituteVeryNoMagicEscapedBracketGood",
      rhs = "<cmd>s/\\V\\[/]/x|KeymapCommandsSelfTestNoSuchCmdXyz/<cr>", expect_flagged = false },
    -- A `"` after the flags starts a comment, hiding the bar.
    { lhs = "<Plug>KcTestSubstituteCommentGood",
      rhs = "<cmd>%s/a/b/g \" note|KeymapCommandsSelfTestNoSuchCmdXyz<cr>", expect_flagged = false },
    -- Each collection form hides the `/` delimiter, so the bar stays in the
    -- replacement; a mis-skipped collection closes early and splits on that bar.
    { lhs = "<Plug>KcTestSubstituteCollectionClassGood",
      rhs = "<cmd>s/[[:alpha:]/]/x|KeymapCommandsSelfTestNoSuchCmdXyz/<cr>", expect_flagged = false },
    { lhs = "<Plug>KcTestSubstituteCollectionEquivGood",
      rhs = "<cmd>s/[[=a=]/]/x|KeymapCommandsSelfTestNoSuchCmdXyz/<cr>", expect_flagged = false },
    { lhs = "<Plug>KcTestSubstituteCollectionCollGood",
      rhs = "<cmd>s/[[.a.]/]/x|KeymapCommandsSelfTestNoSuchCmdXyz/<cr>", expect_flagged = false },
    { lhs = "<Plug>KcTestSubstituteCollectionCaretGood",
      rhs = "<cmd>s/[^]/]/x|KeymapCommandsSelfTestNoSuchCmdXyz/<cr>", expect_flagged = false },
    { lhs = "<Plug>KcTestSubstituteCollectionLeadBracketGood",
      rhs = "<cmd>s/[]/]/x|KeymapCommandsSelfTestNoSuchCmdXyz/<cr>", expect_flagged = false },
    -- A leading `-` must not swallow the next char (here the `\` of `\]`).
    { lhs = "<Plug>KcTestSubstituteCollectionLeadDashGood",
      rhs = "<cmd>s/[-\\]/]/x|KeymapCommandsSelfTestNoSuchCmdXyz/<cr>", expect_flagged = false },
    { lhs = "<Plug>KcTestSubstituteCollectionEscapeGood",
      rhs = "<cmd>s/[\\]/]/x|KeymapCommandsSelfTestNoSuchCmdXyz/<cr>", expect_flagged = false },
    -- A range end swallows `\`, so `[a-\]` closes at its `]` and the later bar
    -- splits; `a-]` must not swallow the closing `]`.
    { lhs = "<Plug>KcTestSubstituteCollectionRangeEndBad",
      rhs = "<cmd>s/[a-\\]/x/|KeymapCommandsSelfTestNoSuchCmdXyz<cr>", expect_flagged = true },
    { lhs = "<Plug>KcTestSubstituteCollectionRangeBeforeCloseBad",
      rhs = "<cmd>s/[a-]/]/x|KeymapCommandsSelfTestNoSuchCmdXyz/<cr>", expect_flagged = true },
    -- nvim_parse_cmd turns `\\` into `\` in args; the splitters must still see
    -- the raw text, or the escaped backslash hides the closing delimiter/quote.
    { lhs = "<Plug>KcTestSubstituteBackslashChainBad",
      rhs = "<cmd>%s/\\//\\\\/g|KeymapCommandsSelfTestNoSuchCmdXyz<cr>", expect_flagged = true },
    { lhs = "<Plug>KcTestSortBackslashChainBad",
      rhs = "<cmd>sort /\\\\/|KeymapCommandsSelfTestNoSuchCmdXyz<cr>", expect_flagged = true },
    { lhs = "<Plug>KcTestEchoBackslashChainBad",
      rhs = "<cmd>echo \"C:\\\\\"|KeymapCommandsSelfTestNoSuchCmdXyz<cr>", expect_flagged = true },
    { lhs = "<Plug>KcTestSortChainBad",
      rhs = ":sort|KeymapCommandsSelfTestNoSuchCmdXyz<cr>", expect_flagged = true },
    { lhs = "<Plug>KcTestSortPatternChainBad",
      rhs = "<cmd>sort /a|b/|KeymapCommandsSelfTestNoSuchCmdXyz<cr>", expect_flagged = true },
    { lhs = "<Plug>KcTestRepeatSubstituteChainBad",
      rhs = "<cmd>&&|KeymapCommandsSelfTestNoSuchCmdXyz<cr>", expect_flagged = true },
    { lhs = "<Plug>KcTestMatchChainBad",
      rhs = "<cmd>match Search /a|b/|KeymapCommandsSelfTestNoSuchCmdXyz<cr>", expect_flagged = true },
    -- `none` and a bare bar end `:match` itself; the bar then separates commands.
    { lhs = "<Plug>KcTestMatchNoneBad",
      rhs = "<cmd>match none|KeymapCommandsSelfTestNoSuchCmdXyz<cr>", expect_flagged = true },
    { lhs = "<Plug>KcTestMatchNoneQuoteBad",
      rhs = "<cmd>match none\"|KeymapCommandsSelfTestNoSuchCmdXyz<cr>", expect_flagged = true },
    { lhs = "<Plug>KcTestMatchBareBarBad",
      rhs = "<cmd>match|KeymapCommandsSelfTestNoSuchCmdXyz<cr>", expect_flagged = true },
    -- Unlike `:sort`, `:match` has no TRLBAR, so a leading `"` is no comment.
    { lhs = "<Plug>KcTestMatchCommentChainBad",
      rhs = "<cmd>match \" c|KeymapCommandsSelfTestNoSuchCmdXyz<cr>", expect_flagged = true },
    { lhs = "<Plug>KcTestSortCommentGood",
      rhs = "<cmd>sort \" c|KeymapCommandsSelfTestNoSuchCmdXyz<cr>", expect_flagged = false },
    { lhs = "<Plug>KcTestEchoUnterminatedGood",
      rhs = "<cmd>echo 'a|KeymapCommandsSelfTestNoSuchCmdXyz<cr>", expect_flagged = false },
    { lhs = "<Plug>KcTestTildeChainBad",
      rhs = "<cmd>~|KeymapCommandsSelfTestNoSuchCmdXyz<cr>", expect_flagged = true },
    { lhs = "<Plug>KcTestWincmdChainBad",
      rhs = "<cmd>wincmd h|KeymapCommandsSelfTestNoSuchCmdXyz<cr>", expect_flagged = true },
    -- The argument char may be `|`; only a bar after it separates commands.
    { lhs = "<Plug>KcTestWincmdBarArgGood",
      rhs = "<cmd>wincmd ||wincmd _<cr>", expect_flagged = false },
    { lhs = "<Plug>KcTestWincmdBarArgBad",
      rhs = "<cmd>wincmd ||KeymapCommandsSelfTestNoSuchCmdXyz<cr>", expect_flagged = true },
    { lhs = "<Plug>KcTestWincmdBarArgAloneGood",
      rhs = "<cmd>wincmd |KeymapCommandsSelfTestNoSuchCmdXyz<cr>", expect_flagged = false },
    -- `g` takes a second argument char, so `g|` consumes the bar.
    { lhs = "<Plug>KcTestWincmdGBad",
      rhs = "<cmd>wincmd g}|KeymapCommandsSelfTestNoSuchCmdXyz<cr>", expect_flagged = true },
    { lhs = "<Plug>KcTestWincmdGBarArgGood",
      rhs = "<cmd>wincmd g|KeymapCommandsSelfTestNoSuchCmdXyz<cr>", expect_flagged = false },
    { lhs = "<Plug>KcTestCexprChainBad",
      rhs = "<cmd>cexpr []|KeymapCommandsSelfTestNoSuchCmdXyz<cr>", expect_flagged = true },
    -- `:help` has no TRLBAR; it ends at a bar followed by text.
    { lhs = "<Plug>KcTestHelpChainBad",
      rhs = "<cmd>help foo|KeymapCommandsSelfTestNoSuchCmdXyz<cr>", expect_flagged = true },
    { lhs = "<Plug>KcTestHelpChainGood",
      rhs = "<cmd>help foo|bnext<cr>", expect_flagged = false },
    -- `||` is no split point; both directions are covered so that a plain
    -- first-bar split flips one of them whatever the empty segment parses to.
    { lhs = "<Plug>KcTestHelpDoubleBarChainBad",
      rhs = "<cmd>help a||KeymapCommandsSelfTestNoSuchCmdXyz<cr>", expect_flagged = true },
    { lhs = "<Plug>KcTestHelpDoubleBarChainGood",
      rhs = "<cmd>help a||echo 'x|KeymapCommandsSelfTestNoSuchCmdXyz<cr>", expect_flagged = false },
    -- A bare `:catch` and a leading `"` (no delimiter) end at the first bar.
    { lhs = "<Plug>KcTestCatchBareChainBad",
      rhs = "<cmd>try|catch|KeymapCommandsSelfTestNoSuchCmdXyz|endtry<cr>", expect_flagged = true },
    { lhs = "<Plug>KcTestCatchQuoteChainBad",
      rhs = "<cmd>try|catch \" c|KeymapCommandsSelfTestNoSuchCmdXyz|endtry<cr>", expect_flagged = true },
    -- An unterminated pattern swallows the bar.
    { lhs = "<Plug>KcTestCatchUnterminatedGood",
      rhs = "<cmd>try|catch /abc|KeymapCommandsSelfTestNoSuchCmdXyz|endtry<cr>", expect_flagged = false },
    -- The bar inside the `:catch` pattern must not split the command.
    { lhs = "<Plug>KcTestCatchChainBad",
      rhs = "<cmd>try|catch /a|b/|KeymapCommandsSelfTestNoSuchCmdXyz|endtry<cr>", expect_flagged = true },
  }

  for _, case in ipairs(cases) do
    vim.api.nvim_set_keymap("n", case.lhs, case.rhs, {})
  end

  _G.KeymapCommandsSelfTestDefinedGlobal = function() end
  local self_ok, self_failures = pcall(check_keymaps)

  _G.KeymapCommandsSelfTestDefinedGlobal = nil
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
  io.stderr:write(string.format("%d keymap(s) failed the keymap-commands audit\n", #failures))
  os.exit(1)
end

os.exit(0)
