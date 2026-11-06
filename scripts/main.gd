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
var external_bike: Node3D
var visual_wheels: Array[Node3D] = []

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

func beam(parent: Node3D, from_pos: Vector3, to_pos: Vector3, thickness: float, color: Color) -> void:
	var center = (from_pos + to_pos) * 0.5
	var direction = to_pos - from_pos
	var segment = box(parent, Vector3(thickness, direction.length(), thickness), center, color)
	segment.quaternion = Quaternion(Vector3.UP, direction.normalized())

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
	cam.position = Vector3(4, 4, 13)
	cam.rotation_degrees = Vector3(-5, 0, 0)
	cam.fov = 43
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
	var controls = [["back", "BACK", 0.03], ["forward", "FWD", 0.18], ["brake", "BRAKE", 0.72], ["gas", "GAS", 0.87]]
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
	visual_wheels.clear()
	external_bike = null
	finished = false
	if is_instance_valid(terrain):
		terrain.queue_free()
	if is_instance_valid(bike):
		bike.queue_free()
	terrain = Node3D.new()
	add_child(terrain)
	var sand = [Color(0.39, 0.34, 0.23), Color(0.41, 0.38, 0.33), Color(0.23, 0.37, 0.20), Color(0.62, 0.42, 0.24), Color(0.36, 0.38, 0.39)][level]
	for i in range(250):
		var a = float(i)
		var b = a + 1.0
		var mid = (a + b) * 0.5
		var slope = atan2(ground_at(b) - ground_at(a), 1.0)
		var part = box(terrain, Vector3(1.03, 12.0, 12.0), Vector3(mid, (ground_at(a) + ground_at(b)) * 0.5 - 6.0, 0), sand)
		part.rotation.z = slope
	box(terrain, Vector3(0.3, 7, 5), Vector3(230, ground_at(230) + 3.5, 0), Color(0.1, 0.9, 0.5))
	bike = Node3D.new()
	add_child(bike)
	if ResourceLoader.exists("res://assets/trials_bike.glb"):
		var packed = load("res://assets/trials_bike.glb") as PackedScene
		if packed != null:
			external_bike = packed.instantiate() as Node3D
			if external_bike != null:
				bike.add_child(external_bike)
				# Asset is +Z forward; gameplay is +X forward.
				external_bike.rotation.y = PI / 2.0
				external_bike.position.y = -0.52
				external_bike.scale = Vector3.ONE
				external_bike.visible = true
	
	var use_fallback = not is_instance_valid(external_bike)
	# Procedural enduro silhouette: spoke wheels, frame triangle, tank, plastics, exhaust.
	var rubber = Color(0.065, 0.069, 0.072)
	var steel = Color(0.67, 0.72, 0.76)
	var red = Color(0.9, 0.12, 0.065)
	var dark = Color(0.12, 0.15, 0.18)
	for offset in [-0.95, 0.95]:
		var assembly = Node3D.new()
		assembly.position = Vector3(offset, 0, 0)
		bike.add_child(assembly)
		var tire = MeshInstance3D.new()
		var tire_mesh = TorusMesh.new()
		tire_mesh.inner_radius = 0.37
		tire_mesh.outer_radius = 0.53
		tire.mesh = tire_mesh
		tire.rotation_degrees.x = 90
		tire.material_override = material(rubber)
		assembly.add_child(tire)
		var hub = MeshInstance3D.new()
		var hub_mesh = CylinderMesh.new()
		hub_mesh.top_radius = 0.13
		hub_mesh.bottom_radius = 0.13
		hub_mesh.height = 0.36
		hub.mesh = hub_mesh
		hub.rotation_degrees.x = 90
		hub.material_override = material(steel)
		assembly.add_child(hub)
		for spoke in range(12):
			var a = float(spoke) * TAU / 12.0
			var rod = box(assembly, Vector3(0.025, 0.74, 0.025), Vector3(sin(a) * 0.2, cos(a) * 0.2, 0), steel)
			rod.rotation.z = -a
		wheel_nodes.append(tire)
	# Frame and chassis components
	beam(bike, Vector3(-0.95, 0.0, 0), Vector3(-0.28, 0.94, 0), 0.12, steel)
	beam(bike, Vector3(-0.28, 0.94, 0), Vector3(0.55, 0.66, 0), 0.13, steel)
	beam(bike, Vector3(0.55, 0.66, 0), Vector3(-0.95, 0, 0), 0.12, steel)
	beam(bike, Vector3(0.57, 1.28, 0), Vector3(0.95, 0, 0), 0.11, steel)
	box(bike, Vector3(0.84, 0.5, 0.59), Vector3(0.19, 1.05, 0), red).rotation.z = -0.13
	box(bike, Vector3(0.91, 0.16, 0.48), Vector3(-0.51, 1.25, 0), dark)
	box(bike, Vector3(0.68, 0.11, 0.62), Vector3(0.93, 1.18, 0), red)
	box(bike, Vector3(0.7, 0.12, 0.57), Vector3(-0.96, 0.63, 0), red)
	box(bike, Vector3(0.54, 0.57, 0.5), Vector3(-0.18, 0.57, 0), Color(0.34, 0.37, 0.39))
	box(bike, Vector3(0.6, 0.16, 0.2), Vector3(-0.65, 0.79, -0.36), steel)
	beam(bike, Vector3(0.54, 1.29, -0.38), Vector3(0.95, 1.29, 0.38), 0.08, dark)
	if not use_fallback:
		for child in bike.get_children():
			if child != external_bike:
				child.visible = false
	rider = Node3D.new()
	bike.add_child(rider)
	box(rider, Vector3(0.45, 0.76, 0.46), Vector3(-0.4, 1.75, 0), Color(0.12, 0.22, 0.34)).rotation.z = -0.2
	for side in [-0.27, 0.27]:
		beam(rider, Vector3(-0.24, 2.03, side), Vector3(0.54, 1.34, side), 0.13, Color(0.15, 0.19, 0.24))
		beam(rider, Vector3(-0.53, 1.43, side), Vector3(-0.23, 0.83, side), 0.19, Color(0.13, 0.16, 0.2))
		beam(rider, Vector3(-0.23, 0.83, side), Vector3(0.09, 0.49, side), 0.17, Color(0.13, 0.16, 0.2))
	var helmet = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.32
	sphere.height = 0.64
	helmet.mesh = sphere
	helmet.position = Vector3(-0.21, 2.48, 0)
	helmet.material_override = material(Color(0.91, 0.35, 0.08))
	rider.add_child(helmet)
	box(rider, Vector3(0.23, 0.13, 0.48), Vector3(0.03, 2.45, 0), dark)
	if use_fallback:
		pass
	else:
		# Hide procedural motorcycle while keeping rider visible.
		for child in bike.get_children():
			if child != external_bike and child != rider:
				child.visible = false

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
		wheel.rotation.z -= speed * delta / wheel_radius
		suspension[i] = lerpf(suspension[i], clampf((rear_penetration if i == 0 else front_penetration), 0.0, 0.2), minf(1.0, delta * 12.0))
		wheel.position.y = -suspension[i] * 0.45
	cam.position = cam.position.lerp(Vector3(x + 1.7, height + 2.4, 13), minf(1.0, delta * 3.0))
	cam.look_at(Vector3(x + 1.7, height + 0.8, 0))
	if x >= 230:
		load_level(level + 1)
	elif not finished:
		label.text = "%s   %0.1f s   %d / 5" % [NAMES[level], elapsed, level + 1]
