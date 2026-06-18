{
  plugins.toggleterm = {
    enable = true;
    settings = {
      direction = "float";
      insert_mappings = true;
      float_opts = {
        width.__raw = "math.floor(vim.o.columns * 0.9)";
        height.__raw = "math.floor(vim.o.lines * 0.9)";
      };
    };
  };

  # Per-project terminal helper.  Lives at the top level because
  # plugins.toggleterm has no extraConfigLua option; use the global hook.
  extraConfigLua = ''
    -- Per-project terminals: maintain a table of toggleterm Terminal
    -- instances keyed by resolved project root. Each project's terminal
    -- is created lazily and recreated automatically if its process has
    -- exited.
    local _project_terms = {}

    function ToggleProjectTerm()
      local root = vim.fn.resolve(vim.fn.getcwd())
      local term = _project_terms[root]

      if term then
        -- jobwait returns -1 while the job is still running; any other value
        -- (exit code, or -2 for timed-out) means the process is gone.
        local alive = term.job_id
          and term.job_id > 0
          and vim.fn.jobwait({ term.job_id }, 0)[1] == -1
        if not alive then
          _project_terms[root] = nil
          term = nil
        end
      end

      if not term then
        local Terminal = require('toggleterm.terminal').Terminal
        term = Terminal:new({
          dir = root,
          direction = 'float',
          float_opts = {
            width  = math.floor(vim.o.columns * 0.9),
            height = math.floor(vim.o.lines   * 0.9),
            border = 'curved',
          },
          -- hidden = true keeps this terminal out of the default toggle cycle
          -- so the global open_mapping (disabled above) cannot steal it.
          hidden = true,
        })
        _project_terms[root] = term
      end

      term:toggle()
    end
  '';
}
