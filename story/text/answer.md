notes asks that a change always beat the changes its author had already stored. Wall-clock timestamps cannot promise that once a device's clock runs fast.

Stamp changes with a hybrid logical clock: the later of the device's wall clock and the newest timestamp it has stored, plus a counter that breaks ties. A change then sorts after everything its author had seen. Changes made without seeing each other still race on timestamp, and the protocol says so.

A timestamp is no longer the time a change was made; it can run ahead of every device's clock. Add a local `observed_at`, when this replica first stored the change, for anyone who needs to show when something happened. It is never sent.

v0.1 logs must still load: their changes read with counter 0, and their observed_at is their timestamp. This is a breaking change to what a timestamp means, so it ships as v0.2.0.
