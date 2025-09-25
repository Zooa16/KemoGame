# the_core.gd
extends Node

# UI nodes
@onready var next = $UI/UI_Spectator/Next
@onready var back = $UI/UI_Spectator/Back
@onready var timer_label: Label = $UI/MarginContainer/TimerLabel
@onready var cards_label: Label = $UI/UI_Player/CardsCollectedLabel
@onready var turn_timer: Timer = $TurnTimer
@onready var password_label: Label = $UI/UI_Player/PasswordLabel # Make sure this path is correct
# Player spawn point
@onready var player_spawn_points_parent = $SpawnPoints
var player_spawn_points: Array = []

# Card spawn point
@onready var card_spawn_points_parent = $CardSpawnPoints
var card_spawn_points: Array = []
var max_cards_to_collect := 0

# Spectator variables
var spectator_delay := 0.5
var spectator_target_id: int = -1
var retry_timer := 0.0
var spectator_ready := false
var combined_collected_cards: Array = []
# 3 minutes per turn
var turn_duration := 60
var time_left := 0

# Load your single card scene
var card_scene = preload("res://Scenes/Cards.tscn")
# Load your single player scene
var player_scene = preload("res://multiplayerอย่าย้ายไฟล์/player.tscn")


func _ready():
	turn_timer.timeout.connect(_on_TurnTimer_timeout)

	for child in player_spawn_points_parent.get_children():
		if child is Marker3D:
			player_spawn_points.append(child)

	for child in card_spawn_points_parent.get_children():
		if child is Marker3D:
			card_spawn_points.append(child)

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	var my_id = multiplayer.get_unique_id()

	# Debug
	print("--- Debug: the_core.gd _ready() ---")
	print("Global.the_mission_team: ", Global.the_mission_team)
	print("Global.no_mission_team: ", Global.no_mission_team)
	print("Local Player ID: ", my_id)
	print("-----------------------------------")

	# ⭐ NEW: ส่วนนี้จะทำการ spawn ผู้เล่นทั้งหมดที่อยู่ในห้อง
	if multiplayer.is_server():
		# รับรายชื่อผู้เล่นทั้งหมดที่เชื่อมต่ออยู่
		var all_peers = multiplayer.get_peers()
		# เพิ่ม ID ของโฮสต์ (ตัวเอง) เข้าไปในรายการด้วย
		all_peers.append(multiplayer.get_unique_id())

		# วนลูปเพื่อสร้างผู้เล่นทุกคน
		for player_id in all_peers:
			spawn_player(player_id)

		generate_random_number_cards()
	# ⭐ NEW: Client จะทำการ spawn ผู้เล่นของตัวเองทันทีที่ฉากโหลด
	else:
		spawn_player(my_id)

	if Global.the_mission_team.has(my_id):
		get_node("UI/UI_Spectator").visible = false
		get_node("UI/UI_Player").visible = true
	else:
		get_node("UI/UI_Player").visible = false
		get_node("UI/UI_Spectator").visible = true
		become_spectator()

	if not Global.revealed_role:
		show_role_reveal()
	else:
		print("Role already revealed. Starting game directly.")
		start_turn_timer()

	activate_computers()

	# --- New: Connect Next and Back buttons ---
	next.pressed.connect(_on_next_pressed)
	back.pressed.connect(_on_back_pressed)

	# Ensure we have a reference to the label
	if not is_instance_valid(password_label):
		print("Error: PasswordLabel node not found!")
		return
	update_password_display()

# --------------------- Timer ------------------------

func start_turn_timer():
	if not multiplayer.is_server():
		return

	time_left = turn_duration
	timer_label.visible = true
	
	rpc("update_timer_label", time_left)

	turn_timer.wait_time = 1.0
	turn_timer.one_shot = false
	turn_timer.start()


