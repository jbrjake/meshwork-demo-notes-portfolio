---
id: pf-1j0dnf1
title: Write story/replay.sh — perform the three sessions and assert every refusal and red-check
category: story
seq: 50
needs: [pf-p0c5asg, pf-57vxppd]
verify: "all(exists story/replay.sh, contains story/replay.sh /mw_refused/)"
status: done
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
- 2026-10-02T17:41Z open→doing — claimed by claude (602c381b-d7db-491e-8df6-85682e6152ed)
- 2026-10-02T17:46Z doing→done — verify exit 0 @ 593377b+1

## comments
- 2026-10-02T17:46Z [claude (602c381b-d7db-491e-8df6-85682e6152ed)] Replayed end to end on meshwork v0.5.2 with --from ~/Documents/code --local-sync, exit 0. Every expect held: the case's close refused after pull-first, the red-checks, the ask in sync's prime, S4 as the one re-open candidate, the answered ask with notes-1's handoff, the portfolio audit's stale (1) and re-open candidates (1), the label reading 'edited in 5 minutes' before the fix, and lint 0 per session. prime truncates the asks-out line before the answer's gid, so Beat 3 asserts the full 'answered-by … (done)' on show, which prints it whole. Code commits land before each close, so closes check a committed tree; reports/ stays untracked, as the user left it, and v0.5.2 notes it on each close.
