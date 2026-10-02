#!/usr/bin/env bash
# Performs the notes story: three staged agent sessions across the demo repos,
# every command run through the real meshwork binary.
#
#   story/replay.sh [--from DIR] [--local-sync] [--pause] [--keep]
#   story/replay.sh --record [--rerecord]
#
# By default it clones the three repos over https into a temp dir, resets the
# app and the library to day 0, plays the sessions with local commits only,
# and deletes the temp dir. --from DIR clones the checkouts under DIR instead.
# --local-sync builds the app against this run's own notesync instead of the
# v0.2.0 tag on GitHub. --pause waits for Enter between sessions. --keep
# leaves the temp dir behind.
#
# --record plays the sessions on the real repos and pushes each one: it
# regenerates the fixture, commits and tags as the sessions go, and writes
# story/recording.md. --rerecord first resets the app and the library to
# story/0-day0 on GitHub, force-pushing over an earlier recording.
#
# MESHWORK_BIN runs a candidate meshwork build instead of the release the
# repos pin. Needs bash, git, curl, cargo via rustup, and the network.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
STORY=$ROOT/story
GH=https://github.com/jbrjake
PF=meshwork-demo-notes-portfolio
CLI=meshwork-demo-notes-cli
SYNC=meshwork-demo-notes-sync
TRAILER="Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"

MODE=replay FROM= LOCAL_SYNC= PAUSE= KEEP= RERECORD=
while [ $# -gt 0 ]; do
  case $1 in
    --from) FROM=$(cd "$2" && pwd); shift ;;
    --local-sync) LOCAL_SYNC=1 ;;
    --pause) PAUSE=1 ;;
    --keep) KEEP=1 ;;
    --record) MODE=record ;;
    --rerecord) RERECORD=1 ;;
    -h|--help) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "replay: unknown option $1" >&2; exit 2 ;;
  esac
  shift
done
if [ "$MODE" = record ] && { [ -n "$FROM" ] || [ -n "$LOCAL_SYNC" ]; }; then
  echo "replay: --record works on the real repos; drop --from and --local-sync" >&2
  exit 2
fi

# Builds land in each clone's target/, the same place meshwork's verify runs
# build, so nothing compiles twice.
unset CARGO_TARGET_DIR RUSTFLAGS RUSTDOCFLAGS CARGO_BUILD_RUSTFLAGS

WORK=$(mktemp -d "${TMPDIR:-/tmp}/notes-story.XXXXXX")
TEXT=$WORK/text
LAST=$WORK/last.out
FINISHED=
cleanup() {
  local rc=$?
  # bash 3.2 reports 0 here after a `set -u` exit, so an unfinished run fails.
  if [ -z "$FINISHED" ] && [ "$rc" -eq 0 ]; then rc=1; fi
  if [ -n "$KEEP" ]; then echo "kept $WORK"; else rm -rf "$WORK"; fi
  exit "$rc"
}
trap cleanup EXIT

# ---- output ---------------------------------------------------------------

die() { printf '\nreplay: %s\n' "$*" >&2; exit 1; }

# Narration, in plain voice.
say() { printf '\n'; printf '%s\n' "$*" | fold -s -w 76 | sed 's/^/# /'; }

