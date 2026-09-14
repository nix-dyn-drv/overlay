# leveldb -- BLOCKED. cmake+make, ~39 real per-TU compile-unit derivations
# registered (db/*.cc, table/*.cc, util/*.cc, plus leveldbutil's own TU),
# LSM-tree engine, moderate-heavy per-file cost. Every single one of those
# 39 real compiles fails identically:
#
#   cc1plus: fatal error: db/c.cc: No such file or directory
#   compilation terminated.
#
# (same for all of db/builder.cc, db/dbformat.cc, db/db_impl.cc,
# db/db_iter.cc, db/dumpfile.cc, db/filename.cc, db/leveldbutil.cc,
# db/log_reader.cc, db/log_writer.cc, db/memtable.cc, db/repair.cc,
# db/table_cache.cc, db/version_edit.cc, db/version_set.cc,
# db/write_batch.cc, helpers/memenv/memenv.cc, every table/*.cc, every
# util/*.cc -- 39/39, a clean 100%, not a partial hit like re2's 20/51).
#
# Root cause: this is the SAME discoverTree cmake-source-path bug already
# documented for xxHash/re2/tinycbor (see
# ~/dyn-drvs/docs/discovertree-cmake-source-path-bug.md) -- a per-TU
# `discoverTree` sandbox's `-M -MG` scan doesn't resolve the absolute
# in-sandbox source path (`/build/source/<file>.cc`) that cmake's
# generated compile command actually invokes `cc`/`c++` with, so the real
# source is never staged into that TU's sandbox tree. Notably, unlike
# xxHash, leveldb's `CMakeLists.txt` lives at the repository root (no
# out-of-tree `build/cmake` subdirectory) -- confirming (as the bug doc's
# re2 finding already suspected) that "out-of-tree cmake dir" isn't a
# precondition; a same-tree cmake+make project hits it just as
# universally. This is the fourth independent confirmation of the same
# discoverTree gap (xxHash, re2, tinycbor@7.0, now leveldb), and the
# highest TU-count/most-total-failure case seen so far.
#
# No package-level workaround exists: the bug is in how `discoverTree`
# resolves source paths for ANY cmake-generated compile invocation, not
# something a `postPatch`/`cmakeFlags` tweak in this package's own recipe
# can route around. BLOCKED pending a dyn-drvs fix to discoverTree's
# cmake path handling (see the bug doc for details); left here (not
# deleted) as a fourth real, reproducible data point.

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
pkgs.leveldb.override { stdenv = acceleratedStdenv; }
