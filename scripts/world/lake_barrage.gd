class_name LakeBarrage
extends Node2D
## Authority-owned, swept water shots. Clients only extrapolate their pictures.
const INTERVAL := 0.5
const TELL := 0.35
const SPEED := 170.0
const DAMAGE := 18.0
const HIT_RADIUS := 10.0
const LIFE := 3.0
const MAX_SHOTS := 12
var escapes: Node2D
var shots: Array[Dictionary] = []
var clock := 0.3
var sequence := 0
var source := Vector2.ZERO
var visual_age := 0.0
var pulse := 0.0

func _ready() -> void:
	var ink:=CanvasItemMaterial.new()
	ink.light_mode=CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material=ink
	z_index=2

func _process(delta: float) -> void:
	if not escapes.level.paused and not escapes.level.finished:
		pulse+=delta
		if not escapes.level.rescue.authority():visual_age=minf(0.05,visual_age+delta)
	queue_redraw()

func targets() -> Array[CampPlayer]:
	var result: Array[CampPlayer]=[]
	for actor: CampPlayer in get_tree().get_nodes_in_group("survivors"):
		if actor.status==CampPlayer.Status.ALIVE and actor.hidden_spot<0 and actor.position.distance_to(escapes.boat_point)<=220 and actor.kit.get("form","")!="nobody":result.append(actor)
	return result

func advance(delta: float) -> void:
	if not escapes.boat_started or not escapes.level.rescue.authority() or escapes.level.paused or escapes.level.finished:return
	visual_age=0
	clock-=delta
	for index in range(shots.size()-1,-1,-1):
		var shot: Dictionary=shots[index]
		if shot.tell>0:
			shot.tell=maxf(0,shot.tell-delta)
			continue
		var travel_delta:=minf(delta,maxf(0,shot.life))
		shot.life-=delta
		var from: Vector2=shot.position
		var to: Vector2=from+shot.direction*SPEED*travel_delta
		var ray:=PhysicsRayQueryParameters2D.create(from,to,1|CampPlayer.BARRIER_LAYER)
		var wall:=get_world_2d().direct_space_state.intersect_ray(ray)
		if not wall.is_empty():to=wall.position
		var blocked:=false
		for flare: Node2D in get_tree().get_nodes_in_group("flares"):
			if flare.get("remaining")!=null and flare.remaining<=0:continue
			var closest:=Geometry2D.get_closest_point_to_segment(flare.position,from,to)
			if flare.position.distance_to(closest)<=32 and escapes.level.clear_path(flare.position,closest):blocked=true;break
		if blocked:
			shots.remove_at(index)
			continue
		var victim: CampPlayer
		var first:=INF
		for actor: CampPlayer in get_tree().get_nodes_in_group("survivors"):
			if actor.status!=CampPlayer.Status.ALIVE or actor.hidden_spot>=0:continue
			var closest:=Geometry2D.get_closest_point_to_segment(actor.position,from,to)
			if actor.position.distance_to(closest)<=HIT_RADIUS and from.distance_to(closest)<first and escapes.level.clear_path(from,actor.position):
				victim=actor;first=from.distance_to(closest)
		if victim!=null:
			victim.receive_hit(DAMAGE)
			escapes.level.soundscape.broadcast("water_splash",victim.position,-8)
			shots.remove_at(index)
		elif not wall.is_empty():
			escapes.level.soundscape.broadcast("water_splash",to,-10)
			shots.remove_at(index)
		elif shot.life<=0:shots.remove_at(index)
		else:shot.position=to

	var bodies:=targets()
	if clock<=0:
		clock=INTERVAL
		if not bodies.is_empty() and shots.size()<MAX_SHOTS:
			var actor: CampPlayer=bodies[sequence%bodies.size()]
			var side: float=-1 if (sequence/6)%2==0 else 1
			source=escapes.boat_point+Vector2(side*(126+sequence%3*8),-38-sequence%3*6)
			sequence+=1
			launch(source,actor.position)

func launch(origin: Vector2,target: Vector2) -> void:
	if shots.size()>=MAX_SHOTS:return
	shots.append({"origin":origin,"position":origin,"target":target,"direction":origin.direction_to(target),"tell":TELL,"life":LIFE})

func stop() -> void:
	shots.clear()

func snapshot() -> Dictionary:
	return {"shots":shots.duplicate(true),"clock":clock,"sequence":sequence,"source":source}

func restore(state: Dictionary) -> void:
	shots.assign(state.get("shots",[]).slice(0,MAX_SHOTS).duplicate(true))
	clock=state.get("clock",0.3);sequence=state.get("sequence",0);source=state.get("source",Vector2.ZERO)
	visual_age=0

func _draw() -> void:
	if not escapes.boat_enabled:return
	var center: Vector2=escapes.boat_point
	var color:=Color("8ddbb3") if escapes.boat_occupied else Color("e7b979")
	if escapes.boat_started:
		draw_circle(center,escapes.BOAT_RADIUS,Color(color,0.055))
		draw_arc(center,escapes.BOAT_RADIUS,0,TAU,64,Color(color,0.9),1.4,true)
		var progress: float=1-escapes.boat_remaining/escapes.BOAT_SECONDS
		if progress>0:draw_arc(center,escapes.BOAT_RADIUS+3,-PI/2,-PI/2+TAU*progress,64,color,2.0,true)
		if sequence>0:FieldEscapeArt.draw_lake_thing(self,source+Vector2(0,-10),false)
	else:draw_arc(center,escapes.BOAT_RADIUS,0,TAU,64,Color("b6c6a0"),1,true)
	for shot: Dictionary in shots:
		if shot.tell>0:
			draw_line(shot.origin,shot.target,Color(0.6,0.85,1,0.22),1)
			draw_arc(shot.target,9,0,TAU,20,Color("b5ecfa"),1)
			draw_circle(shot.origin,5+sin(pulse*20),Color("92cdda"))
		else:
			var at: Vector2=shot.position+shot.direction*SPEED*visual_age
			draw_line(at-shot.direction*12,at,Color(0.35,0.8,1,0.65),3,true)
			draw_circle(at,5,Color("153448"))
			draw_circle(at,3.5,Color("81d7f0"))
			draw_circle(at-Vector2(1,1),1.5,Color("eefcff"))
