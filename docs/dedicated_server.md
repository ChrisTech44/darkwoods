# Dedicated server edition

This branch (`headless-server`) adds a dedicated authority for **1–4 human
survivors**. The server has no survivor and consumes no player slot. Use the
updated `main` client with rules **lnac-net-18**, or a client from this branch.
Older clients must update. The server owns AI, movement validation, damage,
inventory, clues, objectives and extraction, using the same gameplay scene.

## Run from source

Use Godot **4.7.2** and Python 3. From this branch:

```sh
python3 tools/run_server.py --mode woods --port 27840 --min-players 2
```

On Genesect's Snap installation, prefix the command with
`GODOT_BIN=/snap/bin/godot-4` so noninteractive shells find the engine. After
friends finish the current night, stop the old process, pull `headless-server`,
update every player's `main` copy and relaunch with your usual options. Rules 17
and 18 cannot join each other. Diagnostics for this update did not restart the
regular server.

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

All players use **Host / Join Co-op**, enter the server address and UDP port,
press **Join**, choose their survivor and mark **Ready**. Nobody presses Host or
Start. The server starts automatically after the minimum count is reached and
**every connected player** remains ready for the countdown. Joining or becoming
unready cancels it. Set the minimum to your whole group to prevent an early start.

Results return everyone to the lobby automatically; mark Ready for the next night.
The client’s host-only results buttons remain unavailable. No mid-round join,
reconnect, persistence, password, matchmaking or host migration is added. The
server keeps running when a client leaves; departed gear drops for teammates.
When everybody leaves a round it clears the world and waits in the lobby.
A loading timeout resets the lobby and readiness rather than ending the server.
ENet peer timeouts allow 90s for slow initial graphical loading; detecting an
abruptly lost connection can therefore take up to that allowance.

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
build metadata and this guide. **It requires Godot 4.7.2 installed on the target
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
An observed diagnostic issue remains when several clients disconnect nearly
simultaneously: ENet can print `Unable to send packet on channel 0, max channels: 0`.
In the local stress runs, all gameplay assertions still passed, the world was freed
and the server remained listening. Those runs are recorded as failures by the
strict error-free harness; orderly staggered departures are checked separately.
This console-error case is unresolved and must not be described as clean acceptance.

Player poses now use an independent 30Hz stream; full world state uses 20Hz
unordered fragments. Both clients and server must update to rules lnac-net-18 and
the server must restart before updated clients join. Bounded local prediction, acknowledged reconciliation and buffered remote motion
are implemented; the client also avoids unchanged pickup/site redraws. See the
[smoothness measurements](evidence/smoothness/README.md). The main client also
includes the first-frame scenery preparation fix. These changes do not establish
generally improved Internet latency or eliminate all player corrections.
