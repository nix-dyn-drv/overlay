# libwebp -- BLOCKED. Single-output (`out`), cmake-based, ~171 TUs -- picked
# specifically to avoid the multi-output gaps hit elsewhere (openssl's
# `finalPackage`, libpng/libtasn1's `outputBin`), but it hits the SAME
# `discoverTree` cmake-source-path bug already tracked in
# ~/dyn-drvs/docs/discovertree-cmake-source-path-bug.md (xxHash, re2,
# and this repo's own tinycbor).
#
# Every real per-TU compile across every one of libwebp's cmake targets
# fails identically:
#
#   cc1: fatal error: /build/source/examples/dwebp.c: No such file or directory
#   compilation terminated.
#
# ...repeated for `imageio/image_dec.c`, `src/mux/muxread.c`,
# `sharpyuv/sharpyuv_dsp.c`, `src/dec/buffer_dec.c`,
# `src/demux/anim_decode.c`, and every other TU across libwebp's several
# cmake targets (webpdecode/webpencode/webpdsp/webpdspdecode/
# webpdemux/libwebpmux/sharpyuv/dwebp/imagedec/...). Confirmed via
# `nix derivation show` on one failing per-TU `.drv`
# (`dyndrv-CMakeFiles_dwebp_dir_examples_dwebp_c_o.drv`): the actual `cc`
# invocation is `cc ... '-Isrc' '-I/build/source/src' ... -o $out -c
# '/build/source/examples/dwebp.c'`, but inspecting the per-TU sandbox's
# staged `dyndrv-tree` shows it materialized only `src/` (plus
# `CMakeFiles/dwebp.dir/examples/` -- an empty directory skeleton, no
# `.c` file) -- and, tellingly, a literal top-level directory NAMED `-I`
# containing `build/source` as a nested path. That confirms `discoverTree`
# is misparsing one of the `-I<path>` flags as a *file* path component to
# stage (splitting on/staging the flag text itself) rather than resolving
# `/build/source/examples/dwebp.c`, the actual `-c` positional source
# argument, at all -- so `examples/`, `imageio/`, `sharpyuv/`,
# `src/mux/`, `src/dec/`, `src/demux/` (every source subdirectory besides
# the one the scan happened to get partially right) never get staged,
# and every TU whose primary source lives in one of them fails identically
# to xxHash/re2/tinycbor.
#
# Root cause: same as `discovertree-cmake-source-path-bug.md` --
# `discoverTree`'s per-TU sandbox staging can't reliably resolve a cmake-
# generated compile invocation's absolute in-sandbox source path
# (`/build/source/<subdir>/<file>.c`) back to the right relative subtree,
# for libwebp's specific mix of top-level (`examples/`, `imageio/`,
# `sharpyuv/`) and nested (`src/dec/`, `src/enc/`, `src/dsp/`,
# `src/mux/`, `src/demux/`) source layout. Not package-fixable at this
# layer (no `cmakeFlags`/`postPatch` changes libwebp's own cmake project
# layout enough to dodge this -- the bug is in how `discoverTree` stages
# files, not in libwebp's own build description). Left here (not deleted)
# as a fourth confirmed instance of the same open bug, on yet another
# real nixpkgs source-tree shape.

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
pkgs.libwebp.override { stdenv = acceleratedStdenv; }
