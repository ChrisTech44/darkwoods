# Client trail exploration — 18 October 2026

Reproduced against the previous committed server code: an ordinary non-reference
survivor occupied a woods cell, but its visit was not recorded and WorldSync had
no exploration field. With the fix, both checks succeed.
[Before/after diagnostics](reproduction.json).

Authority now records occupied cells for every living/downed survivor. Clients
receive shared team coverage in each complete world snapshot, in a fixed 307-byte
bitmap before normal compression. Unchanged received bitmaps reuse the map data;
missed snapshots recover from the next complete state. No discovery RPC or
client-position claim is added. The existing client simulation guard remains:
predicted travel does not reveal cells. Escaped/dead/boarded actors do not explore.
Clue/cache reveal rules, printed roads/regions and map layout remain unchanged.
Snare placement already consults explored cells; it now correctly includes paths
walked by any teammate. New nights clear exploration and the receive cache.

[Real ENet graphical Woods report](listen_summary.json): 258 assertions, clean.
A host stages only the guest at the west trail mouth while remaining in camp.
The guest walks left with normal controls across a cell boundary; server records
it and the client notebook receives both cells, while unrelated cells stay hidden.
[Before walking](client_before.png), [after walking](client_after.png), both actual
Mac Godot4.7.2 captures inspected. Notebook is at normal local zoom and lighting;
no extra light. Wider authority fixture uses seed42, forced all escapes, frozen
enemies and staged host positions; these are not ordinary playthrough captures.
Microphones/voice are off, Dummy audio. Earlier motion/outage/forgery/extraction/
restart checks remain in the same graphical suite.

Focused map assertions15 and notebook assertions21 also pass; imports/startup,
Python syntax and diff/link checks clean. Full-map round trip covers all2410
valid cells, padding/camp rejection, malformed lengths, missed-state recovery and
new-layout reset. No broad suite or Internet-path performance claim. The extra
snapshot field is optional and backward compatible within rules18; both server
and clients must update to receive this fix. An older server sends no coverage.
Dedicated acceptance is recorded on headless-server after merging this increment.