# A command line as it would be typed. Paths into the session's notes read as
# the bare file name, the way the session wrote them.
show() {
  local line= arg
  for arg in "$@"; do
    arg=${arg//$TEXT\//}
    case $arg in
      '') arg='""' ;;
      *[[:space:]\'\"\$\`\(\)\;\|\&\<\>\*\?\!]*) arg="\"${arg//\"/\\\"}\"" ;;
    esac
    line+=" $arg"
  done
  printf '$%s\n' "$line"
}

banner() {
  printf '\n%s\n %s\n%s\n' "$(printf '=%.0s' {1..76})" "$*" "$(printf '=%.0s' {1..76})"
}

pause() {
  if [ -n "$PAUSE" ]; then read -r -p "[enter] " _ </dev/tty; fi
}

# ---- meshwork -------------------------------------------------------------

# Runs a verb; it must succeed.
mw() {
  show meshwork "$@"
  local rc=0
  "$MW" "$@" >"$LAST" 2>&1 || rc=$?
  cat "$LAST"
  [ "$rc" -eq 0 ] || die "meshwork $1 exited $rc"
}

# Runs a verb that must refuse.
mw_refused() {
  show meshwork "$@"
  local rc=0
  "$MW" "$@" >"$LAST" 2>&1 || rc=$?
  cat "$LAST"
  [ "$rc" -ne 0 ] || die "meshwork $1 should have refused, and it passed"
  printf '(exit %s: refused, as it should be)\n' "$rc"
}

# Runs `add` and stores the minted id in the named variable.
mint() {
  local var=$1; shift
  mw "$@"
  local id
  id=$(sed -n 1p "$LAST")
  [[ $id =~ ^[a-z]+-[0-9a-z]+$ ]] || die "add printed no id: $id"
  printf -v "$var" '%s' "$id"
}

# The id of the task titled exactly $1 in the current repo's store.
lookup() {
  local title=${1//\'/\'\'} id
  id=$("$MW" q "SELECT id FROM tasks WHERE title = '$title'" | sed -n 2p | tr -d ' ')
  [[ $id =~ ^[a-z]+-[0-9a-z]+$ ]] || die "no task titled: $1"
  printf '%s' "$id"
}

# The last command's output must carry this text.
expect() {
  grep -qF -- "$1" "$LAST" || die "expected the output above to show: $1"
}

expect_not() {
  ! grep -qF -- "$1" "$LAST" || die "expected the output above not to show: $1"
}

# ---- the sessions' hands --------------------------------------------------

session() {
  SESSION=$1
  export MESHWORK_AUTHOR="claude ($1)"
  cd "$WORK/$2"
  # Sessions happen at different times. Stamps have minute resolution, so a
  # recording starts each one on a fresh minute and the record reads in order.
  if [ "$MODE" = record ]; then sleep $((61 - 10#$(date +%S))); fi
  banner "Session $1 · $2 · a fresh agent session"
}

# Applies a story patch with this run's ids in place of its placeholders.
patch() {
  local file=$WORK/$1.patch
  sed -e "s/@CASE@/${CASE:-}/g" -e "s/@ASK@/${ASK:-}/g" "$STORY/patches/$1.patch" >"$file"
  show git apply "$1.patch"
  git apply --stat "$file" | sed 's/^/ /'
  git apply "$file"
}

# Runs cargo test on a filter and shows the outcome: results, and the
# message of any failure.
cargo_test() {
  show cargo test "$@"
  local rc=0
  cargo test -q "$@" >"$LAST" 2>&1 || rc=$?
  grep -E -A2 '^thread .* panicked at' "$LAST" | grep -v -e '^--$' -e 'RUST_BACKTRACE' || true
  grep -E '^test result:' "$LAST" | grep -v ' 0 passed; 0 failed' || true
  return "$rc"
}

# Commits the given paths with the session's trailer.
commit() {
  local subject=$1 footer=$2; shift 2
  git add -- "$@"
  show git commit -m "$subject"
  local trailers="Staged-session: $SESSION"$'\n'"$TRAILER"
  if [ -n "$footer" ]; then trailers="$footer"$'\n'"$trailers"; fi
  git commit -q -m "$subject" -m "$trailers"
  git log --oneline -1
}

tag() {
  show git tag "$1"
  git tag -a "$1" -m "$1"
}

lint_clean() {
  local repo
  for repo in "$@"; do
    if [ "$WORK/$repo" = "$PWD" ]; then
      show meshwork lint
    else
      printf '$ (cd ../%s && meshwork lint)\n' "$repo"
    fi
    (cd "$WORK/$repo" && "$MW" lint) || die "lint failed in $repo"
  done
}

push() {
  [ "$MODE" = record ] || return 0
  local repo=$1; shift
  if [ -n "$RERECORD" ]; then
    git -C "$WORK/$repo" push -q --force origin main "$@"
  else
    git -C "$WORK/$repo" push -q origin main "$@"
  fi
  echo "(pushed $repo: main $*)"
}

# ---- setup ----------------------------------------------------------------

fetch_binary() {
  local ver=$1 target
  case "$(uname -s)-$(uname -m)" in
    Darwin-arm64) target=aarch64-apple-darwin ;;
    Linux-aarch64|Linux-arm64) target=aarch64-unknown-linux-gnu ;;
    Linux-x86_64) target=x86_64-unknown-linux-gnu ;;
    *) die "meshwork $ver has no release binary for $(uname -s) $(uname -m); set MESHWORK_BIN" ;;
  esac
  mkdir -p "$HOME/.meshwork/versions/$ver"
  curl -fsSL "https://github.com/jbrjake/meshwork/releases/download/$ver/meshwork-$ver-$target.tar.gz" |
    tar -xz -C "$HOME/.meshwork/versions/$ver"
}

