A user lost a rewrite they made on their phone after syncing it with their laptop. The phone's change log shows it stored the laptop's typo fix first and wrote the rewrite second. But the laptop's clock runs about five minutes fast, so the typo fix carries the later timestamp, and last-writer-wins on wall-clock time (PROTOCOL.md, Change timestamps and Conflict resolution) picks it on both devices.

Please order changes so that a change always beats the changes its author had already stored, whatever the device clocks say. Edits made without seeing each other can still race.

Your planned per-field merge would not save this one: both edits replaced the body.

Our contract test, `causal_order_survives_fast_clock`, pins the behaviour we need: a device with a fast clock writes, the other device syncs and then writes, and the second write must win on both. It fails on v0.1.0. When a release passes it, we will move to it and close this.
