# nixvim-config

## Reference documentation

When making any changes to this nixvim configuration, consult the nixvim source at:

**https://github.com/nix-community/nixvim**

Browse the `plugins/` directory and module source to verify that plugin names and option paths
exist before using them.

## Commit conventions

Group changes by file — one commit per file touched. When a file addresses multiple issues,
describe each change in the commit body and close all affected issues together. Reference
closed issues in the commit body, not the summary line.

Example:
```
fix(cmp): correct option names and add missing source plugin

- rename ls_expand to lsp_expand in snippet expand function
- rename sidePadding to side_padding

Closes #8, #12
```

For a single-issue file a short body with just `Closes #N` is sufficient.
