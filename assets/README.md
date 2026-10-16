# Original game art

The camper and stalker sheets, terrain atlas, trees and ground props are original
pixel art authored in `tools/build_pixel_art.py` for this project. No downloaded
assets, franchise sprites, or third-party asset licenses are involved. Rebuild:

```sh
python3 tools/build_pixel_art.py
```

Characters use three frames in four directional rows: down, up, right, left.
Camper frames are 24×32; stalker frames are 32×40. The camper has a hiking cap,
plaid overshirt, shorts, boots, backpack and rolled mat. The stalker has a weathered
hooded coat, stitched face covering and logging hook. Atlas tiles are 16×16.
Nearest-neighbor filtering and integer viewport scaling preserve the pixels.

Building geometry, furniture, roof cutaways, dock, campsite props and field map
are drawn in GDScript. Lighting uses native Godot PointLight2D textures and
LightOccluder2D geometry, generated at runtime; the former darkness shader has
been replaced. `default_config.tres` contains the editable gameplay/light defaults.
