class_name Minimap
extends Control
## A small plan of what is round you, off by default and switched on in settings. Walls from
## the floor plan, you in the middle, and a dot for every enemy in the colour he actually is,
## so a violet spearman in a crowd of pink reads at a glance.
##
## It draws straight from `Game.data` and the enemies group: nothing to keep in step, and it
## costs nothing at all while it is switched off.

const SIZE: float = 168.0
const RANGE_CELLS: int = 13

var _player: Player


func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	position = Vector2(-SIZE - 18.0, 18.0)
	visible = Settings.minimap
	Settings.changed.connect(func() -> void: visible = Settings.minimap)


func _process(_delta: float) -> void:
	if not visible:
		return
	_player = Game.player
	queue_redraw()


func _draw() -> void:
	if _player == null or not is_instance_valid(_player) or Game.data == null:
		return
	var middle := Vector2(SIZE, SIZE) * 0.5
	var cell: float = SIZE / float(RANGE_CELLS * 2 + 1)
	draw_rect(Rect2(Vector2.ZERO, Vector2(SIZE, SIZE)), Color(0.93, 0.94, 0.96, 0.72))

	var here: Vector2i = Game.data.cell_of(_player.global_position)
	var wall := Color(0.30, 0.32, 0.38, 0.85)
	var floor_colour := Color(1, 1, 1, 0.5)
	for dy: int in range(-RANGE_CELLS, RANGE_CELLS + 1):
		for dx: int in range(-RANGE_CELLS, RANGE_CELLS + 1):
			var at: Vector2i = here + Vector2i(dx, dy)
			var what: String = Game.data.char_at(at)
			if what == "":
				continue
			var spot := middle + Vector2(dx, dy) * cell - Vector2(cell, cell) * 0.5
			if Game.data.is_solid(at):
				draw_rect(Rect2(spot, Vector2(cell, cell)), wall)
			elif what != " ":
				draw_rect(Rect2(spot, Vector2(cell, cell)), floor_colour)

	# The exit, so the map is worth looking at once the floor is clear.
	if Game.data.exit_cell.x >= 0:
		var to_exit: Vector2i = Game.data.exit_cell - here
		if absf(float(to_exit.x)) <= RANGE_CELLS and absf(float(to_exit.y)) <= RANGE_CELLS:
			draw_rect(Rect2(middle + Vector2(to_exit) * cell - Vector2(cell, cell) * 0.5,
				Vector2(cell, cell)), Color(0.25, 0.75, 0.95, 0.9))

	_draw_people(middle, cell)

	# You, pointing the way you are looking.
	var facing: float = -_player.rotation.y
	var nose: Vector2 = Vector2(0, -cell * 1.1).rotated(-facing)
	var left: Vector2 = Vector2(-cell * 0.55, cell * 0.7).rotated(-facing)
	var right: Vector2 = Vector2(cell * 0.55, cell * 0.7).rotated(-facing)
	draw_colored_polygon(PackedVector2Array([middle + nose, middle + left, middle + right]),
		Color(0.06, 0.06, 0.08))
	draw_rect(Rect2(Vector2.ZERO, Vector2(SIZE, SIZE)), Color(0.2, 0.21, 0.25, 0.9), false, 2.0)


## A dot per enemy, in his own colour: the dot is read straight off the body material, so a new
## kind of dude turns up on the map the day he is added.
func _draw_people(middle: Vector2, cell: float) -> void:
	for group: StringName in [&"enemies", &"lurkers", &"allies", &"bosses"]:
		for node: Node in get_tree().get_nodes_in_group(group):
			var who: Node3D = node as Node3D
			if who == null or not is_instance_valid(who):
				continue
			if who.get(&"alive") == false:
				continue
			var away: Vector3 = who.global_position - _player.global_position
			var on_map := Vector2(away.x, away.z) / Game.data.cell_size * cell
			if absf(on_map.x) > SIZE * 0.5 or absf(on_map.y) > SIZE * 0.5:
				continue
			draw_circle(middle + on_map, cell * 0.42, _colour_of(who))


## Whatever he is made of. Falls back to pink for anything with no skin of its own.
func _colour_of(who: Node3D) -> Color:
	var material: Variant = who.get(&"body_material")
	if material is StandardMaterial3D:
		var shade: Color = (material as StandardMaterial3D).albedo_color
		return Color(shade.r, shade.g, shade.b, 1.0)
	if who.is_in_group(&"lurkers"):
		return Color(0.35, 0.85, 0.35)
	if who.is_in_group(&"allies"):
		return Color(0.2, 0.4, 0.9)
	return Mats.PINK
