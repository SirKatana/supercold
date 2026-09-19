class_name TriggerZone
extends Area3D
## One-shot: fires the next trigger wave when the player walks in.

const T: Tuning = preload("res://data/tuning.tres")


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(T.cell_size, 2.0, T.cell_size)
	shape.shape = box
	shape.position.y = 1.0
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		Game.trigger_fired.call_deferred()
		queue_free()
