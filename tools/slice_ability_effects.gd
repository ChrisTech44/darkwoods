extends SceneTree
## One paid 4x4 SpriteCook sheet, preserved alpha. Runtime fits are cached.
const NAMES := ["frog","backwards","float","swap","thread","spore","moth","passenger","slime","mud","toll","echo","clock","song","gaze","tarot"]
func _initialize() -> void:
	var source := Image.load_from_file("res://art_sources/spritecook/ability_effects_sheet.png")
	source.convert(Image.FORMAT_RGBA8)
	for i in range(16):
		var piece := source.get_region(Rect2i((i%4)*50,(i/4)*50,50,50))
		var bounds := piece.get_used_rect()
		piece=piece.get_region(bounds)
		piece.save_png("res://assets/sprites/sc/sample_%s.png" % NAMES[i])
		print(NAMES[i]," ",bounds)
	quit()
