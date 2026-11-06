extends Node3D
# Gravity Trials 2.0 — clean, dependency-free mobile Web baseline.
const VERSION = "2.0.0"
var bike: Node3D
var camera: Camera3D
var hud: Label
var buttons := {"gas": false, "brake": false, "back": false, "forward": false}
var progress := 0.0
var velocity := 0.0
var bike_y := 1.05
var pitch := 0.0
var elapsed := 0.0
var wheel_visuals: Array[Node3D] = []
var vertical_speed := 0.0
var spin_speed := 0.0
var crashed := false
var rear_compression := 0.0
var front_compression := 0.0
var dust_timer := 0.0
var dust: GPUParticles3D
var imported_motorcycle: Node3D

func mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	return m

func cube(parent: Node3D, dimensions: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	n.mesh = mesh
	n.material_override = mat(color)
	n.position = pos
	parent.add_child(n)
	return n

func cylinder(parent: Node3D, radius: float, depth: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = depth
	n.mesh = mesh
	n.material_override = mat(color)
	n.position = pos
	n.rotation.x = PI / 2.0
	parent.add_child(n)
	return n

func surface(px: float) -> float:
	var base := 0.65 * sin(px * 0.105) + 0.35 * sin(px * 0.29)
	var ramps := 0.0
	for center in [24.0, 48.0, 73.0, 105.0, 137.0, 161.0]:
		var distance := absf(px - center)
		if distance < 4.0:
			ramps += (1.0 - distance / 4.0) * 1.6
	return base + ramps

func _ready() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.58, 0.77, 0.94)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.95, 0.95, 1.0)
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -25, -20)
	sun.shadow_enabled = true
	add_child(sun)
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true
	camera.fov = 55.0
	camera.near = 0.05
	camera.far = 300.0
	# One solid continuous surface; no individually rotated terrain blocks.
	var ground := MeshInstance3D.new()
	var mesh := ArrayMesh.new()
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for i in range(201):
		var xx := float(i) - 10.0
		var yy := surface(xx)
		vertices.append(Vector3(xx, yy, 2.0))
		vertices.append(Vector3(xx, yy, -2.0))
		vertices.append(Vector3(xx, -7.0, 2.0))
		vertices.append(Vector3(xx, -7.0, -2.0))
	for i in range(200):
		var j := i * 4
		indices.append_array(PackedInt32Array([j, j+1, j+4, j+1, j+5, j+4]))
		indices.append_array(PackedInt32Array([j+2, j, j+6, j, j+4, j+6]))
		indices.append_array(PackedInt32Array([j+1, j+3, j+5, j+3, j+7, j+5]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	ground.mesh = mesh
	var dirt := mat(Color(0.38, 0.31, 0.24))
	dirt.roughness = 0.98
	dirt.cull_mode = BaseMaterial3D.CULL_DISABLED
	ground.material_override = dirt
	add_child(ground)
	# Low-cost depth cues: distant mountains and track-side rocks.
	var scenery := Node3D.new()
	add_child(scenery)
	for i in range(34):
		var xx := float(i) * 6.5 - 8.0
		var rock := cube(scenery, Vector3(1.2 + float(i % 3), 1.1 + float(i % 4), 1.1), Vector3(xx, surface(xx) - 0.15, -3.4), Color(0.35, 0.34, 0.31))
		rock.rotation.y = float(i % 5) * 0.17
	for i in range(18):
		var xx := float(i) * 12.0 - 10.0
		var mountain := cube(scenery, Vector3(7.0, 9.0 + float(i % 5) * 2.0, 3.0), Vector3(xx, -4.5, -17.0), Color(0.39, 0.49, 0.51))
		mountain.rotation.z = 0.2
	bike = Node3D.new()
	add_child(bike)
	# Optional licensed Honda CRF 450 GLB. No unverified download URLs.
	# Fallback geometry remains until asset is present and successfully imported.
	if ResourceLoader.exists("res://assets/honda_crf450.glb"):
		var scene := load("res://assets/honda_crf450.glb") as PackedScene
		if scene != null:
			imported_motorcycle = scene.instantiate() as Node3D
			if imported_motorcycle != null:
				bike.add_child(imported_motorcycle)
				imported_motorcycle.rotation.y = PI / 2.0
				imported_motorcycle.position.y = -0.43

	cube(bike, Vector3(1.65, 0.20, 0.3), Vector3(0, 0.55, 0), Color(0.19, 0.21, 0.23))
	cube(bike, Vector3(0.92, 0.38, 0.48), Vector3(0.15, 0.88, 0), Color(0.88, 0.13, 0.07))
	cube(bike, Vector3(0.78, 0.12, 0.45), Vector3(-0.35, 1.16, 0), Color(0.1, 0.11, 0.13))
	for side in [-0.88, 0.88]:
		var wheel := Node3D.new()
		wheel.position.x = side
		bike.add_child(wheel)
		cylinder(wheel, 0.43, 0.22, Vector3.ZERO, Color(0.055, 0.06, 0.07))
		cylinder(wheel, 0.23, 0.25, Vector3.ZERO, Color(0.64, 0.67, 0.7))
		wheel_visuals.append(wheel)
	cube(bike, Vector3(0.38, 0.78, 0.35), Vector3(-0.26, 1.64, 0), Color(0.18, 0.23, 0.33))
	var helmet := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.26
	sphere.height = 0.52
	helmet.mesh = sphere
	helmet.position = Vector3(-0.13, 2.19, 0)
	helmet.material_override = mat(Color(0.98, 0.65, 0.08))
	bike.add_child(helmet)
	if is_instance_valid(imported_motorcycle):
		# Hide only fallback visual meshes, retaining the imported asset.
		for node in bike.get_children():
			if node != imported_motorcycle:
				node.visible = false
	var ui := CanvasLayer.new()
	add_child(ui)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(root)
	hud = Label.new()
	hud.position = Vector2(22, 16)
	hud.add_theme_font_size_override("font_size", 25)
	root.add_child(hud)
	for spec in [["back", "LEAN -", 0.02], ["forward", "LEAN +", 0.17], ["brake", "BRAKE", 0.70], ["gas", "GAS", 0.85]]:
		var btn := Button.new()
		btn.text = spec[1]
		btn.anchor_left = spec[2]
		btn.anchor_right = spec[2] + 0.13
		btn.anchor_top = 0.79
		btn.anchor_bottom = 0.96
		btn.add_theme_font_size_override("font_size", 19)
		root.add_child(btn)
		btn.button_down.connect(_set_button.bind(spec[0], true))
		btn.button_up.connect(_set_button.bind(spec[0], false))
	var restart := Button.new()
	restart.text = "RESTART"
	restart.anchor_left = 0.78
	restart.anchor_right = 0.96
	restart.anchor_top = 0.02
	restart.anchor_bottom = 0.12
	root.add_child(restart)
	restart.pressed.connect(_reset)
	_reset()

func _set_button(which: String, pressed: bool) -> void:
	buttons[which] = pressed

func _reset() -> void:
	progress = 0.0
	velocity = 0.0
	vertical_speed = 0.0
	spin_speed = 0.0
	crashed = false
	rear_compression = 0.0
	front_compression = 0.0
	elapsed = 0.0
	pitch = 0.0
	bike_y = surface(progress) + 0.45

func _physics_process(dt: float) -> void:
	if crashed:
		hud.text = "CRASH! RESTART  |  GRAVITY TRIALS 2.1"
		return
	elapsed += dt
	var gas: bool = buttons["gas"] or Input.is_key_pressed(KEY_D)
	var brake: bool = buttons["brake"] or Input.is_key_pressed(KEY_A)
	var lean: float = float(int(buttons["forward"])) - float(int(buttons["back"]))
	var half_base := 0.88
	var wheel_radius := 0.43
	var rear_x := progress - cos(pitch) * half_base
	var front_x := progress + cos(pitch) * half_base
	var rear_bottom := bike_y - sin(pitch) * half_base - wheel_radius
	var front_bottom := bike_y + sin(pitch) * half_base - wheel_radius
	var rear_depth := surface(rear_x) - rear_bottom
	var front_depth := surface(front_x) - front_bottom
	var rear_on_ground := rear_depth > -0.04
	var front_on_ground := front_depth > -0.04
	var grounded := rear_on_ground or front_on_ground
	var acceleration := -1.1
	if gas and rear_on_ground:
		acceleration = 10.5
	elif brake and grounded:
		acceleration = -17.0
	elif not grounded:
		acceleration = -0.15
	velocity = clampf(velocity + acceleration * dt, -5.0, 19.0)
	progress = clampf(progress + velocity * dt, 0.0, 180.0)
	# Spring-damper response at each wheel; vertical motion is not snapped to ground.
	var spring_force := maxf(0.0, rear_depth) * 135.0 + maxf(0.0, front_depth) * 135.0
	if grounded:
		vertical_speed += (spring_force - vertical_speed * 13.0) * dt
		var slope := atan2(surface(front_x) - surface(rear_x), half_base * 2.0)
		spin_speed += (slope - pitch) * 11.0 * dt
		spin_speed += (front_depth - rear_depth) * 5.0 * dt
		if gas and rear_on_ground:
			spin_speed += 0.55 * dt
		spin_speed *= maxf(0.0, 1.0 - 3.0 * dt)
	else:
		spin_speed *= maxf(0.0, 1.0 - 0.2 * dt)
	spin_speed += lean * (5.5 if grounded else 4.0) * dt
	vertical_speed -= 24.0 * dt
	bike_y += vertical_speed * dt
	pitch += spin_speed * dt
	# Positional collision correction after integrating movement.
	var rear_floor := surface(progress - cos(pitch) * half_base) + wheel_radius + sin(pitch) * half_base
	var front_floor := surface(progress + cos(pitch) * half_base) + wheel_radius - sin(pitch) * half_base
	var floor_y := maxf(rear_floor, front_floor)
	if bike_y < floor_y:
		bike_y = floor_y
		if vertical_speed < 0.0:
			vertical_speed *= -0.08
	if absf(pitch) > 1.65:
		crashed = true
	bike.position = Vector3(progress, bike_y, 0)
	bike.rotation.z = pitch
	rear_compression = lerpf(rear_compression, clampf(rear_depth, 0.0, 0.17), minf(1.0, dt * 10.0))
	front_compression = lerpf(front_compression, clampf(front_depth, 0.0, 0.17), minf(1.0, dt * 10.0))
	for i in wheel_visuals.size():
		wheel_visuals[i].rotation.z -= velocity * dt / wheel_radius
		wheel_visuals[i].position.y = -(rear_compression if i == 0 else front_compression) * 0.45
	var look := Vector3(progress + 1.7, bike_y + 0.9, 0)
	camera.position = camera.position.lerp(Vector3(progress + 1.7, bike_y + 2.8, 14.0), minf(1.0, dt * 5.0))
	camera.look_at(look)
	hud.text = "GRAVITY TRIALS 2.1  |  %0.1fs  |  %0.0fm" % [elapsed, progress]
	if progress >= 180.0:
		_reset()
