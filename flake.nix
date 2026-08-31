{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixgg = {
      url = "github:tomberek/nixgg";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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
      packages = forEachSystem (
        system: pkgs:
        let
          nixggPackages = inputs.nixgg.packages.${system};
          dynDrvStdenv = nixggPackages.dynDrvStdenv { stdenv = pkgs.stdenv; };
          inherit (nixggPackages) mkNixggBuild;
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
              stdenv = dynDrvStdenv;
              extraPhase1Attrs =
                finalAttrs: old:
                old
                // {
                  # Removes gen_html's add_executable + DEPENDS edge, and points
                  # GENHTML_BINARY at phase A's binary instead. Every other TU
                  # still goes through dynDrvStdenv's real shim acceleration
                  # unmodified.
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
