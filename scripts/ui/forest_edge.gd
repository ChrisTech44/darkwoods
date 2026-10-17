extends Node2D
## View-local upright foliage, independent of the ground plane's wall shadows.
var sight: WoodsVisibility
func _draw() -> void:
	if is_instance_valid(sight.canopy): sight.canopy.draw_edge(self,sight)
