# brotli -- BLOCKED. cmake build (~38 real per-TU compile derivations
# registered: brotlicommon/brotlidec/brotlienc + the `brotli` CLI), and
# every single real compile fails identically:
#
#   cc1: fatal error: /build/source/c/common/dictionary.c: No such file
#   or directory
#   compilation terminated.
#
# (also c/enc/dictionary_hash.c, c/enc/encoder_dict.c, c/enc/static_init.c,
# c/tools/brotli.c, and every other real TU -- confirmed via
# `nix log`/`nix derivation show` on several of the failing `.drv`s).
#
# Root cause: this is the SAME discoverTree cmake-source-path bug already
# documented against xxHash/re2/tinycbor's cmake recipe, see
# ~/dyn-drvs/docs/discovertree-cmake-source-path-bug.md. Confirmed directly
# here by inspecting the staged per-TU sandbox tree
# (`dyndrv-tree` src input via `nix derivation show` + `nix store ls -R`):
# it contains only `./-I/build/source/c` (an empty directory tree created
# from the literal `-I/build/source/c/include` compiler flag being
# (mis)treated as a path to stage) and the `CMakeFiles/...` bookkeeping
# dirs -- the actual `c/common/dictionary.c` etc. source files were never
# staged at all. cmake's absolute, out-of-source-dir-relative
# `/build/source/...` path baked into the compile command doesn't
# round-trip through discoverTree's `-M -MG`-based staging the same way
# an autoconf/Makefile-relative path does. brotli's cmake project root IS
# the source root (unlike xxHash's out-of-tree `build/cmake` layout) and
# it's a cmake+make generator (not cmake+ninja like re2), so this
# confirms the bug is broader than either of those two prior theories --
# any cmake-generated absolute `/build/source/...` compile path seems to
# trip it, regardless of in-tree/out-of-tree cmakeDir or generator choice.
#
# Not fixed here -- would mean patching dyn-drvs' discoverTree itself,
# out of scope for this repo (see docs/discovertree-cmake-source-path-bug.md
# for the upstream-facing writeup). No package-level cmakeFlags/postPatch
# workaround was attempted since the bug is in how discoverTree stages
# files for ANY real compile in this package, not something brotli's own
# recipe does unusually.
#
# Left here (not deleted) as a fourth confirmed instance of this bug
# (xxHash, re2, tinycbor, now brotli), and the first with the plainest
# possible cmake layout (in-tree, cmake+make, no custom target, no
# out-of-tree build dir) -- ruling out several previously-considered
# contributing factors.

{
  pkgs,
  dyndrv,
  nixPackage ? pkgs.nix,
  dyndrvShim ? null,
}:

let
  acceleratedStdenv = dyndrv.accelerate.mkAcceleratedStdenv {
    stdenv = pkgs.stdenv;
    inherit nixPackage dyndrvShim;
  };
in
pkgs.brotli.override { stdenv = acceleratedStdenv; }
