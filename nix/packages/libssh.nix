# libssh -- BLOCKED. cmake build (~110+ TUs: SSH client library over
# openssl/zlib/libsodium; `out`+`dev` outputs), hits the same
# discoverTree cmake-source-path bug already documented for xxHash/re2/
# tinycbor (this repo's actual nixpkgs pin): every real TU compile fails
# identically --
#
#   cc1: fatal error: /build/libssh-0.12.2/src/agent.c: No such file or directory
#   compilation terminated.
#
# (confirmed via `nix log` on the first-failing derivation,
# `dyndrv-src_CMakeFiles_ssh_dir_agent_c_o.drv`; the build queued 64
# per-TU compile derivations before nix's default fail-fast stopped it at
# the first failure -- there is no reason to expect any of the other 63
# to differ, since cmake bakes the same absolute
# `/build/libssh-<version>/src/<file>.c` invocation shape into every
# compile command). Root cause: cmake generates each compile invocation
# with an absolute source path pointing at where the *outer*
# (unaccelerated) build would have unpacked the full source tree;
# `discoverTree`'s per-TU sandbox stages files based on its own `-M -MG`
# scan, which doesn't line up with that absolute path for this project
# layout. See ~/dyn-drvs/docs/discovertree-cmake-source-path-bug.md --
# same bug class as xxHash/re2/tinycbor (v7.0, this repo's own pin), not
# a new finding. No package-level workaround exists (cmakeFlags can't
# change how cmake emits its compile_commands.json source paths); needs
# a dyn-drvs fix to discoverTree's per-TU source resolution for cmake
# builds. Left here (not deleted) as a fifth confirmation of this bug
# class, on a real-world protocol-glue package outside the
# crypto/compression/parsing libraries the other four already covered.

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
pkgs.libssh.override { stdenv = acceleratedStdenv; }
