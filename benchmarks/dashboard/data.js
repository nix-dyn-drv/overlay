window.BENCHMARK_DATA = {
  "lastUpdate": 1789337203030,
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
      }
    ]
  }
}