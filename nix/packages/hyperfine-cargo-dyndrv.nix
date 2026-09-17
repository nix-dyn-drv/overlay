# hyperfine (Rust, ~173 crates, real nixpkgs package) via cargo-dyndrv's
# per-crate dynamic derivations -- the fifth independent mechanism in
# this survey, and the first targeting a language other than C/C++.
# Cargo's own compilation unit is the crate (not the file), so
# per-crate acceleration here is the direct Rust equivalent of nixgg/
# dyn-drvs' per-translation-unit splitting.
#
# Picked deliberately for a clean first attempt: zero external C
# buildInputs (no pkg-config/extern.json wiring needed, unlike e.g.
# ripgrep's pcre2 dependency), and a plain, filesystem-only build.rs
# (shell-completion generation via clap_complete -- no cc invocation,
# no linking, just writes under $OUT_DIR).
#
# RESULT: BLOCKED. Compiling `portable-atomic`'s own build.rs (a
# transitive dependency via indicatif, hyperfine's progress-bar
# library -- an ordinary, non-optional dependency, not test/dev-only)
# fails:
#
#   error: environment variable `CARGO_PKG_NAME` not defined at compile time
#     --> portable-atomic-1.11.1-src/build.rs:42:17
#      |
#   42 |                 env!("CARGO_PKG_NAME"),
#
# Root-caused directly in cargo-dyndrv's own source
# (cargo-dyndrv/src/main.rs's `add_metadata_env`): it populates
# CARGO_PKG_VERSION and its MAJOR/MINOR/PATCH/PRE components for a
# build-script invocation, but not CARGO_PKG_NAME (or the other real,
# documented Cargo env vars -- AUTHORS, DESCRIPTION, etc.) -- the
# function's own trailing comment, "// TODO: more of these", is an
# acknowledged, not-yet-filled gap, not a design choice. `env!()` is a
# compile-time macro (distinct from `std::env::var()`, which the
# compiler's own error message correctly suggests as a workaround --
# but that's a fix to portable-atomic's OWN source, not something
# available from the hyperfine/cargo-dyndrv call site).
#
# No package-level workaround found: portable-atomic is pulled in
# transitively (hyperfine -> indicatif -> portable-atomic), not an
# optional/feature-gated dependency hyperfine's own Cargo.toml
# controls. Given how common `env!("CARGO_PKG_NAME")` is as an idiom
# in real build.rs scripts (this is a standard Cargo-provided variable,
# not obscure), and how widely-used portable-atomic itself is as a
# transitive dependency across the Rust ecosystem, this bug likely
# blocks a large fraction of real-world crate graphs, not just this
# one package.

{
  pkgs,
  buildDynamicCrate,
}:

let
  # Same pname/version/src/cargoHash as nixpkgs' own by-name recipe
  # (pkgs/by-name/hy/hyperfine/package.nix) -- real, unmodified upstream
  # source, not a synthetic fixture.
  version = "1.20.0";
  src = pkgs.fetchFromGitHub {
    owner = "sharkdp";
    repo = "hyperfine";
    tag = "v${version}";
    hash = "sha256-Ee889Fx2Mi2005SrlcKc7TwG8ZIpTqisfLebXYadvSg=";
  };
in
buildDynamicCrate {
  pname = "hyperfine";
  inherit version src;
  cargoHash = "sha256-0e6QDVv//WQtfvrJj6jW1sEz7jFv3VC6UKLvclyytLs=";
  outputs = [ "hyperfine" ];
}
