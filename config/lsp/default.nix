{
  plugins = {
    lsp = {
      enable = true;
      inlayHints = true;
      servers = {
        bashls.enable = true;
        gopls.enable = true;
        kotlin-language-server.enable = true;
        nil-ls.enable = true;
        jsonls.enable = true;
        ansiblels.enable = true;
#        pyright.enable = true;
        helm-ls = {
          enable = true;
          extraOptions = {
            settings = {
              "helm-ls" = {
                yamlls = {
                  path =
                    "${pkgs.yaml-language-server}/bin/yaml-language-server";
                };
              };
            };
          };
        };
        yamlls = {
          enable = true;
          extraOptions = {
            settings = {
              yaml = {
                schemas = {
                  kubernetes = "'*.yaml";
                  "http://json.schemastore.org/github-workflow" =
                    ".github/workflows/*";
                  "http://json.schemastore.org/github-action" =
                    ".github/action.{yml,yaml}";
                  "http://json.schemastore.org/ansible-stable-2.9" =
                    "roles/tasks/*.{yml,yaml}";
                  "http://json.schemastore.org/kustomization" =
                    "kustomization.{yml,yaml}";
                  "http://json.schemastore.org/ansible-playbook" =
                    "*play*.{yml,yaml}";
                  "http://json.schemastore.org/chart" = "Chart.{yml,yaml}";
                  "https://json.schemastore.org/dependabot-v2" =
                    ".github/dependabot.{yml,yaml}";
                  "https://raw.githubusercontent.com/compose-spec/compose-spec/master/schema/compose-spec.json" =
                    "*docker-compose*.{yml,yaml}";
                  "https://raw.githubusercontent.com/argoproj/argo-workflows/master/api/jsonschema/schema.json" =
                    "*flow*.{yml,yaml}";
                };
              };
            };
          };
        };
      };
      keymaps = {
        silent = true;
        lspBuf = {
          gd = {
            action = "definition";
            desc = "Goto Definition";
          };
          gr = {
            action = "references";
            desc = "Goto References";
          };
          gD = {
            action = "declaration";
            desc = "Goto Declaration";
          };
          gI = {
            action = "implementation";
            desc = "Goto Implementation";
          };
          gT = {
            action = "type_definition";
            desc = "Type Definition";
          };
          K = {
            action = "hover";
            desc = "Hover";
          };
          "<leader>cw" = {
            action = "workspace_symbol";
            desc = "Workspace Symbol";
          };
          "<leader>cr" = {
            action = "rename";
            desc = "Rename";
          };
        };
        diagnostic = {
          "<leader>cd" = {
            action = "open_float";
            desc = "Line Diagnostics";
          };
          "<leader>j" = {
            action = "goto_next";
            desc = "Next Diagnostic";
          };
          "<leader>k" = {
            action = "goto_prev";
            desc = "Previous Diagnostic";
          };
        };
      };
    };
    lsp-lines = {
      enable = true;
      currentLine = true;
    };
    lsp-status = { enable = true; };
  };
}