func _on_TurnTimer_timeout():
	if multiplayer.is_server():
		time_left -= 1
		if time_left < 0:
			turn_timer.stop()
			var is_success = false
			if Global.entered_password == Global.four_digit_code:
				is_success = true
			
			# ส่งค่า is_success ไปกับ RPC
			rpc("go_to_Round_results", is_success) 
		else:
			rpc("update_timer_label", time_left)

@rpc("any_peer", "call_local")
func update_timer_label(new_time: int):
	time_left = new_time
	timer_label.visible = true
	var minutes = int(time_left / 60)
	var seconds = int(time_left % 60)
	timer_label.text = "%02d:%02d" % [minutes, seconds]

# โค้ดใหม่
@rpc("any_peer", "call_local")
func go_to_Round_results(is_success: bool):
	turn_timer.stop()
	
	# โค้ดนี้จะทำงานบนทุกเครื่อง (โฮสต์และไคลเอนต์)
	Global.mission_success = is_success
	if is_success:
		Global.mission_wins += 1
	else:
		Global.mission_losses += 1
		
	print("ปัจจุบัน: ชนะ " + str(Global.mission_wins) + " ครั้ง, แพ้ " + str(Global.mission_losses) + " ครั้ง")

	get_tree().change_scene_to_file("res://Scenes/Round_results.tscn")
	
# --------------------- Spectator ------------------------

func become_spectator():
	print("--- Debug: become_spectator() ---")
	if Global.the_mission_team.is_empty():
		return

	spectator_target_id = Global.the_mission_team.pick_random()
	change_spectator_target(spectator_target_id)

func change_spectator_target(target_id: int):
	spectator_target_id = target_id
	spectator_ready = false

	var spectator_cam = $SpectatorCamera
	spectator_cam.current = true

	# fallback มุมกว้างก่อน
	spectator_cam.position = Vector3(0, 30, -30)
	spectator_cam.look_at(Vector3.ZERO, Vector3.UP)

	# delay ก่อนจะตาม player จริง
	var delay_timer = get_tree().create_timer(spectator_delay)
	delay_timer.timeout.connect(func():
		spectator_ready = true
		retry_timer = 3.0
		print("Spectator is now following player:", spectator_target_id)
	)

func _process(delta):
	if not spectator_ready:
		return

	var spectator_cam = $SpectatorCamera
	var target_node = get_node_or_null("Player_" + str(spectator_target_id))

	if target_node:
		var target_pos = target_node.global_position
		spectator_cam.position = target_pos + Vector3(0, 9, 6)
		spectator_cam.look_at(target_pos, Vector3.UP)
	else:
		# ลดเวลา retry
		retry_timer -= delta
		if retry_timer <= 0:
			if not Global.the_mission_team.is_empty():
				var new_target_id = Global.the_mission_team.pick_random()
				print("Retry: Switching spectator to player", new_target_id)
				change_spectator_target(new_target_id)
	# ลบการเรียก update_password_display() ออกจาก _process เพื่อป้องกันการซิงค์ถี่เกินไป
	# update_password_display()

func _on_next_pressed():
	if Global.the_mission_team.is_empty():
		return

	var mission_ids = Global.the_mission_team.duplicate()
	mission_ids.sort() # Sort the IDs to ensure a predictable order

	var current_index = mission_ids.find(spectator_target_id)
	var next_index = (current_index + 1) % mission_ids.size()

	var new_target_id = mission_ids[next_index]
	change_spectator_target(new_target_id)

func _on_back_pressed():
	if Global.the_mission_team.is_empty():
		return

	var mission_ids = Global.the_mission_team.duplicate()
	mission_ids.sort()

	var current_index = mission_ids.find(spectator_target_id)
	var prev_index = (current_index - 1 + mission_ids.size()) % mission_ids.size()

	var new_target_id = mission_ids[prev_index]
	change_spectator_target(new_target_id)

