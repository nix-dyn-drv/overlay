{
  description = "Showcasing Nix dynamic derivations at nixpkgs scale, four mechanisms side by side";

  nixConfig = {
    extra-experimental-features = [
      "nix-command"
      "ca-derivations"
      "dynamic-derivations"
      "recursive-nix"
    ];
    extra-substituters = [ "https://dynamicderivations.cachix.org" ];
    extra-trusted-public-keys = [
      "dynamicderivations.cachix.org-1:AmDuQASmWJsVYB/r0TGTZnQSnoxPzKP8ijfGw/6aT3k="
    ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixgg = {
      url = "github:tomberek/nixgg";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dyndrv = {
      url = "github:tomberek/dyn-drvs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixNinja.url = "github:pdtpartners/nix-ninja";
    drowse.url = "github:figsoda/drowse";
  };

  outputs =
    {
      self,
      ...
    }@inputs:
    let
      forEachSystem = f: builtins.mapAttrs (system: pkgs: f system pkgs) inputs.nixpkgs.legacyPackages;
    in
    {
      # nixgg mechanism (splitStdenv/dynDrvStdenv). zstd needs the
      # gen_html fix below; the rest just override stdenv.
      packages = forEachSystem (
        system: pkgs:
        let
          nixggPackages = inputs.nixgg.packages.${system};
          dynDrvStdenv = nixggPackages.dynDrvStdenv { stdenv = pkgs.stdenv; };
          inherit (nixggPackages) mkNixggBuild;

          dyndrvLib = inputs.dyndrv.lib.${system};
          dyndrvPatchedNix = import (inputs.dyndrv.outPath + "/try-it-out/patched-nix.nix") { inherit system; };

          dyndrvOpensslCheckpoints = import ./nix/packages/openssl.nix {
            inherit pkgs;
            dyndrv = dyndrvLib;
            nixPackage = dyndrvPatchedNix;
          };
        in
        {
          openssl = pkgs.openssl.override { stdenv = dynDrvStdenv; };
          openssl-3_5 = pkgs.openssl_3_5.override { stdenv = dynDrvStdenv; };
          hello = pkgs.hello.override { stdenv = dynDrvStdenv; };
          mosh = pkgs.mosh.override { stdenv = dynDrvStdenv; };
          zstd =
            let
              genHtml = mkNixggBuild {
                pname = "zstd-gen-html";
                version = "0";
                src = pkgs.zstd.src;
                target = "gen_html";
                buildCommand = ''
                  cd contrib/gen_html
                  g++ -O2 -c gen_html.cpp -o gen_html.o
                  g++ gen_html.o -o gen_html
                '';
              };
            in
            pkgs.zstd.override {
              # extraPhase1Attrs goes on dynDrvStdenv, not zstd.override.
              stdenv = nixggPackages.dynDrvStdenv {
                stdenv = pkgs.stdenv;
                extraPhase1Attrs =
                  finalAttrs: old:
                  old
                  // {
                    postPatch = old.postPatch + ''
                      substituteInPlace build/cmake/contrib/gen_html/CMakeLists.txt \
                        --replace-fail \
                          'add_executable(gen_html ''${GENHTML_DIR}/gen_html.cpp)' \
                          "" \
                        --replace-fail \
                          'DEPENDS gen_html COMMENT "Update zstd manual")' \
                          'COMMENT "Update zstd manual")' \
                        --replace-fail \
                          'set(GENHTML_BINARY ''${PROJECT_BINARY_DIR}/gen_html''${CMAKE_EXECUTABLE_SUFFIX})' \
                          'set(GENHTML_BINARY ${genHtml.package}/bin/gen_html)'
                    '';
                  };
              };
            };

          # dyndrv mechanism (accelerate.mkAcceleratedStdenv / phases.split).
          # freetype is dyn-drvs' own example; giflib/tree/figlet/nnn are
          # new and clean. zstd/mosh/openssl/tinycbor are new and each
          # hit a distinct open dyn-drvs bug, see nix/packages/*.nix.
          # x264 is a new PASS, but needed two package-level workarounds
          # for two more new dyn-drvs bugs -- see nix/packages/x264.nix.
          # dyndrv-freetype-baseline: plain, unaccelerated freetype --
          # the real comparison point for benchmarks/patch-rebuild.sh
          # (dyndrv-freetype alone isn't a valid plain/accelerated pair).
          dyndrv-freetype-baseline = pkgs.freetype;

          dyndrv-freetype =
            (import (inputs.dyndrv.outPath + "/try-it-out/examples/07-accelerate-real-package.nix") {
              inherit pkgs;
              lib = pkgs.lib;
              dyndrv = dyndrvLib;
              nixPackage = dyndrvPatchedNix;
            }).accelerated;

          dyndrv-giflib = import ./nix/packages/giflib.nix {
            inherit pkgs;
            dyndrv = dyndrvLib;
            nixPackage = dyndrvPatchedNix;
          };

          dyndrv-tree = import ./nix/packages/tree.nix {
            inherit pkgs;
            dyndrv = dyndrvLib;
            nixPackage = dyndrvPatchedNix;
          };

          dyndrv-figlet = import ./nix/packages/figlet.nix {
            inherit pkgs;
            dyndrv = dyndrvLib;
            nixPackage = dyndrvPatchedNix;
          };

          dyndrv-nnn = import ./nix/packages/nnn.nix {
            inherit pkgs;
            dyndrv = dyndrvLib;
            nixPackage = dyndrvPatchedNix;
          };

          dyndrv-tinycbor = import ./nix/packages/tinycbor.nix {
            inherit pkgs;
            dyndrv = dyndrvLib;
            nixPackage = dyndrvPatchedNix;
          };

          dyndrv-zstd = import ./nix/packages/zstd.nix {
            inherit pkgs;
            dyndrv = dyndrvLib;
            nixPackage = dyndrvPatchedNix;
          };

          dyndrv-mosh = import ./nix/packages/mosh.nix {
            inherit pkgs;
            dyndrv = dyndrvLib;
            nixPackage = dyndrvPatchedNix;
          };

          dyndrv-protobuf = import ./nix/packages/protobuf.nix {
            inherit pkgs;
            dyndrv = dyndrvLib;
            nixPackage = dyndrvPatchedNix;
          };

          dyndrv-x265 = import ./nix/packages/x265.nix {
            inherit pkgs;
            dyndrv = dyndrvLib;
            nixPackage = dyndrvPatchedNix;
          };

          dyndrv-leveldb = import ./nix/packages/leveldb.nix {
            inherit pkgs;
            dyndrv = dyndrvLib;
            nixPackage = dyndrvPatchedNix;
          };

          dyndrv-x264 = import ./nix/packages/x264.nix {
            inherit pkgs;
            dyndrv = dyndrvLib;
            nixPackage = dyndrvPatchedNix;
          };

          dyndrv-libwebp = import ./nix/packages/libwebp.nix {
            inherit pkgs;
            dyndrv = dyndrvLib;
            nixPackage = dyndrvPatchedNix;
          };

          dyndrv-openjpeg = import ./nix/packages/openjpeg.nix {
            inherit pkgs;
            dyndrv = dyndrvLib;
            nixPackage = dyndrvPatchedNix;
          };

          dyndrv-capnproto = import ./nix/packages/capnproto.nix {
            inherit pkgs;
            dyndrv = dyndrvLib;
            nixPackage = dyndrvPatchedNix;
          };

          # nix-ninja mechanism: a drop-in `ninja` replacement translating a
          # meson-generated build.ninja's real build graph into dynamic
          # derivations. Third, independent implementation of the same
          # builtins.outputOf/builder-rpc-v0 primitive nixgg/dyndrv use.
          nixninja-argp = import ./nix/packages/nixninja-argp.nix {
            inherit pkgs;
            nixNinjaFlake = inputs.nixNinja;
          };

          # drowse mechanism: defers a whole package's EVALUATION into a
          # nested nix-instantiate (recursive-nix), not a per-TU build
          # split -- the "avoid IFD" half of dynamic derivations, distinct
          # from nixgg/dyndrv/nix-ninja's per-TU/per-checkpoint splitting.
          drowse-hello = import ./nix/packages/drowse-hello.nix {
            inherit pkgs;
            drowse = inputs.drowse.lib.${system};
          };

          # Split into three attrs since a flake package must be a
          # derivation, not an attrset.
          dyndrv-openssl = dyndrvOpensslCheckpoints.accelerated;
          dyndrv-openssl-baseline = dyndrvOpensslCheckpoints.baseline;
          dyndrv-openssl-patched = dyndrvOpensslCheckpoints.patchedAccelerated;
        }
      );

      overlays.default = final: prev: {
        inherit (self.packages.${prev.stdenv.hostPlatform.system})
          hello
          openssl
          openssl-3_5
          mosh
          zstd
          ;
      };
    };
}
