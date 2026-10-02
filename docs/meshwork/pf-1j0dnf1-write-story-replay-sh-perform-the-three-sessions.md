---
id: pf-1j0dnf1
title: Write story/replay.sh — perform the three sessions and assert every refusal and red-check
category: story
seq: 50
needs: [pf-p0c5asg, pf-57vxppd]
verify: "all(exists story/replay.sh, contains story/replay.sh /mw_refused/)"
status: open
created: 2026-10-02T17:12Z
---
`story/replay.sh` performs the sessions with the real binary. Both modes share one implementation.

- **Default:** full clones of the three repos over https into a temp dir; cli and sync reset to `story/0-day0`, with `v0.2.0` and the later `story/*` tags deleted locally; a `repos.local.toml` mapping the names to the clones; local commits only. `--from DIR` uses existing checkouts.
- **`--record`:** fresh clones of the real repos at `story/0-day0`; regenerate and commit the fixture first; commit, tag and push after each session.
- **Binary:** the release in the clones' `.meshwork-version`, from `~/.meshwork/versions/<tag>/`, fetched over https when absent. `MESHWORK_BIN` overrides it.
- **Helpers:** `say`, `show`, `mw`, `mw_refused`, `mint`, `patch`, `session`, `expect`.
- **Assertions:** every refusal, every red-check, the prime and audit lines each session relies on, and `lint` exit 0 in each touched repo after each session.
- `--pause` waits for Enter between sessions.

## log
- 2026-10-02T17:12Z created
