# keymaps.nix owns the global key layout

All global keymaps and their which-key group names live in `config/keymaps.nix`, so key
collisions are visible in one file. Keymaps declared through a plugin's own nixvim keymap option
(telescope, lsp) stay with that plugin, and feature-flagged keys are gated inline with
`lib.optionals`. We considered letting each feature module own its keys (as `copilot.nix` does
for cmp and lualine) and rejected it: the flag leak is a couple of lines, and splitting the layout
loses the single place to audit it. Keymaps bind to user commands, never to Lua globals.