remote_sha() { git ls-remote "$GH/$1.git" "$2" | cut -f1; }

check_recordable() {
  [ -z "$(git -C "$ROOT" status --porcelain)" ] || die "--record commits to $ROOT; it has uncommitted changes"
  git -C "$ROOT" fetch -q origin
  [ "$(git -C "$ROOT" rev-parse HEAD)" = "$(git -C "$ROOT" rev-parse origin/main)" ] ||
    die "--record needs $ROOT at origin/main"
  local repo day0 main
  for repo in "$CLI" "$SYNC"; do
    day0=$(remote_sha "$repo" 'refs/tags/story/0-day0^{}')
    main=$(remote_sha "$repo" refs/heads/main)
    if [ "$main" != "$day0" ] || [ -n "$(git ls-remote --tags "$GH/$repo.git" 'story/[123]-*' v0.2.0)" ]; then
      [ -n "$RERECORD" ] || die "$repo is already past day 0 on GitHub; --rerecord resets it"
    fi
  done
}

reset_remote() {
  local repo=$1 day0 ref
  day0=$(git -C "$WORK/$repo" rev-parse 'story/0-day0^{commit}')
  git -C "$WORK/$repo" push -q --force origin "$day0:refs/heads/main"
  for ref in $(git -C "$WORK/$repo" tag -l 'story/*' v0.2.0); do
    [ "$ref" = story/0-day0 ] || git -C "$WORK/$repo" push -q origin ":refs/tags/$ref"
  done
  echo "(reset $repo on GitHub to story/0-day0)"
}

