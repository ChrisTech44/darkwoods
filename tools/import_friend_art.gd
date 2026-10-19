extends "res://tools/import_spritecook_survivors.gd"
## Four-friend artwork uses the existing 24x32 runtime frame contract.
## Column order: Christian, John, Max, Alex; rows: down, up, right, left.
## Run after downloading the source sheets documented in assets/README.md.
const FRIENDS := ["christian", "john", "max", "alex"]
const POSES := "res://art_sources/spritecook/friends_poses.png"
const WALKS := "res://art_sources/spritecook/friends_walks.png"
const PORTRAITS := "res://art_sources/spritecook/friends_portraits.png"
const CHRISTIAN := "res://art_sources/spritecook/christian_camper_frames.png"
const ICONS := "res://art_sources/spritecook/survivor_ability_icons.png"
const ICON_NAMES := ["cash_small","cash_bundle","cash_bag","kit_wallet","kit_dice","kit_empty_wallet","kit_return","kit_debt","kit_sample"]
## Provider repeated two columns. Preserve the source and select correct people
## per row rather than paying to regenerate an otherwise correct design.
const SOURCE_COLUMNS := [[0,1,2,4],[0,1,2,4],[0,1,3,4],[0,1,3,4]]

func _initialize() -> void:
	var poses := _source(POSES)
	var walks := _source(WALKS)
	var portraits := _source(PORTRAITS)
	var christian := _source(CHRISTIAN)
	var icons := _source(ICONS)
	if poses == null or walks == null or portraits == null or christian == null or icons == null:
		quit(1)
		return
	var pose_boxes := _figures(poses,6,4)
	var walk_boxes := _figures(walks,6,4)
	var face_boxes := _figures(portraits,2,2)
	# Provider returned down/up/left rows; mirror left for the right-facing row.
	var christian_boxes := _figures(christian,3,3)
	if pose_boxes.is_empty() or walk_boxes.is_empty() or face_boxes.is_empty() or christian_boxes.is_empty():
		quit(1)
		return
	for column in range(FRIENDS.size()):
		var sheet := Image.create(FRAME.x*3,FRAME.y*4,false,Image.FORMAT_RGBA8)
		for row in range(4):
			if column == 0:
				# Dedicated redo, never the clipped group-atlas column.
				for frame in range(3):
					var pose := _pose(christian.get_region(christian_boxes[mini(row,2)*3+frame]))
					if row == 2: pose.flip_x()
					sheet.blit_rect(pose,Rect2i(Vector2i.ZERO,FRAME),Vector2i(frame*FRAME.x,row*FRAME.y))
				continue
			var idle := _pose(poses.get_region(pose_boxes[row*6+SOURCE_COLUMNS[row][column]]))
			var walk := _pose(walks.get_region(walk_boxes[row*6+SOURCE_COLUMNS[row][column]]))
			var opposite := walk.duplicate()
			opposite.flip_x()
			var frames: Array[Image] = [idle,walk,opposite if row<2 else _step(walk,2)]
			for frame in range(3):
				sheet.blit_rect(frames[frame],Rect2i(Vector2i.ZERO,FRAME),Vector2i(frame*FRAME.x,row*FRAME.y))
		var error := sheet.save_png(ProjectSettings.globalize_path("res://assets/sprites/survivor_%s.png" % FRIENDS[column]))
		if error != OK:
			push_error("Cannot save survivor: " + FRIENDS[column])
			quit(1)
			return
		var face := portraits.get_region(face_boxes[column])
		face = face.get_region(face.get_used_rect())
		var scale := minf(52.0/face.get_width(),64.0/face.get_height())
		face.resize(maxi(1,roundi(face.get_width()*scale)),maxi(1,roundi(face.get_height()*scale)),Image.INTERPOLATE_NEAREST)
		face.save_png(ProjectSettings.globalize_path("res://assets/sprites/sc/portrait_%s.png" % FRIENDS[column]))
		print("Imported friend artwork: " + FRIENDS[column])
	for i in range(ICON_NAMES.size()):
		var cell := _cell(icons,i%3,i/3,3,3)
		var used := cell.get_used_rect()
		if not used.has_area():
			push_error("Empty ability icon: " + ICON_NAMES[i])
			quit(1)
			return
		cell.get_region(used).save_png(ProjectSettings.globalize_path("res://assets/sprites/sc/%s.png" % ICON_NAMES[i]))
		print("Imported ability icon: " + ICON_NAMES[i])
	quit()

func _source(path: String) -> Image:
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null or image.is_empty():
		push_error("Missing friend source: " + path)
		return null
	image.convert(Image.FORMAT_RGBA8)
	return image

func _cell(image: Image, column: int, row: int, columns: int, rows: int) -> Image:
	var low := Vector2i(column*image.get_width()/columns,row*image.get_height()/rows)
	var high := Vector2i((column+1)*image.get_width()/columns,(row+1)*image.get_height()/rows)
	return image.get_region(Rect2i(low,high-low))

## Grid placement varies after provider cropping. Use alpha bounds, never cut
## the source at guessed equal-width cells (which can sever arms/backpacks).
func _figures(image: Image, columns: int, rows: int) -> Array[Rect2i]:
	var boxes := _components(image)
	var figures: Array[Rect2i] = []
	var pieces: Array[Rect2i] = []
	for box in boxes:
		if box.size.y >= image.get_height()/rows*0.45 and box.size.x>=8: figures.append(box)
		else: pieces.append(box)
	if figures.size() != columns*rows:
		push_error("Expected %d figures, found %d" % [columns*rows,figures.size()])
		return []
	for piece in pieces:
		var best := -1
		var distance := INF
		for i in range(figures.size()):
			var gap := Vector2(figures[i].get_center()).distance_to(Vector2(piece.get_center()))
			if gap<distance:
				distance = gap
				best = i
		if best>=0 and distance<image.get_height()/rows*0.6: figures[best] = figures[best].merge(piece)
	figures.sort_custom(func(a: Rect2i,b: Rect2i) -> bool:
		var row_a: int = a.get_center().y*rows/image.get_height()
		var row_b: int = b.get_center().y*rows/image.get_height()
		return row_a<row_b or (row_a==row_b and a.get_center().x<b.get_center().x))
	for i in range(figures.size()): print("Source figure ",i,": ",figures[i])
	return figures

func _components(image: Image) -> Array[Rect2i]:
	var width := image.get_width()
	var height := image.get_height()
	var seen := PackedByteArray()
	seen.resize(width*height)
	var boxes: Array[Rect2i] = []
	for y in range(height):
		for x in range(width):
			if seen[y*width+x] or image.get_pixel(x,y).a<0.5: continue
			var low := Vector2i(x,y)
			var high := low
			var stack: Array[Vector2i] = [low]
			seen[y*width+x] = 1
			while not stack.is_empty():
				var point: Vector2i = stack.pop_back()
				low = Vector2i(mini(low.x,point.x),mini(low.y,point.y))
				high = Vector2i(maxi(high.x,point.x),maxi(high.y,point.y))
				for dy in [-1,0,1]:
					for dx in [-1,0,1]:
						var next := point+Vector2i(dx,dy)
						if next.x<0 or next.y<0 or next.x>=width or next.y>=height: continue
						if seen[next.y*width+next.x] or image.get_pixel(next.x,next.y).a<0.5: continue
						seen[next.y*width+next.x] = 1
						stack.append(next)
			boxes.append(Rect2i(low,high-low+Vector2i.ONE))
	return boxes
