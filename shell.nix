{ pkgs }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    ripgrep
  ];
}
