{ lib, config, ... }:
{
  keymaps =
    # ── Global keymaps (always active) ────────────────────────────────────
    [
      # Clipboard
      { mode = "n"; key = "Y";   action = ''"*y''; }
      { mode = "v"; key = "Y";   action = ''"*y''; options = { desc = "Copy to system clipboard"; }; }
      { mode = "n"; key = "YY";  action = ''^"*y$''; options = { desc = "Copy to system clipboard"; }; }

      # Format
      { key = "<leader>fm"; action = "<CMD>lua vim.lsp.buf.format()<CR>"; options.desc = "Format the current buffer"; }

      # Session
      { mode = "n"; key = "<leader>qq"; action = "<cmd>qa<cr>"; options = { desc = "Quit All"; }; }

      # Window navigation (split-pane movement)
      { action = "<C-w>h"; key = "<C-h>"; mode = [ "n" ]; }
      { action = "<C-w>j"; key = "<C-j>"; mode = [ "n" ]; }
      { action = "<C-w>k"; key = "<C-k>"; mode = [ "n" ]; }
      { action = "<C-w>l"; key = "<C-l>"; mode = [ "n" ]; }

      # Terminal (per-project)
      { mode = [ "n" "t" ]; key = "<leader>t";  action = "<CMD>lua ToggleProjectTerm()<CR>"; options.desc = "Toggle project terminal"; }
      { mode = [ "n" "t" ]; key = "<C-Return>"; action = "<CMD>lua ToggleProjectTerm()<CR>"; options.desc = "Toggle project terminal"; }

      # File tree
      { key = "<leader>e"; action = "<CMD>Neotree toggle<CR>"; options.desc = "Toggle Nvim Tree"; }

      # Buffer navigation
      { mode = "n"; key = "]b";    action = "<cmd>BufferLineCycleNext<cr>"; options = { desc = "Cycle to next buffer"; }; }
      { mode = "n"; key = "[b";    action = "<cmd>BufferLineCyclePrev<cr>"; options = { desc = "Cycle to previous buffer"; }; }
      { mode = "n"; key = "<S-l>"; action = "<cmd>BufferLineCycleNext<cr>"; options = { desc = "Cycle to next buffer"; }; }
      { mode = "n"; key = "<S-h>"; action = "<cmd>BufferLineCyclePrev<cr>"; options = { desc = "Cycle to previous buffer"; }; }
      { mode = "n"; key = "<leader>bd"; action = "<cmd>bdelete<cr>";                         options = { desc = "Delete buffer"; }; }
      { mode = "n"; key = "<leader>bl"; action = "<cmd>BufferLineCloseLeft<cr>";             options = { desc = "Delete buffers to the left"; }; }
      { mode = "n"; key = "<leader>bo"; action = "<cmd>BufferLineCloseOthers<cr>";           options = { desc = "Delete other buffers"; }; }
      { mode = "n"; key = "<leader>bp"; action = "<cmd>BufferLineTogglePin<cr>";             options = { desc = "Toggle pin"; }; }
      { mode = "n"; key = "<leader>bP"; action = "<Cmd>BufferLineGroupClose ungrouped<CR>"; options = { desc = "Delete non-pinned buffers"; }; }

      # Git — hunk preview (gitsigns, always active)
      { key = "<leader>gp"; action = "<CMD>Gitsigns preview_hunk<CR>"; options.desc = "Show git hunk preview"; }

      # Telescope — non-plugin-schema bindings
      { mode = "n"; key = "<leader>sd"; action = "<cmd>Telescope diagnostics bufnr=0<cr>";                      options = { desc = "Document diagnostics"; }; }
      { mode = "n"; key = "<leader>fe"; action = "<cmd>Telescope file_browser<cr>";                             options = { desc = "File browser"; }; }
      { mode = "n"; key = "<leader>fE"; action = "<cmd>Telescope file_browser path=%:p:h select_buffer=true<cr>"; options = { desc = "File browser"; }; }

      # Project — project.nvim + workspaces (custom picker, not :Telescope projects)
      { mode = "n"; key = "<leader>fp"; action = "<cmd>lua ProjectPicker()<cr>";  options = { desc = "Switch project"; }; }
      { mode = "n"; key = "<leader>p";  action = "<cmd>lua ProjectPicker()<cr>";  options = { desc = "Switch workspace"; }; }
      { mode = "n"; key = "<leader>pa"; action = "<cmd>lua AddProject()<cr>";     options = { desc = "Add project"; }; }
      { mode = "n"; key = "<leader>pr"; action = "<cmd>lua RemoveProject()<cr>";  options = { desc = "Remove project"; }; }
    ]

    # ── Feature-gated keymaps ──────────────────────────────────────────────
    ++ lib.optionals config.features.lazygit [
      { mode = "n"; key = "<leader>gg"; action = "<CMD>LazyGit<CR>"; }
    ];
}
