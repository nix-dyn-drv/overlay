# lua-bench-edited.nix: same shape as nixgg's own
# tests/perf-regression-fixture.nix (touch one file, append a comment
# line) -- reused here so both mechanisms rebuild from an IDENTICAL
# one-line source edit, not just "the same package".
{
  flakeDir,
  edit ? null, # null | a relative path inside lua's src/ to touch (e.g. "src/lmathlib.c")
  variant, # "plain" | "accelerated"
  nixPackagePath ? null,
  dyndrvShimPath ? null, # store path of the compiled rust/dyndrv-shim package -- when set, exercises the compiled path instead of the default bash toNodeBash/collectStubs path
}:
let
  pkgs = (builtins.getFlake (toString flakeDir)).legacyPackages.${builtins.currentSystem};
  lib = pkgs.lib;
  dyndrv = import (flakeDir + "/nix") { inherit pkgs lib; };

  realSrc = pkgs.fetchurl {
    url = "https://www.lua.org/ftp/lua-5.4.7.tar.gz";
    hash = "sha256-n79eKO+GxphY9tPTTszDLpEcGii0Eg/z6EqqcM+/HjA=";
  };

  # `fetchurl`'s own output is a compressed tarball, not a directory --
  # unpack once, touch the file, re-pack isn't needed: `src` below can
  # be a plain directory just as well as an archive (stdenv's own
  # unpackPhase handles both), so skip the round-trip through tar
  # entirely.
  unpackedSrc = pkgs.runCommand "lua-5.4.7-unpacked" { } ''
    mkdir -p $out
    tar -xzf ${realSrc} -C $out --strip-components=1
  '';

  editedSrc =
    pkgs.runCommand "lua-5.4.7-edited" { } ''
      cp -a ${unpackedSrc} $out
      chmod -R u+w $out
      printf '\n/* dyndrv perf-comparison touch */\n' >> $out/${edit}
    '';

  src = if edit == null then unpackedSrc else editedSrc;

  resolvedNixPackage =
    if nixPackagePath != null then builtins.storePath nixPackagePath else pkgs.nix;

  resolvedDyndrvShim =
    if dyndrvShimPath != null then builtins.storePath dyndrvShimPath else null;

  stdenv =
    if variant == "accelerated" then
      dyndrv.accelerate.mkAcceleratedStdenv {
        nixPackage = resolvedNixPackage;
        stdenv = pkgs.stdenv;
        dyndrvShim = resolvedDyndrvShim;
      }
    else
      pkgs.stdenv;
in
stdenv.mkDerivation {
  pname = "lua-bench";
  version = "5.4.7";
  inherit src;
  nativeBuildInputs = [ pkgs.gnumake ];

  buildPhase = ''
    runHook preBuild
    cd src
    make linux CC=cc
    cd ..
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    cp src/lua src/luac $out/bin/
    runHook postInstall
  '';

  doCheck = false;
}
