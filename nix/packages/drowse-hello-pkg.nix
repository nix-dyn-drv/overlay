# Ordinary callPackage-shaped recipe (same shape nixpkgs' own pkgs/.../hello
# uses) -- evaluated INSIDE drowse's nested nix-instantiate sandbox, not by
# the outer flake eval. See ../drowse-hello.nix for the wrapper that defers
# evaluating this file via drowse.callPackage.

{ lib, stdenv, fetchurl }:

stdenv.mkDerivation (finalAttrs: {
  pname = "hello";
  version = "2.12.2";

  src = fetchurl {
    url = "mirror://gnu/hello/hello-${finalAttrs.version}.tar.gz";
    hash = "sha256-WpqZbcKSzCTc9BHO6H6S9qrluNE72caBm0x6nc4IGKs=";
  };

  doCheck = true;
})
