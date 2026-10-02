---
id: pf-2fkwhgm
title: Record the story on the real repos and push it
category: story
seq: 60
needs: [pf-1j0dnf1]
verify: contains story/recording.md /story\/3-resolved/
status: open
created: 2026-10-02T17:12Z
---
Run `story/replay.sh --record`. It writes `story/recording.md`: when it ran, the meshwork version, and the tags it pushed. Sync gains `v0.2.0` and `story/2-answer`; the cli gains `story/1-report` and `story/3-resolved`.

A re-record force-pushes `main`, the story tags and sync's `v0.2.0` back to `story/0-day0`.

## log
- 2026-10-02T17:12Z created
