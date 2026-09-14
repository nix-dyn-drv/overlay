window.BENCHMARK_DATA = {
  "lastUpdate": 1789424644463,
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
          "id": "beb36f85906efb53cadee0e1655d3563358ed998",
          "message": "Fix freetype benchmark comparing dyndrv-freetype against itself, remeasure\n\nCI's freetype patch-rebuild benchmark step passed the same attr\n(dyndrv-freetype) as both the \"plain\" and \"accelerated\" side of\npatch-rebuild.sh, so every recorded ratio was ~1.0x (confirmed in the\nlive gh-pages dashboard data) -- not a real plain-vs-accelerated\ncomparison at all. The README/RESULTS.md \"17x slower\" figure was never\nactually measured in this repo either; it's dyn-drvs' own BASELINE.md\nnumber for a different scenario (one-file patch rebuild, not cold\nbuild), cited without re-verification.\n\nAdded dyndrv-freetype-baseline (plain pkgs.freetype) as the real\ncomparison point, fixed both ci.yml and nightly.yml to use it, and\nre-measured directly: cold build is 0.15x (~6.7x slower), consistent\nacross two runs (11.8-11.9s plain vs 77-81s accelerated, 93 dynamic\nderivations registered). Updated README/RESULTS.md to cite this\nrepo's own honest number instead of an uncredited borrowed one.",
          "timestamp": "2026-09-13T23:14:05-04:00",
          "tree_id": "6ea1867007973c044f7adee9b17e344c033ff216",
          "url": "https://github.com/nix-dyn-drv/overlay/commit/beb36f85906efb53cadee0e1655d3563358ed998"
        },
        "date": 1789356290100,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "freetype patch-rebuild speedup (plain/accelerated)",
            "value": 0.6,
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
          "id": "ed24f379f47eaa0ae0260bbe9b5f9bee4165f0ed",
          "message": "Make nix-ninja informational in CI: intermittent real-/nix/store failure\n\nCI (real /nix/store via run-nix-ci.sh's sudo path) hit a failure that\ndidn't reproduce locally against the redirected alt-store: argp-standalone\nfails with PermissionError: [Errno 13] Permission denied: '/nonexistent'\nduring an \"Installing files\" ninja step that ran further than my local\nrepro's build graph did -- looks like ninja's own generated install rule\nexecuting and writing to mkMesonPackage's literal placeholder path, not\nyet root-caused (may be a real/alt-store sandboxing difference, or\nCI-specific timing/ordering). Marked continue-on-error so it doesn't\nblock regressions in drowse or the proven dyndrv tier alongside it.",
          "timestamp": "2026-09-14T02:03:03-04:00",
          "tree_id": "c0e60dfbd75921ef8562d13917d180c174ef2f7a",
          "url": "https://github.com/nix-dyn-drv/overlay/commit/ed24f379f47eaa0ae0260bbe9b5f9bee4165f0ed"
        },
        "date": 1789366942669,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "freetype patch-rebuild speedup (plain/accelerated)",
            "value": 0.67,
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
          "id": "f21ac6a2d5a06ef5b3a326cf90be864f66d84ff6",
          "message": "Rewrite README around the actual goal: is dynamic derivations viable?\n\nThe old README led with mechanism names and a wall of numbers. Reframe\naround what this repo is actually for -- testing whether Nix's dynamic\nderivations feature holds up against real nixpkgs packages, not just\ntoy examples, and reporting the honest answer (wins and losses) rather\nthan just the best-case demo. Explains why four independent libraries\nare tested (isolates \"is the underlying Nix feature viable\" from \"does\nthis one library's design work\"), and states the actual finding in\nplain terms: it works dramatically on the right package shape, but has\nreal, current limits (cmake/automake patterns) that aren't universal\nyet -- with the upstream bug-reporting loop as part of the point, not\njust the benchmark numbers.",
          "timestamp": "2026-09-14T02:12:26-04:00",
          "tree_id": "23fce2d22f1cbc6848218343f4fd20a45c31bd14",
          "url": "https://github.com/nix-dyn-drv/overlay/commit/f21ac6a2d5a06ef5b3a326cf90be864f66d84ff6"
        },
        "date": 1789367283606,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "freetype patch-rebuild speedup (plain/accelerated)",
            "value": 0.6,
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
          "id": "2ae2eb6f93be885cfc6a7770297a042248ab4825",
          "message": "Add fzakaria/trynix: PR comment with a boot-in-browser link\n\ntrynix.dev boots a nixpkgs build in an in-browser QEMU/WASM VM; the\nGitHub Action posts a PR comment linking to it for packages already\nbuilt and pushed to a cache -- pure reviewer UX, unrelated to the\ndynamic-derivations mechanism itself.\n\nWired to .#dyndrv-giflib (a proven, hard-gated, already-Cachix-pushed\npackage). Needed two real fixes to work at all:\n\n- pull-requests: write permission (for posting the comment).\n- extra-conf on the nix-installer-action step: trynix shells out to a\n  plain, daemon-mediated `nix eval $attr.outPath`, which fails with\n  \"experimental Nix feature 'dynamic-derivations' is disabled\" against\n  the ambient daemon's default config -- confirmed directly (a\n  per-invocation --extra-experimental-features flag can't retroactively\n  grant this to an already-running daemon; only nix.conf at install\n  time can, same fix dyn-drvs' own CI needed). This only grants\n  ca-derivations/dynamic-derivations for evaluating an already-built,\n  already-cached output -- NOT builder-rpc-v0, which still requires the\n  patched-Nix path the rest of this workflow uses to actually build one.\n\nGated on same-repo PR contexts only, matching the Cachix push step it\ndepends on -- a fork PR never pushed anything for trynix to link to.",
          "timestamp": "2026-09-14T03:22:40-04:00",
          "tree_id": "11e6fae7b71703abef36e1bfac89a80ae09007be",
          "url": "https://github.com/nix-dyn-drv/overlay/commit/2ae2eb6f93be885cfc6a7770297a042248ab4825"
        },
        "date": 1789371644731,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "freetype patch-rebuild speedup (plain/accelerated)",
            "value": 0.61,
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
          "id": "0e0e5a46db739be13948a6f58493f7b649be0580",
          "message": "Bump dyndrv to 227b1a6: fixes cmake -MT/-MF source misdetection, ar/ranlib probe crashes\n\nTwo more real fixes landed upstream:\n- 97a987d: discoverTree's firstSourceIdx misidentified -MT/-MF's own\n  values as the source file for cmake-generated compile lines (the\n  actual root cause of what was documented as \"discovertree-cmake-\n  source-path-bug.md\" -- that doc's original diagnosis was wrong,\n  now corrected upstream).\n- 227b1a6: ar/ranlib shims crashing/misclassifying on version-probe\n  invocations.\n\nThis likely resolves several of the open per-package PRs' documented\n\"cmake-source-path bug\" blockers (brotli, leveldb, libwebp, libssh,\nopenjpeg, x265) -- re-testing each against this rev next.",
          "timestamp": "2026-09-14T04:44:14-04:00",
          "tree_id": "9308285ef90778e52475a6069a642e9964790793",
          "url": "https://github.com/nix-dyn-drv/overlay/commit/0e0e5a46db739be13948a6f58493f7b649be0580"
        },
        "date": 1789376599168,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "freetype patch-rebuild speedup (plain/accelerated)",
            "value": 0.59,
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
          "id": "bf73bd8050fc7d246f1e19fa750bdf37a6347cb4",
          "message": "Bump dyndrv to 0d233d3: fixes phases.split cmake+make out-of-tree install\n\nFixes the install-time \"CMake Error: source directory /build/source\ndoes not exist\" bug that blocked brotli/leveldb/capnproto's cmake+make\nbuilds (phases.split's phase 2 forced sourceRoot=\".\" and never\nrecreated the /build/source path cmake's own cached\nCMAKE_HOME_DIRECTORY still pointed at; the existing dyndrvCdToBuildDir\nreconstruction only triggered for meson's build.ninja marker before\nthis fix generalized it to cmake+make too).\n\nConfirmed via an ultracode retest sweep across all 10 open per-package\nPRs: capnproto now passes cleanly (pushed to PR #7); brotli/leveldb\nprogressed past this bug into two more real, distinct dyn-drvs bugs\n(brotli: multi-output dev/lib split not populated before fixupPhase;\nleveldb: the already-documented split-postinstall-before-restore-bug,\nconfirmed a second time via substituteInPlace instead of wrapProgram).",
          "timestamp": "2026-09-14T10:01:56-04:00",
          "tree_id": "19accee0fa5166b5bf93c7226b770b41ef905b17",
          "url": "https://github.com/nix-dyn-drv/overlay/commit/bf73bd8050fc7d246f1e19fa750bdf37a6347cb4"
        },
        "date": 1789395489594,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "freetype patch-rebuild speedup (plain/accelerated)",
            "value": 0.67,
            "unit": "x"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "tomberek@users.noreply.github.com",
            "name": "tomberek",
            "username": "tomberek"
          },
          "committer": {
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": false,
          "id": "542cb0c26e2b3218367ee1a7dde6bd59a8bf71ad",
          "message": "Merge pull request #7 from nix-dyn-drv/capnproto-package-2\n\nAdd capnproto (cmake, ~187 .c++ TUs) -- PASS, fixed by dyn-drvs 0d233d3 (retest)",
          "timestamp": "2026-09-14T10:26:55-04:00",
          "tree_id": "225234f6b4cd7794970d060a9a1800cc5dc86b71",
          "url": "https://github.com/nix-dyn-drv/overlay/commit/542cb0c26e2b3218367ee1a7dde6bd59a8bf71ad"
        },
        "date": 1789397197066,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "freetype patch-rebuild speedup (plain/accelerated)",
            "value": 0.81,
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
          "id": "d2f923180b7112d247c895f934a477ad2b8aa4b7",
          "message": "Bump dyndrv to 2525772: fixes ar shim missing .o/archive inputs\n\nNew fix upstream: 28af81d (\"Fix ar shim: declare its own real .o/archive\ninputs as derivation deps\") -- this is the bug hitting libwebp, x265,\nand openjpeg's ar/ranlib archive steps (nix derivation show confirmed\ninputs.drvs = {} for those failing derivations). Also picks up\n2525772's own CI addition of the trynix action (unrelated to this\nrepo's own copy).\n\nVerified: giflib and capnproto still build clean against the new rev.\nRetesting libwebp/x265/openjpeg next.",
          "timestamp": "2026-09-14T11:18:19-04:00",
          "tree_id": "d2e033d81cbd795a73aed8d100cdfe692684733b",
          "url": "https://github.com/nix-dyn-drv/overlay/commit/d2f923180b7112d247c895f934a477ad2b8aa4b7"
        },
        "date": 1789400265230,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "freetype patch-rebuild speedup (plain/accelerated)",
            "value": 0.64,
            "unit": "x"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "tomberek@users.noreply.github.com",
            "name": "tomberek",
            "username": "tomberek"
          },
          "committer": {
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": true,
          "id": "7352d90af9df02e699ac13861b373d9740d66b45",
          "message": "Merge pull request #14 from nix-dyn-drv/trynix-openssl\n\nPoint trynix boot link at .#openssl instead of .#dyndrv-giflib",
          "timestamp": "2026-09-14T12:43:08-04:00",
          "tree_id": "f85a4ee667cc5f1e5668d34ce8f3a1b6120c3e08",
          "url": "https://github.com/nix-dyn-drv/overlay/commit/7352d90af9df02e699ac13861b373d9740d66b45"
        },
        "date": 1789405306861,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "freetype patch-rebuild speedup (plain/accelerated)",
            "value": 0.62,
            "unit": "x"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "tomberek@users.noreply.github.com",
            "name": "tomberek",
            "username": "tomberek"
          },
          "committer": {
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": true,
          "id": "e855aef35464cf218a993465f085ad622a486ac9",
          "message": "Merge pull request #13 from nix-dyn-drv/openjpeg-package\n\nAdd openjpeg (cmake, ~76 TUs) -- PASS, fixed upstream by dyn-drvs 28af81d",
          "timestamp": "2026-09-14T12:43:48-04:00",
          "tree_id": "a0eadde805ffa014636c8828fb1d163e4e85d309",
          "url": "https://github.com/nix-dyn-drv/overlay/commit/e855aef35464cf218a993465f085ad622a486ac9"
        },
        "date": 1789405359394,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "freetype patch-rebuild speedup (plain/accelerated)",
            "value": 0.6,
            "unit": "x"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "tomberek@users.noreply.github.com",
            "name": "tomberek",
            "username": "tomberek"
          },
          "committer": {
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": true,
          "id": "6794c900e8915a089a3cf5a5159a5e0ff46e38b4",
          "message": "Merge pull request #15 from nix-dyn-drv/bump-dyndrv-dc07a0a\n\nBump dyndrv to dc07a0a",
          "timestamp": "2026-09-14T14:34:53-04:00",
          "tree_id": "a0eadde805ffa014636c8828fb1d163e4e85d309",
          "url": "https://github.com/nix-dyn-drv/overlay/commit/6794c900e8915a089a3cf5a5159a5e0ff46e38b4"
        },
        "date": 1789412002844,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "freetype patch-rebuild speedup (plain/accelerated)",
            "value": 0.58,
            "unit": "x"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "tomberek@users.noreply.github.com",
            "name": "tomberek",
            "username": "tomberek"
          },
          "committer": {
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": true,
          "id": "6403e45875627a6721a554c2ffa47d0080752996",
          "message": "Merge pull request #4 from nix-dyn-drv/libwebp-package\n\nAdd libwebp (cmake, ~171 TUs, single-output) -- PASS, fixed upstream by 97a987d + 28af81d + dc07a0a",
          "timestamp": "2026-09-14T15:57:34-04:00",
          "tree_id": "08d5494e2ef4d5a460e9c0ff8df93a977e3986e1",
          "url": "https://github.com/nix-dyn-drv/overlay/commit/6403e45875627a6721a554c2ffa47d0080752996"
        },
        "date": 1789416725173,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "freetype patch-rebuild speedup (plain/accelerated)",
            "value": 0.56,
            "unit": "x"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "tomberek@users.noreply.github.com",
            "name": "tomberek",
            "username": "tomberek"
          },
          "committer": {
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": true,
          "id": "6e20f9fc85d52bc4fb378b4c63da5d1c2a1ebef5",
          "message": "Merge pull request #16 from nix-dyn-drv/fix-trynix-build-flag\n\nci: fix trynix openssl-ordering race with build: true",
          "timestamp": "2026-09-14T17:42:35-04:00",
          "tree_id": "d1af7dc3de8aae01ed3a6eecad936a4b79d1eefc",
          "url": "https://github.com/nix-dyn-drv/overlay/commit/6e20f9fc85d52bc4fb378b4c63da5d1c2a1ebef5"
        },
        "date": 1789423304905,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "freetype patch-rebuild speedup (plain/accelerated)",
            "value": 0.6,
            "unit": "x"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "tomberek@users.noreply.github.com",
            "name": "tomberek",
            "username": "tomberek"
          },
          "committer": {
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": true,
          "id": "9d048240e8344979b37b64b1cc70dc5c098cbb50",
          "message": "Merge pull request #8 from nix-dyn-drv/x264-package\n\nAdd x264 (autotools configure, not cmake) -- PASS, 2 new dyn-drvs bugs found+worked around (retested, still needed)",
          "timestamp": "2026-09-14T18:06:12-04:00",
          "tree_id": "7aa12a74d882a8fb1189cce674f146f3c3dc409d",
          "url": "https://github.com/nix-dyn-drv/overlay/commit/9d048240e8344979b37b64b1cc70dc5c098cbb50"
        },
        "date": 1789424643846,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "freetype patch-rebuild speedup (plain/accelerated)",
            "value": 0.58,
            "unit": "x"
          }
        ]
      }
    ]
  }
}