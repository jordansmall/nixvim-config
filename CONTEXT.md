# nixvim-config

A personal Neovim configuration built with nixvim. The domain is context-switching between
codebases while keeping each one's editor state.

## Language

**Universe**:
A named, registered directory together with its saved editor state (tabpages, windows, buffers).
Exactly one Universe is active at a time, and it owns the whole editor.
_Avoid_: Workspace, project session

**Multiverse**:
The catalog of all registered Universes.
_Avoid_: project list, project history
