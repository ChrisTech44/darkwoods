# Camper portraits, animation and ability graphics

19 October 2026. Godot 4.7.2, macOS, OpenGL Compatibility, 384×216 viewport.

## Requested appearances

All four are equipped woodland campers with visible packs, rolled sleeping mats,
straps, canteens and boots. Their specified clothing and features remain visible:

| Character | Requested design | Actual selection capture |
| --- | --- | --- |
| Christian | Short dark hair, close-cropped full beard, green T-shirt, grey long pants | [Christian](select_christian.png) |
| John | Dark hair, blue T-shirt, tan cargo shorts | [John](select_john.png) |
| Max | Dark hair, red T-shirt, black shorts | [Max](select_max.png) |
| Alex | Bald, glasses, close-cropped full beard, white T-shirt, tan shorts | [Alex](select_alex.png) |

[All runtime animation frames, nearest-neighbor 4×](all_frames_zoom.png):
Christian / John / Max / Alex; each has idle and two walk frames in
front/back/right/left rows. Every frame and all four selector captures were
opened and inspected. Shapes follow descriptions, not photographic likenesses.

The group walking source clips Christian at its left edge. His runtime frames
**exclude that entire column** and use a dedicated SpriteCook redo:
[complete Christian source](../../../art_sources/spritecook/christian_camper_frames.png).
The provider returned front/back/left rows; right-facing frames are mirrored
from the intact left-facing row. This is a new generated source, not padding
or reconstructing the missing arm/backpack in the damaged group sheet.

## Money and other ability graphics

[Nine-icon source](../../../art_sources/spritecook/survivor_ability_icons.png).
[Cash in the running game](money_markers.png): small bills, bundled cash and a
money bag represent the existing amount tiers; dollar labels remain. Max's HUD
switches between a wallet, [staking dice](max_stake.png) and
[empty wallet](max_empty_wallet.png). [Alex's return pennant](alex_return_marker.png)
uses his existing marker position/lifetime. The HUD also shows John's hourglass
and [damage debt](john_debt.png), and Christian's sample vial. The
[Mimic form](christian_mimic.png) uses the updated friend's camper art too.
These are presentation changes; they award no cash, reveal no hidden objects
and do not change ability timings, authority or extraction rules.

## Fixture and verification

Actual graphical fixture, seed42, forced all escapes/no modifiers for diagnosis,
frozen enemies and night clock, staged actor/wallet/drop states. Normal lighting
and sight stay enabled; no bright inspection override. Base pose (300,400),
cash/marker audit (140,430), with a 40px side step to view the return marker.
The frozen fixture explicitly redraws current marker/cast art for each shot.
Voice/microphones off; Dummy audio. Captures are staged checks, not a full human
playthrough. Source sprites were inspected for alpha and outline completeness.

```sh
godot --headless --path . --script res://tools/import_friend_art.gd
godot --headless --path . --import
godot --path . --audio-driver Dummy --script res://tools/capture_four_survivors.gd -- --art-audit
```

- [Content/selection](content.log): 389 checks.
- [Survivor state/catalogue](kits.log): 144 checks.
- [Actual player rendering](render.log): 9 checks.
- [Actual replica rendering](replication.log): 8 checks.
- [Layout](layout.log): 1,323 checks.
- [Notebook](notebook.log): 21 checks.
- [Import](import.log), [startup](startup.log), [capture log](gallery.log),
  local Markdown targets and diff whitespace checked.

All listed suites pass with zero failures and no engine errors/warnings. The
full broad runner was not rerun for this art increment; its previous result is
preserved separately under the four-survivor implementation evidence. No new
Internet, packaged-platform, listening or microphone acceptance is claimed.

## Sources and credit use

The [asset manifest](../../../spritecook-assets.json) records IDs and SHA-256
prefixes; [asset README](../../../assets/README.md) describes deterministic
cropping/downscale and the selected duplicate columns. No signed URLs or tokens
are stored. Source sheets remain unchanged; runtime assets are derivatives.

Nano Banana 2.1, 1K, one variation per call: 36 credits for the superseded civilian
pass, 36 for camper revisions, 12 for Christian's requested isolated redo, and
12 for the shared ability sheet. **96 total used; 320 remain.** The last redo
plus icons cost 24. Portrait auto-slicing was free. No more paid generation or
cleanup followed the single Christian redo. Earlier civilian files remain only
in ignored artifacts; their manifest IDs are explicitly superseded.
