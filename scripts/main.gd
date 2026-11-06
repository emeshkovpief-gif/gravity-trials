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
	return 0.35 * sin(px * 0.16) + 0.22 * sin(px * 0.31)

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
	sun.shadow_enabled = false
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
	var dirt := mat(Color(0.48, 0.34, 0.22))
	dirt.cull_mode = BaseMaterial3D.CULL_DISABLED
	ground.material_override = dirt
	add_child(ground)
	bike = Node3D.new()
	add_child(bike)
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
	elapsed = 0.0
	pitch = 0.0
	bike_y = surface(progress) + 0.45

func _physics_process(dt: float) -> void:
	elapsed += dt
	var gas: bool = buttons["gas"] or Input.is_key_pressed(KEY_D)
	var brake: bool = buttons["brake"] or Input.is_key_pressed(KEY_A)
	var lean: float = float(int(buttons["forward"])) - float(int(buttons["back"]))
	if gas:
		velocity += 7.0 * dt
	elif brake:
		velocity -= 10.0 * dt
	else:
		velocity = move_toward(velocity, 0.0, 3.0 * dt)
	velocity = clampf(velocity, -4.0, 14.0)
	progress = clampf(progress + velocity * dt, 0.0, 180.0)
	var target_pitch := atan2(surface(progress + 0.88) - surface(progress - 0.88), 1.76)
	pitch = lerp_angle(pitch, target_pitch + lean * 0.12, minf(1.0, 5.0 * dt))
	bike_y = lerpf(bike_y, surface(progress) + 0.45, minf(1.0, 12.0 * dt))
	bike.position = Vector3(progress, bike_y, 0)
	bike.rotation.z = pitch
	for wheel in wheel_visuals:
		wheel.rotation.z -= velocity * dt / 0.43
	var look := Vector3(progress + 1.0, bike_y + 1.0, 0)
	camera.position = Vector3(progress + 1.0, bike_y + 2.7, 13.0)
	camera.look_at(look)
	hud.text = "GRAVITY TRIALS 2.0  |  %0.1fs  |  %0.0fm" % [elapsed, progress]
	if progress >= 180.0:
		_reset()
