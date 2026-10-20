class_name SamplePresentation
extends RefCounted
## Every copy has an explicit delivery shape. Guides never discover targets.
const SHAPES := {
	"witch":["shot",272.0,10.0], "ration_moth":["lob",90.0,78.0],
	"bramble_seamstress":["shot",150.0,80.0], "lantern_moth":["shot",150.0,10.0],
	"hitchhiker":["shot",150.0,10.0], "shutter_wraith":["area",210.0,0.0],
	"vampire":["gaze",150.0,0.8], "bigfoot":["cone",150.0,0.5],
	"candle_grazer":["area",100.0,0.0], "switchback_hound":["cone",170.0,0.4],
	"lens_eater":["cone",150.0,0.5], "last_car_conductor":["self",0.0,0.0],
	"owl":["cone",150.0,0.5], "bog_hands":["patch",90.0,24.0],
	"imps":["cone",150.0,0.5], "teddy":["cone",150.0,0.5],
	"cuckoo":["lock",210.0,0.6], "banshee":["area",150.0,0.0],
	"slug":["trail",22.0,0.0], "surveyor":["area",110.0,0.0],
	"tollkeeper":["patch",90.0,24.0], "echo":["patch",90.0,110.0],
	"fortune_teller":["self",0.0,0.0], "boiler_saint":["area",120.0,0.0],
	"relay_jackal":["cone",150.0,0.5], "stoneback_ram":["charge",90.0,30.0],
	"werewolf":["charge",90.0,30.0], "groundskeeper":["charge",90.0,30.0],
	"briar_revenant":["self",0.0,0.0], "mimic":["self",0.0,0.0]
}
const SHOTS := ["witch","ration_moth","bramble_seamstress","lantern_moth","hitchhiker"]
const ART := {"bramble_seamstress":"thread","ration_moth":"spore","lantern_moth":"moth","hitchhiker":"passenger","slug":"slime","bog_hands":"mud","tollkeeper":"toll","echo":"echo","cuckoo":"clock","boiler_saint":"song","vampire":"gaze","fortune_teller":"tarot"}
## Authored creature interaction cues, not AI hearing stimuli.
const CUES := {
	"witch":["witch_cackle",2.0,1.2], "ration_moth":["screech_5",-2.0,1.6],
	"bramble_seamstress":["monster_7",0.0,1.3], "vampire":["vampire_snarl",4.0,1.0],
	"bigfoot":["bigfoot_growl",6.0,1.0], "lantern_moth":["lantern_moth_screech",2.0,1.2],
	"candle_grazer":["screech_2",0.0,0.82], "lens_eater":["screech_1",4.0,0.7],
	"owl":["owl",0.0,0.7], "bog_hands":["bog_gurgle",4.0,0.75],
	"imps":["giggle",3.0,1.2], "teddy":["squeak",6.0,0.7],
	"surveyor":["eerie",4.0,0.8], "hitchhiker":["giggle",2.0,0.7],
	"tollkeeper":["monster_8",2.0,1.25], "fortune_teller":["bells",-2.0,1.6],
	"relay_jackal":["monster_6",4.0,1.5], "stoneback_ram":["monster_8",6.0,1.0],
	"slug":["bog_gurgle",0.0,0.6], "briar_revenant":["revenant_screech",0.0,1.0],
	"groundskeeper":["car_start",-4.0,1.6], "mimic":["screech_4",-4.0,0.85]
}
static func cue(actor: CampPlayer, kind: String) -> void:
	if not CUES.has(kind): return
	var row: Array = CUES[kind]
	SurvivorKits.world(actor).soundscape.broadcast(row[0],actor.position,row[1],row[2])

static func art(kind: String, subtype: String = "frog") -> String:
	if kind == "witch": return "sample_"+(subtype if subtype in ["frog","backwards","float","swap"] else "frog")
	return "sample_"+ART[kind] if ART.has(kind) else ""

static func sprite(canvas: CanvasItem, kind: String, at: Vector2, subtype: String = "frog", size: float = 24.0, alpha: float = 1.0) -> void:
	var name := art(kind,subtype)
	if not name.is_empty(): PixelArt.draw_in(canvas,name,Rect2(at-Vector2.ONE*size*0.5,Vector2.ONE*size),Color(1,1,1,alpha))

static func clipped(level: Node, start: Vector2, direction: Vector2, reach: float) -> Vector2:
	var end := start+direction*reach
	var hit: Dictionary = level.get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(start,end,1))
	return end if hit.is_empty() else (hit["position"]-direction*1.0) as Vector2

static func guide(canvas: Node2D, level: Node, actor: CampPlayer) -> void:
	if actor != level.player or actor.role != "christian" or not SurvivorKits.enabled(actor) or actor.status != CampPlayer.Status.ALIVE: return
	var cast: Dictionary=actor.kit.get("cast",{})
	var kind: String=cast.get("kind",actor.kit.get("form","") if not actor.kit.get("form","").is_empty() else actor.kit.get("sample",""))
	if not SHAPES.has(kind): return
	var spec: Array=SHAPES[kind]
	var shape: String=spec[0]
	var reach: float=spec[1]
	var at: Vector2=actor.position
	var direction: Vector2=cast.get("direction",actor.facing)
	var faint := Color(0.8,0.92,0.77,0.24)
	if shape in ["shot","lob","patch","charge"]:
		if cast.get("projectile",false): at=cast["at"]; reach=cast.get("distance_left",reach)
		var end := clipped(level,at,direction,reach)
		canvas.draw_dashed_line(at,end,faint,1,5)
		if shape in ["patch","lob"]:
			if not cast.is_empty() and not cast.get("projectile",false): end=cast["at"]
			canvas.draw_arc(end,spec[2],0,TAU,48,faint,1)
		else:
			var side := direction.orthogonal()*minf(float(spec[2]),10)
			canvas.draw_line(at+side,end+side,Color(faint,0.1),1)
			canvas.draw_line(at-side,end-side,Color(faint,0.1),1)
			canvas.draw_line(end-side,end+side,faint,1)
	elif shape in ["cone","gaze","lock"]:
		var angle := acos(float(spec[2]))
		var points := PackedVector2Array([at])
		for i in range(17): points.append(clipped(level,at,direction.rotated(lerpf(-angle,angle,i/16.0)),reach))
		points.append(at)
		canvas.draw_polyline(points,faint,1)
	elif shape in ["area","trail"]:
		canvas.draw_arc(at,reach,0,TAU,64,faint,1)

static func detail(actor: CampPlayer) -> String:
	if not SurvivorKits.enabled(actor): return ""
	if actor.role == "max": return ""
	var form: String=actor.kit.get("form","")
	if not form.is_empty():
		var action := "No extra X action."
		if form in ["werewolf","groundskeeper"]:
			var cooldown: float=actor.kit.get("action_cd",0.0)
			action=("X: POUNCE" if form=="werewolf" else "X: MOWER BURST")+(" READY" if cooldown<=0 else " in %.1fs" % cooldown)
		elif form=="briar_revenant": action="MOVE only while nobody watches."
		elif form=="stoneback_ram": action="CHARGING: direction locked."
		elif form=="mimic": action="DISGUISED AS "+actor.display_name()
		return "%s — %.1fs left\n%s" % [CreatureSamples.name_of(form),actor.kit.get("form_time",0.0),action]
	return ""
