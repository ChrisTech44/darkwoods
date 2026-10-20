extends Node2D
## Presentation identity only. peer_name/role remain the authoritative owner.
var actor: CampPlayer
func _ready() -> void:
	z_index=90
	z_as_relative=false
	var ink := CanvasItemMaterial.new()
	ink.light_mode=CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material=ink
func _process(_delta: float) -> void: queue_redraw()
func _draw() -> void:
	if is_instance_valid(actor) and actor.kit.get("form","")=="nobody": return
	if actor==null or actor.hidden_spot>=0 or actor.status in [CampPlayer.Status.ESCAPED,CampPlayer.Status.BOARDED]: return
	if actor.peer_name.is_empty() and actor.kit.get("form","")!="mimic": return
	var world: Node=SurvivorKits.world(actor)
	if world!=null and world.sight!=null and not world.sight.can_see(actor.position): return
	var text := actor.display_name()
	var height := 34.0
	var form: String=actor.kit.get("form","")
	if form in ["werewolf","briar_revenant","stoneback_ram"]: height=43
	elif form=="groundskeeper": height=51
	var at := Vector2(-ThemeDB.fallback_font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,7).x*0.5,-height)
	draw_string_outline(ThemeDB.fallback_font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,7,2,Color("101c1c"))
	draw_string(ThemeDB.fallback_font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,7,Color("b9d4b2"))
