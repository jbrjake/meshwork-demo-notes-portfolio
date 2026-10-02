---
id: pf-p0c5asg
title: Write the code changes each session makes as patches against day 0
category: story
seq: 30
needs: [pf-0ytxfev, meshwork-demo-notes-sync#sy-cbnfwt3, meshwork-demo-notes-cli#nt-4gtpn48]
verify: "all(exists story/patches/1a-cli-reenact.patch, exists story/patches/2b-sync-hlc.patch, exists story/patches/3c-cli-label-observed.patch)"
status: open
created: 2026-10-02T17:12Z
---
One patch per code step under `story/patches/`, named `<beat><step>-<repo>-<slug>.patch`:
- notes-1: `1a-cli-reenact`, `1b-cli-pull-first`, `1c-cli-contract`, `1d-cli-wait-on-ask`
- sync-1: `2a-sync-hlc-tests`, `2b-sync-hlc`
- notes-2: `3a-cli-notesync-v0.2`, `3b-cli-label-test`, `3c-cli-label-observed`

Each applies cleanly to the tree its session leaves. Task ids appear only as placeholders (`@CASE@`, `@ASK@`), because ids mint fresh on every run.

`3b` and `3c` build against notesync v0.2.0 before that tag exists. Write them against a local sync checkout with `2b` applied, through a `[patch]` in a scratch cargo config that is never committed.

## log
- 2026-10-02T17:12Z created
