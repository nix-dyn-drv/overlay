window.BENCHMARK_DATA = {
  "lastUpdate": 1789346544694,
  "repoUrl": "https://github.com/nix-dyn-drv/overlay",
  "entries": {
    "Benchmark": [
      {
        "commit": {
          "author": {
            "email": "tbereknyei@anduril.com",
            "name": "tbereknyei",
            "username": "tomberek"
          },
          "committer": {
            "email": "tbereknyei@anduril.com",
            "name": "tbereknyei",
            "username": "tomberek"
          },
          "distinct": true,
          "id": "c2b95fe2e648f92d33b2de70eb420903a031e5d5",
          "message": "Grant contents:write so github-action-benchmark can push to gh-pages\n\nDefault GITHUB_TOKEN permissions are read-only; the gh-pages publish\nstep needs write access to push the benchmark dashboard commit.\n\nCo-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>",
          "timestamp": "2026-09-13T17:57:11-04:00",
          "tree_id": "031d7676b5894a0e080f66e0256b71e2e296e3a3",
          "url": "https://github.com/nix-dyn-drv/overlay/commit/c2b95fe2e648f92d33b2de70eb420903a031e5d5"
        },
        "date": 1789337202197,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "freetype patch-rebuild speedup (plain/accelerated)",
            "value": 1.29,
            "unit": "x"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "tbereknyei@anduril.com",
            "name": "tbereknyei",
            "username": "tomberek"
          },
          "committer": {
            "email": "tbereknyei@anduril.com",
            "name": "tbereknyei",
            "username": "tomberek"
          },
          "distinct": true,
          "id": "2dd01d7e2d53949eab384e50e5b57f26321215d5",
          "message": "Record confirmed CI success for nixgg-mechanism openssl/hello/mosh/zstd\n\nCo-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>",
          "timestamp": "2026-09-13T18:00:36-04:00",
          "tree_id": "b34ccda1fafa74908f6b21c9c35ed9b024813ab9",
          "url": "https://github.com/nix-dyn-drv/overlay/commit/2dd01d7e2d53949eab384e50e5b57f26321215d5"
        },
        "date": 1789337553544,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "freetype patch-rebuild speedup (plain/accelerated)",
            "value": 1.01,
            "unit": "x"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "tbereknyei@anduril.com",
            "name": "tbereknyei",
            "username": "tomberek"
          },
          "committer": {
            "email": "tbereknyei@anduril.com",
            "name": "tbereknyei",
            "username": "tomberek"
          },
          "distinct": true,
          "id": "26eded35872d0943a8c6b4bf7796990b061fd7c0",
          "message": "Add giflib as a second proven dyn-drvs package, simplify README\n\ngiflib (plain Makefile, ar-based static lib) builds cleanly with no\nworkarounds -- confirmed while investigating why pcre2/giflib initially\nappeared to fail (both were actually a missing nixPackage argument in\nthe test setup, not real bugs; pcre2 does hit the real discoverTree\nlink-step bug once nixPackage is fixed, confirming it's not cmake-specific).\n\nCo-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>",
          "timestamp": "2026-09-13T19:52:14-04:00",
          "tree_id": "d4747ee45751c112b53ca36a1ff1f123a137df58",
          "url": "https://github.com/nix-dyn-drv/overlay/commit/26eded35872d0943a8c6b4bf7796990b061fd7c0"
        },
        "date": 1789344334876,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "freetype patch-rebuild speedup (plain/accelerated)",
            "value": 1.02,
            "unit": "x"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "tbereknyei@anduril.com",
            "name": "tbereknyei",
            "username": "tomberek"
          },
          "committer": {
            "email": "tbereknyei@anduril.com",
            "name": "tbereknyei",
            "username": "tomberek"
          },
          "distinct": false,
          "id": "091bcd4f0d9c91fd69f230520503b9f5def5dcfe",
          "message": "Add tinycbor (BLOCKED, new cmake-source-path bug) from ultracode survey\n\nAn ultracode-orchestrated survey against xxHash, tinycbor, re2, libb64,\nand mpfr found three new dyn-drvs failure modes beyond the four already\ndocumented, plus a third confirmation of the known link-step bug (mpfr).\n\ntinycbor was initially spot-checked as a clean PASS, but that used an\nolder qmake-based 0.6.1 recipe from a different nixpkgs channel than\nthis repo's actual pin. Rebuilding against this flake's real nixpkgs\n(26.05, tinycbor 7.0, cmake-based) hit the same discoverTree\ncmake-source-path bug xxHash and re2 exposed -- wired in as\ndyndrv-tinycbor, informational/non-blocking in CI like zstd/mosh.\n\nFull writeups for the new bugs went to ~/dyn-drvs/docs/ (left\nuncommitted there per standing instruction).",
          "timestamp": "2026-09-13T20:29:12-04:00",
          "tree_id": "70d3c5264c270091b0a063b2a73b8514f0bd9885",
          "url": "https://github.com/nix-dyn-drv/overlay/commit/091bcd4f0d9c91fd69f230520503b9f5def5dcfe"
        },
        "date": 1789346544196,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "freetype patch-rebuild speedup (plain/accelerated)",
            "value": 1.01,
            "unit": "x"
          }
        ]
      }
    ]
  }
}