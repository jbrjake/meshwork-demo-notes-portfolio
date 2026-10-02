//! Writes the gate-rewrite fixture: the change logs a laptop and a phone hold
//! after the lost edit the user reports.
//!
//! usage: fixture-gen OUT_DIR [--now MS]
//!
//! Let T be now minus four hours. The laptop's clock runs five minutes fast;
//! the phone's is true.
//! 1. At T the laptop creates the note (v1), and the two sync.
//! 2. At T+60m the laptop fixes a typo (v2, stamped T+65m), and the two sync.
//! 3. At T+63m the phone, offline, rewrites the note (v3, stamped T+63m).
//! 4. At T+180m the two sync. v2 wins on both, though v3 was written after it.

use notesync::{Clock, Fields, ManualClock, Replica, SystemClock};
use std::path::{Path, PathBuf};
use std::{env, fs, io, process};

const MINUTE: u64 = 60_000;
const NOTE: &str = "laptop-1";
const TITLE: &str = "Keynote outline";
const V1: &str = "Open with the demo, then the numbers. Close on the roadmpa.";
const V2: &str = "Open with the demo, then the numbers. Close on the roadmap.";
const V3: &str = "Open with the customer story. The demo comes second and the numbers last. End on the roadmap and one clear ask.";

fn main() {
    let args: Vec<String> = env::args().skip(1).collect();
    let (out, now) = match args.as_slice() {
        [out] => (PathBuf::from(out), SystemClock.now_ms()),
        [out, flag, ms] if flag == "--now" => match ms.parse() {
            Ok(ms) => (PathBuf::from(out), ms),
            Err(_) => usage(),
        },
        _ => usage(),
    };
    if let Err(e) = generate(&out, now) {
        eprintln!("fixture-gen: {e}");
        process::exit(1);
    }
}

fn usage() -> ! {
    eprintln!("usage: fixture-gen OUT_DIR [--now MS]");
    process::exit(2);
}

fn generate(out: &Path, now: u64) -> io::Result<()> {
    let t = now - 240 * MINUTE;
    let work = env::temp_dir().join(format!("fixture-gen-{}", process::id()));
    let _ = fs::remove_dir_all(&work);

    let laptop_clock = ManualClock::new(0);
    let phone_clock = ManualClock::new(0);
    let at = |minutes: u64| {
        laptop_clock.set(t + (minutes + 5) * MINUTE);
        phone_clock.set(t + minutes * MINUTE);
    };
    let mut laptop = Replica::open(&work.join("laptop"), &laptop_clock)?;
    let mut phone = Replica::open(&work.join("phone"), &phone_clock)?;

    at(0);
    laptop.put(NOTE, note(V1))?;
    sync(&mut laptop, &mut phone)?;

    at(60);
    laptop.put(NOTE, note(V2))?;
    sync(&mut laptop, &mut phone)?;

    at(63);
    phone.put(NOTE, note(V3))?;

    at(180);
    sync(&mut phone, &mut laptop)?;

    for replica in [&laptop, &phone] {
        let body = &replica.doc(NOTE).expect("the note").fields["body"];
        assert_eq!(body, V2, "the fixture must show the reported loss");
    }

    fs::create_dir_all(out)?;
    for device in ["laptop", "phone"] {
        fs::copy(
            work.join(device).join("changes.log"),
            out.join(format!("{device}-changes.log")),
        )?;
    }
    fs::remove_dir_all(&work)
}

fn note(body: &str) -> Fields {
    Fields::from([
        ("title".to_string(), TITLE.to_string()),
        ("body".to_string(), body.to_string()),
    ])
}

/// What the notes app does on sync: push what the other device lacks, then
/// pull what this one lacks.
fn sync<A: Clock, B: Clock>(local: &mut Replica<A>, other: &mut Replica<B>) -> io::Result<()> {
    other.apply(local.changes_since(&other.seen()))?;
    local.apply(other.changes_since(&local.seen()))?;
    Ok(())
}