#--------------------- activate_computers ------------------------
func activate_computers():
	if not multiplayer.is_server():
		print("Function 'activate_computers' can only be called by the host.")
		return

	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var activated_ids = []

	# สุ่ม ID 2 หมายเลขที่ไม่ซ้ำกัน
	while activated_ids.size() < 1:
		var new_id = rng.randi_range(1, 2)
		if not activated_ids.has(new_id):
			activated_ids.append(new_id)

	# DEBUG: print the generated IDs on the host before sending
	print("DEBUG: Host is activating computers with IDs: ", activated_ids)

#เรียกใช้ RPC เพื่อส่งข้อมูลไปยังทุก peer (ไคลเอนต์)
	rpc("sync_activated_computers", activated_ids)

#ฟังก์ชัน RPC ที่จะทำงานบนทุกเครื่อง (เซิร์ฟเวอร์และไคลเอนต์)
@rpc("any_peer", "call_local")
func sync_activated_computers(ids: Array):
	# DEBUG: print to confirm IDs have been received on this machine
	print("DEBUG: Received activated computer IDs from host: ", ids)

	#อัปเดตตัวแปรใน Global.gd
	Global.computer_ids_to_activate = ids
	# เนื่องจากตัวแปรถูก set(value) ใน Global.gd อยู่แล้ว,
	# จะมีการเรียก emit_signal("computer_ids_updated") โดยอัตโนมัติ

# --------------------- Role reveal ------------------------

func show_role_reveal():
	var role_reveal_scene = preload("res://Scenes/role_reveal.tscn")
	var role_reveal_node = role_reveal_scene.instantiate()
	get_tree().root.add_child(role_reveal_node)

	Global.revealed_role = true

	var my_id = multiplayer.get_unique_id()
	var my_role = Global.player_roles.get(my_id, {}).get("base", "Unknown")
	var is_leader = Global.player_roles.get(my_id, {}).get("leader", false)

	role_reveal_node.show_role(my_role, is_leader)
	role_reveal_node.role_reveal_finished.connect(on_role_reveal_finished)

func on_role_reveal_finished():
	print("Role reveal animation finished. Starting game timer.")
	start_turn_timer()

# --------------------- Multiplayer ------------------------

func _on_peer_connected(id: int):
	# ⭐ NEW: Always spawn new players regardless of team
	spawn_player(id)

	if multiplayer.is_server():
		rpc_id(id, "update_timer_label", time_left)

func _on_peer_disconnected(id: int):
	var player = get_node_or_null("Player_" + str(id))
	if player:
		player.queue_free()
		print("Despawned player with ID: " + str(id))

# --------------------- Player spawn ------------------------

func get_player_spawn_point_transform(player_id: int) -> Transform3D:
	if player_spawn_points.is_empty():
		return Transform3D.IDENTITY

	var index = player_id % player_spawn_points.size()
	return player_spawn_points[index].transform

func spawn_player(player_id: int):
	if get_node_or_null("Player_" + str(player_id)):
		return

	var spawn_transform = get_player_spawn_point_transform(player_id)
	var player_instance = player_scene.instantiate()

	player_instance.name = "Player_" + str(player_id)
	player_instance.transform = spawn_transform
	player_instance.set_multiplayer_authority(player_id)
	player_instance.scale = Vector3(0.3, 0.3, 0.3)

	add_child(player_instance)

	if multiplayer.is_server():
		player_instance.card_collected_updated.connect(Callable(self, "_on_player_card_collected_updated").bind(player_id))

	if Global.player_colors.has(player_id):
		player_instance.set_player_color.rpc(Global.player_colors[player_id])
	if Global.player_names.has(player_id):
		player_instance.set_player_name.rpc(Global.player_names[player_id])

	if Global.player_roles.has(player_id):
		var role = Global.player_roles[player_id]
		player_instance.set_role(role["base"], role["leader"])

		if role["leader"]:
			Global.leader_id = player_id
			player_instance.update_role_visibility()

	# ⭐ NEW: Handle visibility for players not on the mission team
	if not Global.the_mission_team.has(player_id) and multiplayer.get_unique_id() != player_id:
		# If this is not the local player and they are not on the mission team, hide them.
		player_instance.visible = false
	else:
		# Otherwise, the player should be visible.
		player_instance.visible = true

