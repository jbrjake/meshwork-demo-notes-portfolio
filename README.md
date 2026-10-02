# The meshwork notes demo

> **This is a demo.** Three public repos use [meshwork](https://github.com/jbrjake/meshwork) to track their work from their first commit. Their history up to the `story/0-day0` tags was built by real agent sessions. The three sessions after it are staged: `story/replay.sh` performs them with real meshwork commands, real code changes and real outputs, and you can run it yourself.

## The repos

| Repo | What it is | Task ids |
|---|---|---|
| [meshwork-demo-notes-cli](https://github.com/jbrjake/meshwork-demo-notes-cli) | `notes`, a command-line notes app that syncs between device folders | `nt-…` |
| [meshwork-demo-notes-sync](https://github.com/jbrjake/meshwork-demo-notes-sync) | notesync, the document replication library the app syncs through | `sy-…` |
| meshwork-demo-notes-portfolio (this repo) | `repos.toml`, the registry that lets tasks in one repo need, ask and pin specs in another; and the story | `pf-…` |

Each repo's tasks are markdown files under `docs/meshwork/`.

## The story

A user reports one lost edit: they fixed a typo on their laptop, synced, rewrote the note on their phone during a flight, and after landing the laptop's version won. That message is the only human input. Three agent sessions that never meet take it from there.

1. **notes-1**, in the app, opens a case closed by a test that re-enacts the report from the two devices' change logs. It blames the app's push-before-pull sync and reorders it; meshwork refuses the close, because the re-enactment still fails. The logs show the real cause: the laptop's clock runs five minutes fast, and notesync's last-writer-wins on wall-clock time lets the older typo fix beat the rewrite. That is the library's protocol, so notes-1 files an ask to notesync from its own store, pins the protocol clause it wants changed, and leaves a handoff.
2. **sync-1**, in the library, finds the ask in its queue. It stamps changes with hybrid logical clocks, adds a local `observed_at`, rewrites the protocol clauses, repins the day-0 task built on the conflict clause, and releases v0.2.0.
3. **notes-2**, back in the app, finds the ask answered and the clause it pinned moved. A portfolio-wide spec audit names a day-0 task built on the old sentence: the list's "edited N minutes ago" label, which now reads "edited in 5 minutes" for an edit made just now. notes-2 moves to v0.2.0, closes the ask, reopens and fixes the label, and closes the case.

The record stays queryable: the replay ends with one query over every status change and one over every comment, the smoking gun and its retraction included.

## Replay it

```
git clone https://github.com/jbrjake/meshwork-demo-notes-portfolio
cd meshwork-demo-notes-portfolio
story/replay.sh            # add --pause to step through the sessions
```

It needs bash, git, curl, cargo via rustup and the network. It clones the three repos into a temp dir, resets the app and the library to `story/0-day0`, fetches the meshwork release the repos pin, and plays the sessions with local commits only. It takes a couple of minutes, mostly building two small std-only crates, and deletes the temp dir when it ends. It fails loudly if any refusal, red-check, prime line or audit row the story relies on does not appear.

`MESHWORK_BIN=/path/to/meshwork story/replay.sh` runs a different meshwork build against the story.

## Read the recording

The recorded sessions are in the repos' history:

| Tag | Repo | After |
|---|---|---|
| `story/0-day0` | cli, sync | day 0: both built, backlogs open, notesync v0.1.0 |
| `story/1-report` | cli | notes-1: the case and the ask |
| `story/2-answer`, `v0.2.0` | sync | sync-1: hybrid logical clocks |
| `story/3-resolved` | cli | notes-2: the case closed |

`story/recording.md` says when it was recorded and on which meshwork release.

## What is here

- `repos.toml`: the registry. A machine that keeps the checkouts somewhere other than `~/Documents/code/<name>` maps them in a gitignored `repos.local.toml`.
- `story/replay.sh`: performs the sessions.
- `story/patches/`: each code change a session makes, against the tree it leaves.
- `story/text/`: what the sessions write: the report, the case, the ask, the handoffs, the comments.
- `story/fixture-gen/`, `story/fixtures/gate-rewrite/`: the two devices' change logs from the reported flight, generated on notesync v0.1.0.
- `docs/meshwork/`: this repo's own store, which tracked building the demo.
