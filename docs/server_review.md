# Dedicated-server review — 19 October 2026

The user expects dedicated hosting to be the main play path. This review followed
[the ability delivery overhaul](ability_feedback_review.md), using the production
headless authority and real ENet client processes. Findings below distinguish
observed failures from implemented fixes; no regular server was restarted.

## Fixed findings

| Finding | Reproduction and correction |
| --- | --- |
| Wrong dedicated survivor role | Lobby insertion order selected the initial reference body's role, while attachment reused that body for the lowest peer ID. These orders can differ. The server now sorts IDs consistently. The test reverses roster insertion order against sorted IDs, uses Christian/John/Max/Alex, and checks each authoritative body and each client's role. |
| Errors during simultaneous departures | The baseline produced three `Unable to send packet on channel 0, max channels: 0` errors despite passing its gameplay assertions. `CampENetPeer` delegates the native ENet API and skips packet sends only when the native destination is no longer connected. This covers engine control packets before game callbacks run. Relay stays enabled; four clients exchange synthetic unreliable channel-3 packets through the authority. Final source stress run dropped three closing-destination packets and logged no engine errors/warnings. |
| Misleading or stale server builds | Packaging hardcoded an older protocol and exported over a possibly old PCK. It now reads actual protocol/engine/commit/dirty state, exports into fresh staging, requires a nonempty error-free result, stages the guide/launcher/metadata with it and replaces the ZIP last. A failed export cannot publish an earlier PCK as new. Tests reproduce a zero-exit export that creates no file and verify the old bundle survives unchanged. |
| Max's pending money action survives a menu | Opening the offline pause or online menu now cancels the pending stake without a purchase, gamble or charge. Real client input is checked against the dedicated wallet. |
| Christian cannot stop his own commitment | Teddy/Peeper-style effects can trip their caster. His own commitment may now be cancelled with X while tripped; death, hiding, held/sleep/frog restrictions still apply. Catalogue checks reproduce the self-lock and verify cancellation. |
| Radio/stinger playback leaks at exit | The strict graphical content run passed 426 assertions but leaked an MP3 stream and playback. Shutdown now stops/releases every positional and non-positional soundscape child, and queued radio-talk callbacks cannot restart after stop. The same capture gate is now error/warning free; 30 sound checks pass with native playback and with headless output disabled. |
| Wet-footstep gain exceeds headroom | Native PCM capture measured 0.962 against a 0.95 gate; the original file peaks at −0.8 dBFS, before its earlier +4 dB gain. Runtime gain is now −1 dB, leaving source peak headroom without editing the recording. The decode test also now handles WAV loop properties correctly for the synthesized whistle. |
| Verification can accept a silent new suite | Every runtime suite must now emit exactly one successful test-result record; missing, malformed or duplicate records fail. Import/startup/parse gates retain their own criteria. The runner also rejects warnings. Updated obsolete flashlight-duration, Settings-tree and native call-falloff assertions. The existing 560px/1.2 creature-call behavior is unchanged; its old test/design paragraph still described 160px/2.0. |

The disconnect explanation is consistent with Godot's
[SceneMultiplayer disconnect relay](https://raw.githubusercontent.com/godotengine/godot/master/modules/multiplayer/scene_multiplayer.cpp)
and [ENet event polling](https://raw.githubusercontent.com/godotengine/godot/master/modules/enet/enet_multiplayer_peer.cpp).
The local before/after reproduction is the acceptance evidence; inspecting upstream
source alone does not establish behavior on every engine build.

## Executed acceptance and limits

On macOS Apple M2, Godot **4.7.2**, source and exported-PCK authorities each passed
**77 server + 70 client checks**, with four distinct campers. These exercise real
X input, a flying Witch projectile and victim status/native cue, copied Saint
loop start/cleanup, Max menu cancellation, synthetic relay, movement/exploration,
normal boat extraction/results, automatic lobby/second round, reference-human
removal and simultaneous empty cleanup. Lifecycle fixtures freeze enemies/disable
the night director, supply parts and advance launch time; they exercise actual
authoritative objective handlers rather than a full naturally played night.
The host has no survivor slot or voice
codec. Quick Camp two-client lifecycle also passed during review.

The disabled-abilities gate passed both four-person listen hosting and dedicated
source hosting, plus four clients against the PCK: guests cannot change the rule,
local cash tampering is restored, all four starting/passive/active kits are off,
and ordinary movement remains. Synthetic voice checks passed **24 codec/routing,
8 guest and 13 host** assertions with microphone capture disabled. Python launcher,
package and result-validation tests passed **12/12**.

[Selected logs and reports](evidence/server_review/README.md) preserve the executed
checks. All tests ran on spare local ports. These checks do not establish Linux or
Windows acceptance for this new build, production deployment, Internet latency,
real-microphone operation, human listening quality or long-term load/balance.
Earlier Linux/network evidence remains historical and is linked in the
[server guide](dedicated_server.md). Update both clients and server to
**lnac-net-20** before playing together.

The private ability gallery was refreshed separately: 52 fully decoded MP4s and
nine inspected contact sheets, including all 30 Christian interactions. Its staged
bright lighting, controlled AI and hidden sight/roof layers are labelled; it is
not multiplayer or natural-play evidence. It remains ignored locally under
`artifacts/ability_gallery/` and is not published to GitHub.
