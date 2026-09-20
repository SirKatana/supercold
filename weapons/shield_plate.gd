class_name ShieldPlate
extends StaticBody3D
## One solid part of a ballistic shield: the armour plate, or the glass viewport in it.

var shield: Shield
var is_visor: bool = false


func on_bullet_hit(bullet: Node, point: Vector3, normal: Vector3) -> bool:
	return shield.bullet_struck(self, bullet, point, normal)


## The super gun's beam goes straight through armour plate.
func laser_passes() -> bool:
	return true
