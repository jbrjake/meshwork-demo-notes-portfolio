---
id: pf-0ytxfev
title: Generate the gate-rewrite fixture from two notesync v0.1.0 replicas
category: story
seq: 20
verify: "all(exists story/fixtures/gate-rewrite/laptop-changes.log, exists story/fixtures/gate-rewrite/phone-changes.log)"
status: open
created: 2026-10-02T17:12Z
---
`story/fixture-gen/` is a small crate on notesync v0.1.0, by git tag. It drives a laptop replica and a phone replica with `ManualClock`s and writes their change logs to `story/fixtures/gate-rewrite/`.

Let T be the generation time minus four hours. The laptop's clock reads true plus five minutes; the phone's reads true.
1. At T the laptop creates "Keynote outline" (body v1), and the two sync.
2. At T+60m the laptop fixes a typo (body v2, stamped T+65m), and the two sync. The phone stores v2.
3. At T+63m the phone rewrites the note (body v3, stamped T+63m), offline.
4. At T+180m the two sync. v2 wins on both.

The phone's log then shows v2 stored before v3, while v3 carries the lower stamp. `story/replay.sh --record` regenerates the fixture right before the first session, so the reported flight sits hours before it.

## log
- 2026-10-02T17:12Z created
