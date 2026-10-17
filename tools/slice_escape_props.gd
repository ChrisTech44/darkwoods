extends SceneTree
## One 12-credit 4x4 SpriteCook sheet supplies all F5 hero props. Preserve source.
const NAMES := ["f5_transformer","f5_breaker","f5_relay","f5_beacon",
	"outboard_motor","f5_boat","f5_boathouse","f5_ranger_booth",
	"f5_gate","f5_logs","f5_logging","f5_pier",
	"f5_lake_thing","f5_bridge","boat_fuel","f5_codes"]
func _initialize() -> void:
	var sheet := Image.load_from_file("res://art_sources/spritecook/escape_props_sheet.png")
	sheet.convert(Image.FORMAT_RGBA8)
	for index in range(16):
		var x := roundi(float(index%4)*sheet.get_width()/4)
		var y := roundi(float(index/4)*sheet.get_height()/4)
		var end_x := roundi(float(index%4+1)*sheet.get_width()/4)
		var end_y := roundi(float(index/4+1)*sheet.get_height()/4)
		var cell := sheet.get_region(Rect2i(x,y,end_x-x,end_y-y))
		# Trim at meaningful alpha, excluding intentionally faint ambient glow tails.
		var low := Vector2i(cell.get_width(),cell.get_height())
		var high := Vector2i.ZERO
		for cy in range(cell.get_height()):
			for cx in range(cell.get_width()):
				if cell.get_pixel(cx,cy).a>0.5:
					low=low.min(Vector2i(cx,cy))
					high=high.max(Vector2i(cx,cy)+Vector2i.ONE)
		var rect := Rect2i(low,(high-low).max(Vector2i.ONE))
		var sprite := cell.get_region(rect)
		# Integer nearest-neighbour enlargement gives runtime hero sizing room while
		# keeping the designed pixel grid; no new pixels are invented.
		var scale := 4 if NAMES[index] == "f5_relay" else 2
		sprite.resize(sprite.get_width()*scale,sprite.get_height()*scale,Image.INTERPOLATE_NEAREST)
		sprite.save_png("res://assets/sprites/sc/%s.png" % NAMES[index])
		print(JSON.stringify({"sprite":NAMES[index],"crop":Rect2i(Vector2i(x,y)+rect.position,rect.size),"size":sprite.get_size()}))
	quit()
