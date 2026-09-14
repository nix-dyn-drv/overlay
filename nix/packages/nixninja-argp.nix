# argp-standalone (meson+ninja, ~7 tiny C files, no cmake, single static-lib
# target) via nix-ninja's mkMesonPackage -- a drop-in `ninja` replacement
# (set $NINJA=nix-ninja) that turns a meson-generated build.ninja's real
# build graph into independent Nix dynamic derivations, same primitive
# (builtins.outputOf/builder-rpc-v0) as nixgg/dyn-drvs but a third,
# independent implementation. Verified: real `ar` archive with all 7
# translation units, `ar t libargp.a` lists genuine .o members.
#
# Unlike nixgg/dyn-drvs, mkMesonPackage doesn't override an existing
# package's stdenv -- it reconstructs the meson invocation directly
# (src + nativeBuildInputs + a real ninja target name), and mkMesonPackage
# itself isn't exported as a flake `lib` output, so it's imported straight
# from nix-ninja's own source tree via `pkgs.callPackage`.

{
  pkgs,
  nixNinjaFlake,
}:

let
  mkMesonPackage = pkgs.callPackage (nixNinjaFlake.outPath + "/modules/flake/pkgs/mkMesonPackage") {
    nix-ninja = nixNinjaFlake.packages.${pkgs.system}.nix-ninja;
    nix-ninja-task = nixNinjaFlake.packages.${pkgs.system}.nix-ninja-task;
    nix = pkgs.nix;
  };

  drv = mkMesonPackage {
    pname = "argp-standalone";
    version = pkgs.argp-standalone.version;
    src = pkgs.argp-standalone.src;
    target = "libargp.a";
    nativeBuildInputs = pkgs.argp-standalone.nativeBuildInputs;
  };
in
drv.target
