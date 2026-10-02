A user's rewrite was lost. The report:

> At the gate I fixed a typo in a note on my laptop and let both devices sync. After takeoff I rewrote the note on my phone. When I landed and synced, my rewrite was gone and the laptop's version won.

The phone made its rewrite after it had synced the laptop's typo fix, so the rewrite should win on both devices. Both devices' change logs are attached.

Done when `reported_gate_rewrite_survives` passes. It replays the two logs on fresh device folders, with each device's clock reading what the log recorded and a sync wherever a log shows one, and expects both devices to end on the phone's rewrite.
