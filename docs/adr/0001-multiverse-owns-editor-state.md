# multiverse.nvim owns per-codebase editor state, one Universe at a time

We replaced the hand-built tab-per-project workspace manager (project.nvim root detection,
persistence.nvim sessions, scope.nvim tab-scoped buffers, custom `switch_project` Lua) with
codymikol/multiverse.nvim. A Universe owns the whole editor: switching saves the current one,
closes every buffer, and restores the target. We accepted losing side-by-side projects in tabs
(`MultiverseAlternate` covers quick flipping) to stop maintaining a fragile custom switcher.

## Consequences

- project.nvim must not come back: its `BufEnter` chdir breaks multiverse's cwd-based lookup of
  the current Universe and silently skips saving it.
- Terminals are zellij-backed (`MultiverseTerminal`); buffer-based terminals die on every switch.
- LSP restart on environment change hangs off direnv's `User DirenvLoaded`, not off multiverse
  hooks, so nothing in this config depends on multiverse internals.
