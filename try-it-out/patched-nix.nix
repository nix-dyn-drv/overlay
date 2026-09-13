# Adapted from dyn-drvs (github:tomberek/dyn-drvs). Pinned NixOS/nix
# commit with builder-rpc-v0/submit-output support (landed on master,
# no patched fork needed). Must match the Nix used inside the sandbox
# (see run-nix.sh) or builds fail with a worker-protocol mismatch.

{
  rev ? "72385de1bef8b8879384b4810e3b0864f4d3c3da",
  system ? builtins.currentSystem,
}:

let
  flake = builtins.getFlake "github:NixOS/nix/${rev}";
in
flake.packages.${system}.nix
