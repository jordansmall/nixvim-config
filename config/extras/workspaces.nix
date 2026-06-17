{
  extraConfigLua = ''
    local function switch_project(root)
      -- 1. Save the session we are leaving
      require('persistence').save()

      -- 2. Re-use an existing tab if this project is already open
      for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
        local tabnr = vim.api.nvim_tabpage_get_number(tabpage)
        if vim.fn.getcwd(-1, tabnr) == root then
          vim.api.nvim_set_current_tabpage(tabpage)
          return
        end
      end

      -- 3. Open a new tab, set tab-local cwd, restore that project's session
      vim.cmd("tabnew")
      vim.cmd("tcd " .. vim.fn.fnameescape(root))
      require('persistence').load()
    end

    require('telescope').setup({
      extensions = {
        projects = {
          action = function(project)
            switch_project(project.path)
          end,
        },
      },
    })
  '';
}