func update_all_player_properties():
	if Global.player_colors.is_empty() and Global.player_names.is_empty():
		return

	for node in get_tree().get_nodes_in_group("players"):
		var player_id = str(node.name).split("_")[1].to_int()

		if Global.player_colors.has(player_id):
			node.set_player_color.rpc(Global.player_colors[player_id])

		if Global.player_names.has(player_id):
			node.set_player_name.rpc(Global.player_names[player_id])

# --------------------- Cards ------------------------

func generate_random_number_cards():
	if not multiplayer.is_server():
		return

	var all_card_numbers = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
	all_card_numbers.shuffle()

	var available_spawn_points = card_spawn_points.duplicate()
	available_spawn_points.shuffle()

	var numbers_to_spawn = []
	var positions_to_spawn = []

	for i in range(4):
		numbers_to_spawn.append(all_card_numbers[i])

		if i < available_spawn_points.size():
			positions_to_spawn.append(available_spawn_points[i].global_transform.origin)

	print("Generated (unique) numbers: ", numbers_to_spawn)
	print("Generated unique positions: ", positions_to_spawn)

	rpc("spawn_cards_with_numbers", numbers_to_spawn, positions_to_spawn)



@rpc("any_peer", "reliable", "call_local")
func sync_password_string(password_string: String):
	# ฟังก์ชันนี้จะถูกเรียกบนทุกเครื่อง (รวมถึงเซิร์ฟเวอร์)
	Global.entered_password = password_string

	# อัปเดต UI บนเครื่องของแต่ละผู้เล่น
	var ui_node = get_node_or_null("UI/UI_Player")
	if is_instance_valid(ui_node):
		var password_label_node = ui_node.get_node_or_null("PasswordLabel")
		if is_instance_valid(password_label_node): # แก้ไขตรงนี้
			password_label_node.text = password_string

# ⭐ NEW: RPC ที่จะทำงานบนเซิร์ฟเวอร์เพื่อซิงค์ข้อมูลรหัสผ่าน
@rpc("any_peer", "call_local")
func sync_password_to_global(password: String):
	# ตรวจสอบว่าโค้ดนี้ทำงานบนเซิร์ฟเวอร์เท่านั้น
	if not multiplayer.is_server():
		return

	print("Server received password from a client: ", password)

	# อัปเดตตัวแปรใน Global ซึ่งจะทำให้ Signal 'password_updated' ทำงานบนทุกเครื่อง
	Global.entered_password = password

	# เรียกฟังก์ชันอัปเดต UI จากที่นี่
	update_password_display()


# โค้ดส่วนนี้จะทำงานบนโฮสต์เท่านั้น
func update_password_display():
	if not multiplayer.is_server():
		return

	# รหัสผ่านจริงที่สุ่มมาจาก GameManager
	var real_password_numbers = Global.spawned_card_numbers
	if real_password_numbers.is_empty():
		print("Error: Global.spawned_card_numbers is emptys!")
		return

	# รวบรวมการ์ดที่ผู้เล่นในทีมภารกิจเก็บได้
	var combined_collected_cards: Array = []
	for player_id in Global.the_mission_team:
		if Global.collected_cards_by_player.has(player_id):
			# เพิ่มการ์ดที่เก็บได้ของแต่ละผู้เล่นในทีมภารกิจ
			combined_collected_cards.append_array(Global.collected_cards_by_player[player_id])

	# จัดเรียงตัวเลขที่เก็บได้
	combined_collected_cards.sort()

	# สร้างสตริงรหัสผ่านใหม่
	var password_string = ""
	for number_to_check in real_password_numbers:
		if number_to_check in combined_collected_cards:
			password_string += str(number_to_check)
		else:
			password_string += "_"

	# ส่งรหัสผ่านนี้ไปยังผู้เล่นทุกคน
	rpc("sync_password_string", password_string)
