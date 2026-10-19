# Original game art

## Four camper friends and ability graphics (19 October 2026)

The active roster has dedicated `survivor_christian/john/max/alex.png` sheets
and matching `sc/portrait_<name>.png` portraits. All carry hiking packs, rolled
sleeping mats, canteens and boots. Christian: short dark hair, close-cropped full
beard, green T-shirt/grey long pants. John: dark hair, blue shirt/tan cargo shorts.
Max: dark hair, red shirt/black shorts. Alex: bald, glasses, close-cropped full
beard, white shirt/tan shorts. These are stylized descriptions, not photo likenesses.

Rebuild from committed source images:

```sh
godot --headless --path . --script res://tools/import_friend_art.gd
godot --headless --path . --import
```

The importer extracts connected alpha bounds to avoid chopping equipment at
assumed grid boundaries. Group pose/walk sources contain duplicate columns;
explicit row selections pick John, Max and Alex. Christian uses his isolated
redo (nine poses in down/up/left rows, right mirrored), excluding the clipped
Christian column in the group walking source. Runtime frames stay 24×32, three
frames in down/up/right/left rows. Portraits fit 52×64. Raw sheets are preserved
in `art_sources/spritecook/`; IDs/hashes are in the root SpriteCook manifest.

Nine cropped `sc/` objects: `cash_small`, `cash_bundle`, `cash_bag`, `kit_wallet`,
`kit_dice`, `kit_empty_wallet`, `kit_return`, `kit_debt`, `kit_sample`. Cash tier
pictures represent existing amounts; HUD icons show existing state. Alex's marker
has a small pennant graphic. No economy, isolation, debt or targeting rules change.

Credit record: 36 first-pass civilian prototypes, 36 camper revisions, 12 Christian
redo and 12 shared ability-icon sheet = **96 credits total**, balance **320** after
generation. The last requested redo plus ability art cost 24. Portrait auto-slicing
cost no credits. No paid animation, repeated reroll or additional cleanup job.
Earlier civilian prototypes stay out of runtime assets; their IDs remain marked
superseded in the manifest. [Captures and verification](../docs/evidence/camper_art/README.md).

## SpriteCook revamp (16 October 2026)

Part of the art was regenerated with SpriteCook (Nano Banana 2.1, pixel mode) on
the user's SpriteCook account, at the user's request; asset IDs and hashes are
in [spritecook-assets.json](../spritecook-assets.json) and the raw sheets in
`art_sources/spritecook/`. Licensing follows the user's SpriteCook terms.

| Game files | Source | Processing |
| --- | --- | --- |
| `pine_0/1/2`, `birch`, new `spruce`, `dead_tree`, `shrub`, `boulder`, new `stump` | One generated 3×3 props sheet | `tools/slice_spritecook_props.gd`: native pixels, trees bottom-anchored on 64×80 |
| `survivor_<role>` ×6 (+ `camper.png` = scout) | A 6×4 pose grid, generated as an edit of the old poses so each role keeps its colours | `tools/import_spritecook_survivors.gd`: area downscale of the ~28×55 figures to 31 px, snapped to each figure's palette; frames 1–2 add a 1 px step-bob with alternating legs |
| `stalker` | A 2×2 pose grid, generated as an edit of the old poses | `tools/import_spritecook_stalker.gd`: one shared 0.52 scale into new **40×48** frames (was 32×40), same step-bob |
| All 16 creature sheets | Four 4×4 pose grids (columns = species, rows = directions), each an edit of the old poses; the last (guardians) used Nano Banana 2 Lite | `tools/import_spritecook_creatures.gd`: per-species shared scale (0.85–1.0, never upscaled) into 64×64 frames; wrong-facing side views mirrored or swapped; hover bob for the moths and Wraith |

The terrain atlas, buildings and props drawn in code still use the original
procedural art below. | 16 item icons, 16 camp objects, 16 furniture pieces, 16 landmark props | Four 4×4 grids | `tools/slice_spritecook_grid.gd` → trimmed native sprites in `assets/sprites/sc/`; `scripts/core/pixel_art.gd` (`PixelArt.fit`) scales them at runtime (palette-snapped, cached, never upscaled) |
| 13 seamless materials (`assets/tiles/tex_*`) | Two texture-mode grids (2×2 ground, 3×3 materials) | `tools/import_spritecook_textures.gd`: cut clear of dividers, resampled to 96/64 px; sampled world-aligned by the camp TileMap, woods terrain, floors and roofs |
| Title screen | One 384×216 illustration | Drawn by `menu_backdrop.gd` under the existing fog and fireflies |

`camp_tiles.png` and the code-drawn shapes remain as fallbacks wherever a
SpriteCook file is missing.

All three Python builders (`build_pixel_art.py`, `build_cryptids.py`,
`build_content_art.py`) skip the SpriteCook-owned files unless run with
`--procedural`.

The camper and stalker sheets, terrain atlas, trees and ground props are original
pixel art authored in `tools/build_pixel_art.py` for this project. No downloaded
assets, franchise sprites, or third-party asset licenses are involved. Rebuild:

```sh
python3 tools/build_pixel_art.py
python3 tools/build_cryptids.py
python3 tools/build_content_art.py
```

Characters use three frames in four directional rows: down, up, right, left.
Camper frames are 24×32; stalker frames are 32×40. The camper has a hiking cap,
plaid overshirt, shorts, boots, backpack and rolled mat. The stalker has a weathered
hooded coat, stitched face covering and logging hook. Atlas tiles are 16×16.
Nearest-neighbor filtering and integer viewport scaling preserve the pixels.

`build_cryptids.py` uses the same standard-library pixel painter for six
original 64×64 creatures, three walking frames in four directional rows:
werewolf (layered grey fur, muzzle, claws and fangs), Sasquatch (hunched ape silhouette, crested skull, shaggy fur, long arms and
large feet), and lantern moth (patterned eyespot wings, segmented body,
antennae and amber eyes). PNG output is deterministic. These are original
interpretations of folklore, not downloaded or franchise character assets.

Building geometry, furniture, roof cutaways, dock, campsite props and field map
are drawn in GDScript. Lighting uses native Godot PointLight2D textures and
LightOccluder2D geometry, generated at runtime; the former darkness shader has
been replaced. `default_config.tres` contains the editable gameplay/light defaults.
Seeded woods ruins, warning gate, weather, loading card, animated menu and field
notes are also original GDScript drawing. Audio files are documented separately below.

The roster also includes original vampire (pale angular face, high collar and
maroon-lined cloak), witch (pointed hat, braid, staff and layered robes), and
briar revenant (antlers, exposed ribs, twig limbs and moss) directional sheets.
All six rebuild with the same standard-library script. Forest site scenery,
soft radial mist, trunk occluders and projectile effects are native GDScript art.

## Audio

The user supplied the MP3 recordings used for local playback. See
[audio cue mapping and provenance](audio/README.md) and [manifest](audio/manifest.json).
These are separate from the repository's reproducible original pixel artwork.


`build_content_art.py` adds six original 24×32 survivor sheets with role outfits,
backpacks, tools and patches, plus seven 64×64 cryptid sheets with three frames
and four directions. It uses the same deterministic standard-library painter.
The expanded biome floors, machinery, trellises, rail switches, quarry terraces
and chapel mosaics are native GDScript drawing in `forest_site.gd`. No external
visual assets or new dependencies are used.

The denser roaming update adds three original 64px directional sheets in
`build_content_art.py`: tall-eared Relay Jackal, patterned Ration Moth and iris-faced
Lens Eater. No external assets or dependencies were added.
