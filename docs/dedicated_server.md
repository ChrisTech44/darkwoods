# Dedicated server edition

This checkout includes a dedicated authority for **1–4 human
survivors**. The server has no survivor and consumes no player slot. Use the
updated `main` client with rules **lnac-net-25**, with the same protocol.
Older clients must update. The server owns AI, movement validation, damage,
inventory, clues, objectives and extraction, using the same gameplay scene.

Woods now contains **31 creatures plus the Stalker**, including every roaming
and regional type on every seed, also during Blood Moon. Enemy replication uses
the seeded roster order, so update **both server and every client** to rules21;
older clients must not join with a smaller/different roster. Restart the server
after updating and confirm its `server_listening` line says `lnac-net-25`.

Trail exploration is shared by the whole team, including travel by humans other
than the server's reference survivor. Earlier rules-18 builds had an incomplete
coverage path; current server and clients both require lnac-net-25.
[Map replication checks](evidence/map_exploration/README.md).

## Run from source

Use Godot **4.7.2** and Python 3. From this checkout:

```sh
python3 tools/run_server.py --mode woods --port 27840 --min-players 2
```

On Genesect's Snap installation, prefix the command with
`GODOT_BIN=/snap/bin/godot-4` so noninteractive shells find the engine. After
friends finish the current night, stop the old process, pull the current branch,
update every player's `main` copy and relaunch with your usual options. Client
and server protocol must match lnac-net-25; older rules-17/18/19/20 clients cannot
join it. Diagnostics for this update did not restart the regular server.

The source launcher first runs Godot's headless import step to generate asset
imports and register script classes. A fresh clone has no `.godot` cache; starting
the game directly before importing can produce missing `LakeWater`, `StalkerTraits`
and `ServerRuntime` errors. Preparation runs on each source launch so updates are
rescanned. If import reports script errors, the launcher exits before starting the
server. The exported `--pack` path already contains imports and skips this step.

If using Godot directly rather than the launcher, prepare the checkout first:

```sh
godot --headless --audio-driver Dummy --path . --import
```

Stop any process that printed script errors even if it later printed
`server_listening`: that message confirms the UDP socket, not successful gameplay
compilation. Keep the complete import output if preparation still fails.

For four friends use `--min-players 4`; for solo testing use `--min-players 1`.
A `server_listening` JSON line confirms binding. The server listens on available
interfaces. No graphical window, microphone capture, speaker playback or native
voice codec is initialized. The launcher always selects headless display and
Dummy audio, including when that computer has saved voice preferences.

| Option | Default | Meaning |
| --- | --- | --- |
| `--port` | `27840` | UDP port, 1–65535 |
| `--mode` | `woods` | `woods` or `camp` |
| `--seed` | `0` | Fresh random seed each round; positive seed repeats that layout |
| `--min-players` | `1` | Required human count, 1–4 |
| `--start-delay` | `3` | Seconds all connected players must remain ready, 1–60 |
| `--result-delay` | `15` | Seconds results remain before returning to the lobby, 3–300 |
| `--no-camper-abilities` | off | Disable every camper passive/active and starting cash/sample; ordinary survival and monster powers remain |

The ability rule is advertised to clients, locked for each round and survives
automatic lobby resets. Guests cannot re-enable it. Use the same flag after `--`
when launching Godot directly. [Ability rules](ability_feedback_review.md).

All players use **Host / Join Co-op**, enter the server address and UDP port,
press **Join**, choose their survivor and mark **Ready**. Nobody presses Host or
Start. The server starts automatically after the minimum count is reached and
**every connected player** remains ready for the countdown. Joining or becoming
unready cancels it. Set the minimum to your whole group to prevent an early start.

Results return everyone to the lobby automatically; mark Ready for the next night.
The client’s host-only results buttons remain unavailable. New arrivals still wait for the lobby. Existing clients can automatically recover
their survivor with an in-memory ticket for five minutes after an unexpected drop.
No crash persistence, password, matchmaking or host migration is added. The
server keeps running when a client leaves; departed gear drops for teammates.
When everybody deliberately leaves, the world clears. If everyone unexpectedly
disconnects, the round pauses until somebody returns or all five-minute
reservations expire. Items drop immediately; reconnect never duplicates them.
A loading timeout resets the lobby and readiness rather than ending the server.
Initial graphical loading retains a 90s allowance. During play, fifteen seconds
without input packets triggers removal and reservation; idle players still send
packets continuously. Transport failures may also be detected earlier by ENet.

## Connect over a network

