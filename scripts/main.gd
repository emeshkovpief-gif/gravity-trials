extends Node3D

const NAMES = ["Training Hills", "Rocky Canyon", "Forest Trial", "Desert Jump", "Extreme Ridge"]
var level = 0
var bike: Node3D
var cam: Camera3D
var label: Label
var elapsed = 0.0
var x = 4.0
var height = 3.0
var speed = 0.0
var vertical = 0.0
var tilt = 0.0
var turn = 0.0
var finished = false
var held = {"gas": false, "brake": false, "back": false, "forward": false}
var terrain: Node3D
var wheel_nodes: Array[MeshInstance3D] = []
var rider: Node3D
var suspension = [0.0, 0.0]
var angular_velocity = 0.0
var grounded = false
var last_speed = 0.0

func material(c: Color) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = c
	return m

func box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material(color)
	node.position = pos
	parent.add_child(node)
	return node

func ground_at(px: float) -> float:
	var t = float(level + 1)
	return sin(px * (0.085 + t * 0.008)) * (0.9 + t * 0.17) + sin(px * 0.21) * (0.25 + t * 0.12) + sin(px * 0.45) * t * 0.07

func _ready() -> void:
	var env = WorldEnvironment.new()
	var e = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.53, 0.72, 0.91)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.9, 0.9, 1.0)
	env.environment = e
	add_child(env)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -30, -20)
	sun.shadow_enabled = true
	add_child(sun)
	cam = Camera3D.new()
	cam.position = Vector3(4, 5, 22)
	cam.rotation_degrees = Vector3(-5, 0, 0)
	cam.fov = 47
	cam.current = true
	add_child(cam)
	var ui = CanvasLayer.new()
	add_child(ui)
	var root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(root)
	label = Label.new()
	label.position = Vector2(24, 16)
	label.add_theme_font_size_override("font_size", 26)
	root.add_child(label)
	var controls = [["back", "↶", 0.03], ["forward", "↷", 0.18], ["brake", "BRAKE", 0.72], ["gas", "GAS", 0.87]]
	for item in controls:
		var b = Button.new()
		b.text = item[1]
		b.anchor_left = item[2]
		b.anchor_right = item[2] + 0.11
		b.anchor_top = 0.79
		b.anchor_bottom = 0.96
		b.offset_left = 0
		b.offset_right = 0
		b.offset_top = 0
		b.offset_bottom = 0
		b.add_theme_font_size_override("font_size", 22)
		root.add_child(b)
		b.button_down.connect(_press.bind(item[0], true))
		b.button_up.connect(_press.bind(item[0], false))
	var restart = Button.new()
	restart.text = "RESTART"
	restart.anchor_left = 0.78
	restart.anchor_right = 0.96
	restart.anchor_top = 0.03
	restart.anchor_bottom = 0.12
	root.add_child(restart)
	restart.pressed.connect(_restart)
	load_level(0)

func _press(key: String, value: bool) -> void:
	held[key] = value

func _restart() -> void:
	load_level(level)

func load_level(n: int) -> void:
	level = n % NAMES.size()
	elapsed = 0.0
	x = 4.0
	height = ground_at(x) + 1.3
	speed = 0.0
	vertical = 0.0
	tilt = 0.0
	turn = 0.0
	angular_velocity = 0.0
	grounded = false
	last_speed = 0.0
	suspension = [0.0, 0.0]
	wheel_nodes.clear()
	finished = false
	if is_instance_valid(terrain):
		terrain.queue_free()
	if is_instance_valid(bike):
		bike.queue_free()
	terrain = Node3D.new()
	add_child(terrain)
	var sand = [Color(0.66, 0.57, 0.36), Color(0.48, 0.46, 0.4), Color(0.29, 0.47, 0.28), Color(0.78, 0.58, 0.32), Color(0.5, 0.5, 0.54)][level]
	for i in range(250):
		var a = float(i)
		var b = a + 1.0
		var mid = (a + b) * 0.5
		var slope = atan2(ground_at(b) - ground_at(a), 1.0)
		var part = box(terrain, Vector3(1.03, 3.0, 6.0), Vector3(mid, (ground_at(a) + ground_at(b)) * 0.5 - 1.5, 0), sand)
		part.rotation.z = slope
	box(terrain, Vector3(0.3, 7, 5), Vector3(230, ground_at(230) + 3.5, 0), Color(0.1, 0.9, 0.5))
	bike = Node3D.new()
	add_child(bike)
	box(bike, Vector3(2.4, 0.38, 0.6), Vector3(0, 0.55, 0), Color(0.1, 0.16, 0.2))
	box(bike, Vector3(1.15, 0.65, 0.8), Vector3(0.15, 0.93, 0), Color(0.93, 0.17, 0.08))
	box(bike, Vector3(0.7, 0.18, 0.8), Vector3(-0.3, 1.38, 0), Color(0.08, 0.08, 0.08))
	for offset in [-0.95, 0.95]:
		var wheel = MeshInstance3D.new()
		var mesh = CylinderMesh.new()
		mesh.top_radius = 0.52
		mesh.bottom_radius = 0.52
		mesh.height = 0.28
		wheel.mesh = mesh
		wheel.rotation_degrees.x = 90
		wheel.position = Vector3(offset, 0.0, 0)
		wheel.material_override = material(Color(0.08, 0.09, 0.1))
		bike.add_child(wheel)
		wheel_nodes.append(wheel)
	rider = Node3D.new()
	bike.add_child(rider)
	box(rider, Vector3(0.34, 0.85, 0.4), Vector3(-0.3, 1.85, 0), Color(0.18, 0.25, 0.65))
	var head = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.34
	sphere.height = 0.68
	head.mesh = sphere
	head.position = Vector3(-0.12, 2.52, 0)
	head.material_override = material(Color(0.96, 0.74, 0.12))
	rider.add_child(head)
	# Fork, swingarm, handlebars and exhaust
	box(bike, Vector3(0.12, 1.3, 0.22), Vector3(0.92, 0.55, 0), Color(0.72, 0.76, 0.8))
	box(bike, Vector3(0.9, 0.13, 0.22), Vector3(-0.53, 0.38, 0), Color(0.65, 0.68, 0.72))
	box(bike, Vector3(0.5, 0.11, 0.9), Vector3(0.87, 1.27, 0), Color(0.12, 0.13, 0.15))
	box(bike, Vector3(0.75, 0.19, 0.22), Vector3(-0.6, 0.8, -0.4), Color(0.6, 0.61, 0.64))

