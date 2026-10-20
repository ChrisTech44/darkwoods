# Dedicated-server review evidence

19 October 2026; macOS Apple M2, Godot 4.7.2. Microphone capture disabled.
No regular server process was changed. See [findings and limits](../../server_review.md).

- [Complete resumed regression](regression.json): 254 final passing steps, including 180 parse and 27 named graphical gates. Prior failed attempts and explicit resume boundaries are retained. The active-enemy expedition passed after its old 240s harness budget was extended to 480s; ordinary gameplay/rendering were preserved.
- [Pre-fix simultaneous-leave failure](disconnect_baseline.txt): three native channel-0 errors; retained as failed evidence.
- [Four distinct source clients](source_four_clients.json) and [authority assertions](source_authority.log): 77 authority + 70 client checks, zero failures/errors/warnings.
- [Four distinct PCK clients](pack_four_clients.json) and [pack authority assertions](pack_authority.log): same gates. Final PCK was rebuilt from clean runtime commit `4e5d119`; [build metadata and hashes](package_build.json) record its provenance.
- [Source disabled-rule gate](disabled_rules_source.json): four-person listen and dedicated hosting. [PCK disabled-rule gate](disabled_rules_pack.json): four dedicated clients.
- [Native graphical sound shutdown](sound_shutdown_graphical.log) and [headless sound routing](sound_shutdown_headless.log): 30 assertions each, no capture device; radio/stinger streams release and delayed radio stays off.
- [Synthetic voice](synthetic_voice.json): codec/routing and real ENet host/client packets, no microphone.
- [Private gallery validation](gallery_validation.json): 52 refreshed MP4s, full decode and inspected contact sheets; media remain ignored locally.
- [Pre-fix native audio findings](audio_failure_baseline.txt): wet-step peak and WAV fixture error, retained as historical failed evidence.
- [Native PCM and looping](native_pcm.log): 215 assertions across 68 cues; wet footsteps peak 0.541 after gain correction, WAV whistle decoded.
- [Python checks](python_tests.log): 12 passing launcher/package/result-validation tests.

Ability tests stage a safe projectile lane, supplied samples and a coffee-protected
song caster to isolate replication. Relay uses synthetic packets on the voice
transport channel, not captured speech. Lifecycle freezes enemy AI/disables the night director after boot, supplies
objective parts and advances the launch clock while using the real objective and
extraction path. These fixtures do not establish human listening, natural balance,
Internet performance or the new package's Linux/Windows behavior.