LAN guests use the server machine’s LAN address. Internet guests need a reachable
server address and its UDP port allowed through the firewall; home servers also
need UDP port forwarding. Carrier-grade NAT can prevent direct hosting. An
existing trusted VPN is another option. A dedicated server does not automatically
provide NAT traversal, a relay or better latency; placement and connection
quality still matter. Gameplay and existing voice transport are unencrypted.

The existing ENet peer relay forwards client voice RPCs; the dedicated process
never captures, decodes or plays voice. The client keeps its opt-in controls and
positional/spectator playback rules. Real-microphone and listening acceptance
remain separate; synthetic gameplay tests do not establish voice quality.

## Portable package / Linux operation

```sh
python3 tools/package_server.py
```

This writes `artifacts/server/last-night-server.zip`: a server PCK, shell launcher,
build metadata and this guide. Metadata records the actual engine build, protocol,
source commit and whether the checkout was dirty. Export runs in a fresh staging
directory, validates the new PCK and replaces the ZIP last; failed exports preserve
the previous bundle. The historical rules21 package was built from clean runtime
commit `787e98b` and passed all 153 dedicated/four-client checks, including the full
roster; [current metadata and hashes](evidence/full_roster/package.json).
The earlier rules20 package was built from clean runtime commit `4e5d119`;
its [metadata and hashes](evidence/server_review/package_build.json) are historical.
Rebuild with the command above for the current full-roster rules21 server. **It requires Godot 4.7.2 installed on the target
OS**; it does not bundle an untested native engine binary. On Linux, unpack it,
make the launcher executable if necessary, and run:

```sh
chmod +x run-server.sh
./run-server.sh --mode woods --port 27840 --min-players 4
```

Set `GODOT_BIN` to the engine executable if it is not named `godot`. From a source
checkout, `python3 tools/run_server.py --pack artifacts/server/last-night-server.pck`
also runs the exported pack. Client rendering resources are retained where scene
loading needs them; this first server package is not a claim of minimum RAM.
Keep the engine and pack together at the documented version. Stop with Ctrl+C.

For an unattended Linux host, run that launcher as an unprivileged service under
your normal service manager with a writable user-data directory and restart on
failure. Keep the selected UDP port open; preserve console logs for diagnosis.
Monitor `server_status`, `server_ready_countdown`, `server_results` and
`server_loading_timeout`. Fatal configuration/bind errors exit nonzero.

## Verification limits

See the development log for exact executed checks. A Linux Snap Godot 4.7.2 Mono
source server on Genesect was tested across the real network with one/four macOS
source clients, including normal graphical rendering. The rules-18 PCK was also executed under the Linux Snap runtime with four main
source clients across the real connection; all 69 lifecycle assertions passed.
See [smoothness/package evidence](evidence/smoothness/README.md). This does not
establish Windows, exported clients, general Internet routing, sustained load
or human listening acceptance. Implementation diagnostics used a separate project-local copy and spare port.
A subsequent [post-restart verification](evidence/production_verification/README.md)
measured the regular server, including matched external/loopback clients; external
multi-second stalls remained while loopback delivery stayed steady.
No hosting account was provisioned. See the
[network investigation](network_lag_investigation.md) for timings and limits.
The October 19 review reproduced and fixed the simultaneous-disconnect channel-0
error. The ENet delegate filters packets to native peers whose channels have
already closed, while retaining server relay for client-to-client traffic.
Source and exported-PCK four-player runs now pass the strict error-free gate,
including all four distinct roles, projectile/status/sound replication, copied
song cleanup, synthetic channel-3 relay, extraction, another round and simultaneous
leaves. Microphone capture was disabled. This local macOS acceptance does not
extend the earlier Linux/network results to the new build. See the
[server review and execution evidence](server_review.md).

Player poses now use an independent 30Hz stream; full world state uses 20Hz
unordered fragments. Both clients and server must update to rules lnac-net-25 and
the server must restart before updated clients join. Bounded local prediction, acknowledged reconciliation and buffered remote motion
are implemented; the client also avoids unchanged pickup/site redraws. See the
[smoothness measurements](evidence/smoothness/README.md). The main client also
includes the first-frame scenery preparation fix. These changes do not establish
generally improved Internet latency or eliminate all player corrections.

[20 October reconnect/watchdog investigation and acceptance](playtest_followup.md#disconnect-investigation-and-implemented-recovery). Update clients and authority together to rules22.

The rules22 changes require a fresh source launch or rebuilt package; this increment
does not replace the earlier local rules21 ZIP/PCK or deploy a running server.
