class_name Sight
extends RefCounted
## Line of sight that treats anything in the `see_through` group (glass) as air.

const MASK: int = 1 | 32


static func is_clear(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> bool:
	var exclude: Array[RID] = []
	for attempt: int in 6:
		var query := PhysicsRayQueryParameters3D.create(from, to, MASK)
		query.exclude = exclude
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			return true
		var collider: Object = hit["collider"]
		if collider is Node and (collider as Node).is_in_group(&"see_through"):
			exclude.append(hit["rid"])
			continue
		return false
	return false
