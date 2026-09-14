window.BENCHMARK_DATA = {
  "lastUpdate": 1789353902499,
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
          "id": "0359c2bf2666b9f8023a88ac98cfb605bbe69239",
          "message": "Add daily nixpkgs-unstable tracking workflow\n\nnixpkgs.url already points at nixpkgs-unstable (rolling), so \"keeping up\nwith a much larger system\" means auto-bumping flake.lock on a schedule\nand proving proven packages still build against the new pin -- not just\nfreezing at whatever revision happened to be locked.\n\nnixpkgs-update.yml: daily cron, nix flake update nixpkgs, rebuild the\nproven tier (freetype, giflib) and nixgg tier (openssl, hello, mosh,\nzstd). If both stay green, commit the lock bump straight to main --\nthat's the actual \"kept up automatically\" signal. If either regresses,\nopen a PR instead so the break is visible before it lands.",
          "timestamp": "2026-09-13T21:06:06-04:00",
          "tree_id": "5d23599c53ef60907409ffb984e2235c346ca21e",
          "url": "https://github.com/nix-dyn-drv/overlay/commit/0359c2bf2666b9f8023a88ac98cfb605bbe69239"
        },
        "date": 1789348656954,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "freetype patch-rebuild speedup (plain/accelerated)",
            "value": 1.08,
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
          "id": "adce1fe854bac3ed263868a4ab3fa49dc22656b3",
          "message": "Fix nixpkgs-update.yml: query root's nixpkgs node, not dyndrv's internal one\n\n.locks.nodes.nixpkgs is a real node in this flake's lock file, but it's\ndyn-drvs' own internal nixpkgs input (a separate nixos-26.05 pin, deduped\nunder that name since flake.lock names nodes by first occurrence), not\nroot's nixpkgs-unstable input. The before/after rev comparison silently\ncompared the wrong node and always read as \"unchanged\" even after a real\nbump (confirmed: manual dispatch run 34794805145 skipped in 32s despite\nnixpkgs-unstable having moved from 2026-08-29 to 2026-09-13 locally).\nFixed to resolve via .locks.nodes.root.inputs.nixpkgs first.",
          "timestamp": "2026-09-13T21:09:18-04:00",
          "tree_id": "7a35d923db2d9c02585f91e26f48aba65ff621cb",
          "url": "https://github.com/nix-dyn-drv/overlay/commit/adce1fe854bac3ed263868a4ab3fa49dc22656b3"
        },
        "date": 1789348872199,
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
          "id": "01fe3481ca9748f18cfedf3cc2a395d8e594835b",
          "message": "Document libpng/libtasn1 (outputBin bug) and gperf (depfile bug) findings\n\nTwo more new dyn-drvs bugs found and independently verified during the\npackage survey, beyond the ones already covered (xxHash, re2, libb64,\nmpfr, tinycbor):\n\n- libpng/libtasn1 both fail at phase 1 setup with `_assignFirst: could\n  not find a non-empty variable ... outputMan`. Both set outputBin =\n  \"dev\" explicitly; phases.split forces single-output but doesn't clear\n  that inherited literal override.\n- gperf gets past real per-TU compiles, then fails at every automake\n  depcomp `mv .Tpo .Po` step -- the -MF depfile is a second compiler\n  output that never round-trips out of the per-TU sandbox.\n\nFull writeups went to ~/dyn-drvs/docs/ (left uncommitted there per\nstanding instruction).",
          "timestamp": "2026-09-13T21:24:50-04:00",
          "tree_id": "ab2fb0325fb800d2a9b20085394a43f8357b3e7e",
          "url": "https://github.com/nix-dyn-drv/overlay/commit/01fe3481ca9748f18cfedf3cc2a395d8e594835b"
        },
        "date": 1789349825653,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "freetype patch-rebuild speedup (plain/accelerated)",
            "value": 0.99,
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
          "id": "b3ed508980f68f76609b3fda7588f289f5b1ba18",
          "message": "Add tree, figlet, nnn as new proven dyn-drvs packages\n\nThree more real nixpkgs packages confirmed building cleanly through\naccelerate.mkAcceleratedStdenv, found by prioritizing plain\nhand-written-Makefile packages (no configure, no cmake) after the\nprior survey showed autotools' depcomp idiom and cmake's generated\nbuild systems are both reliable landmines for this mechanism. All\nthree independently spot-checked, tree/figlet directly against this\nrepo's pinned nixpkgs; nnn's build also re-verified locally.\n\nWired into flake.nix, ci.yml's hard-gate proven tier, and\nnixpkgs-update.yml's rebuild-and-bump gate, alongside RESULTS.md/README\nupdates.",
          "timestamp": "2026-09-13T21:44:27-04:00",
          "tree_id": "bba653210b50e7249b7ce3f0f50845b4927eac72",
          "url": "https://github.com/nix-dyn-drv/overlay/commit/b3ed508980f68f76609b3fda7588f289f5b1ba18"
        },
        "date": 1789351111271,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "freetype patch-rebuild speedup (plain/accelerated)",
            "value": 1,
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
          "id": "fa843246d9a90de4e77eae05372574fb0ac6f90a",
          "message": "Bump dyndrv input to latest pushed commit (2024a41)\n\nPicks up dyn-drvs' recent doc consolidation and flake-purity work (Rpc\nwrapper flake output, --impure removal). Verified: flake evaluates\nclean, and all five proven packages (freetype, giflib, tree, figlet,\nnnn) still build clean; zstd still blocked as documented (its link-step\nfix is still local/uncommitted upstream, not in this pushed rev yet).",
          "timestamp": "2026-09-13T22:32:13-04:00",
          "tree_id": "ae663303f3f2c87a1f602b6ff1c489399a64af23",
          "url": "https://github.com/nix-dyn-drv/overlay/commit/fa843246d9a90de4e77eae05372574fb0ac6f90a"
        },
        "date": 1789353901891,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "freetype patch-rebuild speedup (plain/accelerated)",
            "value": 1,
            "unit": "x"
          }
        ]
      }
    ]
  }
}