# Nixvim template

This template gives you a good starting point for configuring nixvim standalone.

## Configuring

To start configuring, just add or modify the nix files in `./config`.
If you add a new configuration file, remember to add it to the
[`config/default.nix`](./config/default.nix) file

## direnv

The direnv integration debounces `direnv export vim` and can be tuned with:

- `g:direnv_interval`: debounce delay in milliseconds (default 500)
- `g:direnv_max_wait`: rapid triggers that may postpone an export before it
  runs immediately (default 5)

## Testing your new configuration

To test your configuration simply run the following command

```
nix run .
```
