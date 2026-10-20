extends SceneTree
## One 12-credit 3x3 design sheet; procedural bob/lean, not generated walk views.
const KINDS := ["lifeguard","nightlight_kid","vulture","huntmaster","magician","nobody","shade","fortune_wheel","fortune_skull"]
func _initialize() -> void:
	var source := Image.load_from_file(ProjectSettings.globalize_path("res://art_sources/spritecook/habit_breakers_sheet.png"))
	for index in range(KINDS.size()):
		var x0 := roundi((index%3)*source.get_width()/3.0)
		var y0 := roundi((index/3)*source.get_height()/3.0)
		var x1 := roundi((index%3+1)*source.get_width()/3.0)
		var y1 := roundi((index/3+1)*source.get_height()/3.0)
		var figure := source.get_region(Rect2i(x0,y0,x1-x0,y1-y0))
		figure=figure.get_region(figure.get_used_rect())
		if figure.get_width()>60 or figure.get_height()>56:
			var scale := minf(60.0/figure.get_width(),56.0/figure.get_height())
			figure.resize(roundi(figure.get_width()*scale),roundi(figure.get_height()*scale),Image.INTERPOLATE_NEAREST)
		var frame := Image.create(64,64,false,Image.FORMAT_RGBA8)
		frame.blit_rect(figure,Rect2i(Vector2i.ZERO,figure.get_size()),Vector2i((64-figure.get_width())/2,63-figure.get_height()))
		if index>=7:
			frame.save_png("res://assets/sprites/"+KINDS[index]+".png")
			continue
		var sheet := Image.create(192,256,false,Image.FORMAT_RGBA8)
		for row in range(4):
			for step in range(3):
				var pose := frame.duplicate()
				if row==3: pose.flip_x()
				sheet.blit_rect(pose,Rect2i(0,0,64,62),Vector2i(step*64,row*64-(1 if step==1 else 0)))
		if sheet.save_png("res://assets/sprites/"+KINDS[index]+".png")!=OK: quit(1); return
	print("Imported seven canonical designs and wheel; procedural motion, no paid animation.")
	quit()