func _physics_process(delta: float) -> void:
	if finished:
		return
	elapsed += delta
	var gas = held["gas"] or Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D)
	var brake = held["brake"] or Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A)
	var lean = float(int(held["forward"] or Input.is_key_pressed(KEY_UP))) - float(int(held["back"] or Input.is_key_pressed(KEY_DOWN)))
	var wheel_radius = 0.52
	var rear_x = x - cos(tilt) * 0.95
	var front_x = x + cos(tilt) * 0.95
	var rear_y = height - sin(tilt) * 0.95
	var front_y = height + sin(tilt) * 0.95
	var rear_penetration = ground_at(rear_x) + wheel_radius - rear_y
	var front_penetration = ground_at(front_x) + wheel_radius - front_y
	var rear_contact = rear_penetration > -0.07
	var front_contact = front_penetration > -0.07
	grounded = rear_contact or front_contact
	var throttle_force = 0.0
	if gas:
		throttle_force = 18.0 if rear_contact else 2.0
	elif brake:
		throttle_force = -25.0 if grounded else -1.0
	else:
		throttle_force = -4.0 if grounded else -0.5
	speed += throttle_force * delta
	speed = clampf(speed, -7.0, 25.0)
	var previous_x = x
	x = clampf(x + speed * delta, 0.0, 235.0)
	if grounded:
		var slope = atan2(ground_at(front_x) - ground_at(rear_x), 1.9)
		var compression = maxf(0.0, maxf(rear_penetration, front_penetration))
		vertical += (compression * 105.0 - vertical * 13.0) * delta
		angular_velocity += (slope - tilt) * (9.0 if rear_contact and front_contact else 3.0) * delta
		angular_velocity += (front_penetration - rear_penetration) * 2.4 * delta
		angular_velocity += lean * 5.0 * delta
		if gas and rear_contact:
			angular_velocity += 1.15 * delta
		angular_velocity *= maxf(0.0, 1.0 - 3.0 * delta)
	else:
		angular_velocity += lean * 4.2 * delta
		angular_velocity *= maxf(0.0, 1.0 - 0.18 * delta)
	vertical -= 23.0 * delta
	height += vertical * delta
	tilt += angular_velocity * delta
	# Prevent wheels from tunneling into terrain after a landing.
	var rear_bottom = height - sin(tilt) * 0.95 - wheel_radius
	var front_bottom = height + sin(tilt) * 0.95 - wheel_radius
	var correction = maxf(ground_at(x - cos(tilt) * 0.95) - rear_bottom, ground_at(x + cos(tilt) * 0.95) - front_bottom)
	if correction > 0.0:
		height += correction
		if vertical < 0.0:
			vertical = -vertical * 0.10
	# Crash on a severe rollover or a head-first impact.
	if absf(tilt) > 1.72 or (grounded and absf(angular_velocity) > 7.5):
		finished = true
		label.text = "CRASH!  Tap RESTART"
	bike.position = Vector3(x, height, 0)
	bike.rotation.z = tilt
	if is_instance_valid(rider):
		rider.rotation.z = -lean * 0.17
	for i in wheel_nodes.size():
		var wheel = wheel_nodes[i]
		wheel.rotation.y += speed * delta / wheel_radius
		suspension[i] = lerpf(suspension[i], clampf((rear_penetration if i == 0 else front_penetration), 0.0, 0.2), minf(1.0, delta * 12.0))
		wheel.position.y = -suspension[i] * 0.45
	cam.position = cam.position.lerp(Vector3(x + 3.5, height + 4.0, 23), minf(1.0, delta * 3.0))
	cam.look_at(Vector3(x + 3.5, height + 1.0, 0))
	if x >= 230:
		load_level(level + 1)
	elif not finished:
		label.text = "%s   %0.1f s   %d / 5" % [NAMES[level], elapsed, level + 1]
