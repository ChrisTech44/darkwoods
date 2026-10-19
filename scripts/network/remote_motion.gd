class_name RemoteMotion
extends RefCounted
## Render authority samples 80ms behind, with at most 50ms extrapolation.
const DELAY := 0.08
const EXTRAPOLATE := 0.05
var samples: Array = []
var clock_offset := INF
var latest_tick := -1
var latest_epoch := -1

func push(position: Vector2, velocity: Vector2, tick: int, arrival: float, epoch: int = 0) -> bool:
	if tick <= latest_tick: return false
	var time := tick / float(Engine.physics_ticks_per_second)
	var warp := latest_epoch >= 0 and latest_epoch != epoch
	if warp: samples.clear()
	latest_epoch = epoch
	latest_tick = tick
	clock_offset = minf(clock_offset, arrival - time)
	samples.append([time, position, velocity])
	while samples.size() > 32: samples.pop_front()
	return warp

func sample(now: float) -> Vector2:
	var at := now - clock_offset - DELAY
	while samples.size() > 2 and samples[1][0] <= at: samples.pop_front()
	if samples.size() >= 2 and at <= samples[1][0]:
		var a: Array = samples[0]
		var b: Array = samples[1]
		return a[1].lerp(b[1], clampf((at - a[0]) / (b[0] - a[0]), 0.0, 1.0))
	var last: Array = samples.back()
	return last[1] + last[2] * clampf(at - last[0], 0.0, EXTRAPOLATE)

func render(node: Node2D, now: float, delta: float) -> void:
	var target := sample(now)
	var speed: float = maxf(240.0, samples.back()[2].length() * 1.5)
	node.position = node.position.move_toward(target, speed * delta)