setup() {
  [ "$MODE" = record ] && check_recordable
  local repo src
  for repo in "$PF" "$CLI" "$SYNC"; do
    if [ -n "$FROM" ]; then src=$FROM/$repo; else src=$GH/$repo.git; fi
    git clone -q "$src" "$WORK/$repo" || die "could not clone $src"
  done
  for repo in "$CLI" "$SYNC"; do
    [ "$MODE" = record ] && [ -n "$RERECORD" ] && reset_remote "$repo"
    git -C "$WORK/$repo" checkout -q -B main story/0-day0
    for ref in $(git -C "$WORK/$repo" tag -l 'story/*' v0.2.0); do
      [ "$ref" = story/0-day0 ] || git -C "$WORK/$repo" tag -d "$ref" >/dev/null
    done
  done
  printf '[paths]\n%s = "%s"\n%s = "%s"\n%s = "%s"\n' \
    "$PF" "$WORK/$PF" "$CLI" "$WORK/$CLI" "$SYNC" "$WORK/$SYNC" >"$WORK/$PF/repos.local.toml"
  export MESHWORK_PORTFOLIO=$WORK/$PF

  local ver
  ver=$(cat "$WORK/$CLI/.meshwork-version")
  MW=${MESHWORK_BIN:-$HOME/.meshwork/versions/$ver/meshwork}
  if [ -z "${MESHWORK_BIN:-}" ] && [ ! -x "$MW" ]; then fetch_binary "$ver"; fi
  [ -x "$MW" ] || die "no meshwork binary at $MW"

  if [ -z "$(git config user.email || true)" ]; then
    export GIT_AUTHOR_NAME="notes story replay" GIT_AUTHOR_EMAIL="replay@localhost"
    export GIT_COMMITTER_NAME=$GIT_AUTHOR_NAME GIT_COMMITTER_EMAIL=$GIT_AUTHOR_EMAIL
  fi

  mkdir -p "$TEXT"
  cp "$STORY"/text/*.md "$TEXT/"

  if [ "$MODE" = record ]; then
    (cd "$STORY/fixture-gen" && cargo run -q -- ../fixtures/gate-rewrite)
    git -C "$ROOT" add story/fixtures
    git -C "$ROOT" commit -q -m "chore(story): regenerate the gate-rewrite fixture for the recording" -m "$TRAILER"
    git -C "$ROOT" push -q origin main
  fi
  RECORDED_AT=$(date -u +%Y-%m-%dT%H:%MZ)
}

# ---- the story ------------------------------------------------------------

day0() {
  banner "Day 0"
  say "Three repos track their work with meshwork from their first commit: notes, a command-line notes app; notesync, the replication library it syncs through; and this portfolio, which registers both. Here is what each has on its plate."
  cd "$WORK/$CLI"
  mw portfolio ready
  expect "Merge per field so concurrent edits to different fields both survive"
  expect "Search notes by text"
}

beat1() {
  session notes-1 "$CLI"
  START=$(date -u +%Y-%m-%dT%H:%MZ)
  say "The session starts the way every session does: the plugin's hook injects prime."
  mw prime

  say "The one human input in the whole story is this message:"
  sed 's/^/> /' "$TEXT/report.md"
  mkdir -p reports/gate-rewrite
  cp "$STORY"/fixtures/gate-rewrite/*.log reports/gate-rewrite/
  show ls reports/gate-rewrite
  ls reports/gate-rewrite

  say "notes-1 writes its notes to files and passes them with @file. It opens a case, closed by a test that re-enacts the report."
  mint CASE add "Stop edits made after a sync losing to older ones" --cat sync --seq 10 \
    --body "@$TEXT/case.md" --verify "run cargo test reported_gate_rewrite_survives"
  mw attach "$CASE" reports/gate-rewrite/laptop-changes.log
  mw attach "$CASE" reports/gate-rewrite/phone-changes.log

  say "The test replays both logs on fresh device folders, each clock reading what its log recorded, syncing through the app's own sync wherever a log shows one. It expects the phone's rewrite to survive."
  show mkdir -p tests/notes/fixtures/gate-rewrite
  mkdir -p tests/notes/fixtures/gate-rewrite
  show cp reports/gate-rewrite/laptop-changes.log reports/gate-rewrite/phone-changes.log tests/notes/fixtures/gate-rewrite/
  cp reports/gate-rewrite/*.log tests/notes/fixtures/gate-rewrite/
  patch 1a-cli-reenact

  say "start claims the case and red-checks its verify: the test must fail before the fix."
  mw start "$CASE"
  expect "open→doing"
  expect_not "already green"

  say "The app's sync pushes before it pulls. That looks like the answer."
  mw comment "$CASE" "Smoking gun: notes sync pushes before it pulls, so the laptop's typo fix lands on top of the rewrite. Pulling first."
  patch 1b-cli-pull-first
  show git diff
  git --no-pager diff

  say "close runs the verify. The re-enactment still fails, so meshwork keeps the case open."
  mw_refused close "$CASE"
  "$MW" show "$CASE" >"$LAST" 2>&1
  expect "[doing]"
  cargo_test reported_gate_rewrite_survives && die "the re-enactment should still fail with pull-first"
  expect "the laptop lost the phone's rewrite"
  show git checkout -- src/sync.rs
  git checkout -- src/sync.rs

  say "Back to the evidence. The first three columns of the phone's log: device, sequence number, timestamp."
  show cut -f1-3 reports/gate-rewrite/phone-changes.log
  cut -f1-3 reports/gate-rewrite/phone-changes.log
  say "The phone stored the laptop's change 2 before it wrote its own change 1, yet its change carries the lower timestamp."
  mw comment "$CASE" "@$TEXT/diagnosis.md"

  say "Is a fix already planned somewhere?"
  mw portfolio search merge
  TITLE=$(lookup "Keep a rename when another device edits the note's body at the same time")
  mw why "$TITLE"
  PFM=$(cd "$WORK/$SYNC" && lookup "Merge per field so concurrent edits to different fields both survive")
  expect "$SYNC#$PFM (open)"
  say "Per-field merge is planned, but it would not help here: both edits replaced the body. notes-1 asks the library instead, from its own store."

  mint ASK add "Order changes so an edit always beats the changes its author had already seen" \
    --to "$SYNC" --parent "$CASE" --seq 20 --body "@$TEXT/ask.md" \
    --verify "run cargo test causal_order_survives_fast_clock"
  say "It pins the protocol clause it is asking to change, so a change to that clause shows up here."
  mw cover "$ASK" "$SYNC#docs/PROTOCOL.md#sp-change-timestamp"

  say "A contract test states what the app needs from the library. It fails on v0.1.0."
  patch 1c-cli-contract
  cargo_test causal_order_survives_fast_clock && die "the contract should fail on notesync v0.1.0"

  mw tree "$CASE"
  mw ready
  expect "asks out (1)"
  expect "$ASK"
  mw set "$ASK" --handoff "@$TEXT/handoff.md"

  say "The two tests wait on the ask, so main stays green."
  patch 1d-cli-wait-on-ask
  commit "chore(store): open the gate-rewrite case and ask notesync for causal ordering" "" docs/meshwork
  commit "test(sync): re-enact the reported gate rewrite and pin the causal-order contract" "" tests
  tag story/1-report
  lint_clean "$CLI"
  push "$CLI" story/1-report
  pause
}

beat2() {
  session sync-1 "$SYNC"
  mw prime
  expect "addressed to this repo (1)"
  expect "$CLI#$ASK"

  say "sync-1 reads the ask where it lives, in the app's store."
  printf '$ (cd ../%s && meshwork show %s)\n' "$CLI" "$ASK"
  (cd "$WORK/$CLI" && "$MW" show "$ASK")

  mint ANSWER add "Stamp changes with hybrid logical clocks" --cat protocol --seq 5 \
    --answers "$CLI#$ASK" --body "@$TEXT/answer.md" \
    --verify "all(run cargo test change_sorts_after_everything_its_author_saw, run cargo test v1_log_reads_with_counter_zero, run cargo test observed_at_is_local)"
  patch 2a-sync-hlc-tests
  mw start "$ANSWER"
  expect_not "already green"
  patch 2b-sync-hlc

  say "The protocol is the contract, so its diff is the heart of the change."
  show git diff -- docs/PROTOCOL.md
  git --no-pager diff -- docs/PROTOCOL.md

  mw cover "$ANSWER" docs/PROTOCOL.md#sp-change-timestamp
  mw cover "$ANSWER" docs/PROTOCOL.md#sp-conflict-resolution
  mw cover "$ANSWER" docs/PROTOCOL.md#sp-observed-at

  say "What else was built on the clauses that just changed?"
  S4=$(lookup "Resolve conflicting changes last-writer-wins by timestamp")
  mw spec audit docs/PROTOCOL.md
  expect "re-open candidates (1)"
  expect "$S4"
  show sed -n '/sp-conflict-resolution/,/^$/p' docs/PROTOCOL.md
  sed -n '/sp-conflict-resolution/,/^$/p' docs/PROTOCOL.md
  say "Last-writer-wins by timestamp still holds; only its caveat changed. The day-0 task is repinned, not reopened."
  mw cover "$S4" --repin

  cargo_test
  commit "test(protocol): pin hybrid logical clock ordering, v0.1 logs, and local observed time" "" tests
  commit "feat(protocol)!: stamp changes with hybrid logical clocks" \
    "BREAKING CHANGE: a change's timestamp is a hybrid logical clock reading, not wall-clock time; it can run ahead of every device's clock. Use Doc::observed_at_ms() to show when something happened." \
    src docs/PROTOCOL.md README.md
  commit "chore(release): v0.2.0" "" Cargo.toml Cargo.lock CHANGELOG.md
  tag v0.2.0

  mw close "$ANSWER"
  expect "verify exit 0"
  mw set "$PFM" --handoff "@$TEXT/pfm-handoff.md"
  commit "chore(store): answer notes' causal-ordering ask; repin the conflict task; hand off per-field merge" "" docs/meshwork
  tag story/2-answer
  lint_clean "$SYNC"
  push "$SYNC" v0.2.0 story/2-answer
  pause
}

beat3() {
  session notes-2 "$CLI"
  mw prime
  expect "spec moved under 1 live task"
  expect "doing $CASE"
  expect "[claimed: claude (notes-1)]"
  expect "asks out (1)"
  expect "· answered-by "
  say "The ask is answered, and notes-1 left a handoff on it."
  mw show "$ASK"
  expect "answered-by $SYNC#$ANSWER (done)"
  expect "Not sync order: pull-first changed nothing"

  say "The clause the ask pinned has moved. Here it is now:"
  show sed -n '/sp-change-timestamp/,/^$/p' "../$SYNC/docs/PROTOCOL.md"
  sed -n '/sp-change-timestamp/,/^$/p' "$WORK/$SYNC/docs/PROTOCOL.md"

  say "What else in the portfolio was built on that clause?"
  LABEL=$(lookup "Show when each note was last edited in list")
  mw portfolio spec audit "$SYNC#docs/PROTOCOL.md"
  expect "stale (1)"
  expect "re-open candidates (1)"
  expect "$LABEL"

  say "First, take the answer: move to notesync v0.2.0 and stop ignoring the two tests."
  patch 3a-cli-notesync-v0.2
  if [ -n "$LOCAL_SYNC" ]; then
    export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0="url.$WORK/$SYNC.insteadOf" \
      GIT_CONFIG_VALUE_0="$GH/$SYNC" CARGO_NET_GIT_FETCH_WITH_CLI=true
  fi
  show cargo build
  cargo build -q 2>&1 | grep -v '^ *Updating\|^ *Locking\|^ *Adding\|^ *Updating git' || true
  commit "fix(deps): move to notesync v0.2.0 so an edit beats the changes it had seen" "" \
    Cargo.toml Cargo.lock tests/notes/contract.rs tests/notes/report.rs
  mw cover "$ASK" --repin
  mw close "$ASK"
  expect "verify exit 0"

  say "Under v0.2.0 a timestamp \"can run ahead of any device's clock\", and the day-0 list label reads it. notes-2 reopens that task under the case."
  mw reopen "$LABEL"
  mw comment "$LABEL" "@$TEXT/label-reopen.md"
  mw set "$LABEL" --parent "$CASE"
  patch 3b-cli-label-test
  cargo_test edited_label_never_reads_ahead && die "the label should read ahead on notesync v0.2.0"
  expect "edited in 5 minutes"
  mw start "$LABEL"
  expect_not "already green"
  patch 3c-cli-label-observed
  commit "fix(list): show edit times from when this device stored the change" "" src tests/notes/label.rs
  mw cover "$LABEL" --repin
  mw close "$LABEL"
  expect "verify exit 0"

  say "With the ask answered and the label fixed, the re-enactment passes."
  mw close "$CASE"
  expect "verify exit 0"
  mw tree "$CASE"
  commit "chore(store): close the gate-rewrite case" "" docs/meshwork
  tag story/3-resolved
  lint_clean "$CLI" "$SYNC"
  push "$CLI" story/3-resolved
  pause
}

epilogue() {
  banner "Epilogue · the record"
  cd "$WORK/$CLI"
  say "No session. Every status change since the report, across the portfolio:"
  mw portfolio q "SELECT gid, date, to_status, note FROM log WHERE to_status IS NOT NULL AND date >= '$START' ORDER BY date, gid, ord"
  say "And what the sessions said, including the smoking gun and its retraction:"
  mw portfolio q "SELECT gid, author, text FROM comments WHERE date >= '$START' ORDER BY date, gid, ord"
  expect "Smoking gun"
  expect "Wrong: notesync"
}

record_finish() {
  [ "$MODE" = record ] || return 0
  local ver
  ver=$("$MW" --version 2>/dev/null || cat "$WORK/$CLI/.meshwork-version")
  cat >"$STORY/recording.md" <<EOF
# Recording

- Recorded: $RECORDED_AT
- meshwork: $ver
- $CLI: story/1-report, story/3-resolved
- $SYNC: v0.2.0, story/2-answer
EOF
  git -C "$ROOT" add story/recording.md
  git -C "$ROOT" commit -q -m "chore(story): record the story — story/3-resolved" -m "$TRAILER"
  git -C "$ROOT" push -q origin main
  echo "(recorded: story/recording.md)"
}

setup
day0
pause
beat1
beat2
beat3
epilogue
record_finish
banner "Done"
FINISHED=1
