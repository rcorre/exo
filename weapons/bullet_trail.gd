extends Node3D

const LIFETIME := 0.08

@onready var mesh_instance: MeshInstance3D = $Mesh

func setup(from: Vector3, to: Vector3) -> void:
	var offset := to - from
	var distance := offset.length()
	if distance < 0.001:
		queue_free()
		return

	var direction := offset / distance
	var angle := Vector3.UP.angle_to(direction)
	var basis := Basis.IDENTITY
	if angle > 0.001:
		var axis := Vector3.UP.cross(direction)
		axis = axis if axis.length_squared() > 0.0001 else Vector3.RIGHT
		basis = Basis(axis.normalized(), angle)

	global_transform = Transform3D(basis, from + offset * 0.5)
	mesh_instance.scale.y = distance

	var material := mesh_instance.get_surface_override_material(0).duplicate() as StandardMaterial3D
	mesh_instance.set_surface_override_material(0, material)

	var tween := create_tween()
	tween.tween_property(material, "albedo_color:a", 0.0, LIFETIME)
	tween.parallel().tween_property(material, "emission_energy_multiplier", 0.0, LIFETIME)
	tween.tween_callback(queue_free)
