# hello via drowse.callPackage -- a genuinely different mechanism from
# nixgg/dyn-drvs: those two keep a package's own evaluation fully resolved
# by the OUTER `nix eval` and only split its BUILD into checkpoint
# derivations. drowse's callPackage/instantiate instead defers the whole
# package's EVALUATION into a nested `nix-instantiate` running inside a
# recursive-nix sandbox, surfacing only the resulting .drv's output through
# builtins.outputOf -- the "avoid IFD by pushing eval into the sandbox"
# half of the dynamic-derivations story, distinct from per-TU build
# splitting. Uses `recursive-nix`, not `builder-rpc-v0`.
#
# hello is drowse's own tested proof point (tests/hello.nix, verbatim),
# reused here rather than inventing a new wrapped file -- deliberately not
# a "fine-grained per-TU" demo, since that's not what this mechanism does.
# Verified: real ELF `bin/hello`, runs and prints "Hello, world!".

{
  pkgs,
  drowse,
}:

drowse.callPackage {
  pname = "hello";
  version = "2.12.2";
  src = ./drowse-hello-pkg.nix;
}
