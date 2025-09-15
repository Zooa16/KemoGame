# main.gd

extends Node

@onready var main_menu = $CanvasLayer/MainMenu
@onready var address_entry = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/AddressEntry
@onready var hud = $CanvasLayer/HUD
@onready var Idroom_label = $CanvasLayer/HUD/VBoxContainer/HBoxContainer/IDROOM/MarginContainer/Idroom_label
@onready var status = $CanvasLayer/HUD/Status
@onready var player_count_label = $CanvasLayer/HUD/player_count_label
@onready var playerlist_label = $"CanvasLayer/HUD/Playerlist/player id"
@onready var start_button = $CanvasLayer/HUD/StartButton
@onready var lobby_spawn_points_parent = $SpawnPoints
@onready var copy_button = $CanvasLayer/HUD/VBoxContainer/HBoxContainer2/CopyButton
@onready var background = $CanvasLayer/TextureRect
@onready var game_start_timer: Timer = $CountdownTimer
@onready var Host_room_name = $CanvasLayer/HUD/VBoxContainer/Host_room_name
@onready var Leave_Room_Button = $"CanvasLayer/HUD/Leave Room Button"

# NEW: เพิ่มปุ่มแสดง/ซ่อน ID ห้อง
@onready var Show_Hide_ID_Button = $CanvasLayer/HUD/VBoxContainer/HBoxContainer2/Show_Hide_ID_Button

var countdown_duration = 5.0
var is_counting_down = false
var is_id_hidden = true # NEW: ตัวแปรสำหรับสถานะการซ่อน ID

var lobby_spawn_points: Array = []
const PLAYER_COLORS: Array[Color] = [
	Color.RED,
	Color.BLUE,
	Color.GREEN,
	Color.YELLOW,
	Color.AQUA,
	Color.MAGENTA,
	Color.ORANGE,
	Color.LIME,
	Color.GRAY,
	Color.PURPLE
]
var used_colors: Dictionary = {}
const Player = preload("res://multiplayerอย่าย้ายไฟล์/player.tscn")
const PORT := 9999
const MAX_PLAYERS := 10

var enet_peer := ENetMultiplayerPeer.new()
var room_code: int = 0
var connected_players: Array = []
var host_id: int = 0
var current_room_name: String = ""

func _ready():
	multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_disconnected.connect(remove_player)
	multiplayer.server_disconnected.connect(server_disconnected)
	multiplayer.connection_failed.connect(connection_failed)
	multiplayer.connected_to_server.connect(connected_to_server)
	copy_button.pressed.connect(_on_copy_button_pressed)
	start_button.pressed.connect(Callable(self, "_on_start_button_pressed"))
	game_start_timer.timeout.connect(Callable(self, "_on_countdown_timeout"))
	
	# NEW: เชื่อมต่อสัญญาณของปุ่มใหม่
	Show_Hide_ID_Button.pressed.connect(_on_show_hide_id_button_pressed)
	Leave_Room_Button.pressed.connect(_on_leave_room_button_pressed)

	for child in lobby_spawn_points_parent.get_children():
		if child is Marker3D:
			lobby_spawn_points.append(child)
	start_button.visible = false
	main_menu.show()
	background.show()
	
	Host_room_name.text = ""
	Idroom_label.text = "ID ROOM: **********" # NEW: ตั้งค่าเริ่มต้นให้เป็น **********

func _process(_delta):
	start_button.visible = multiplayer.is_server()
	if multiplayer.is_server():
		start_button.disabled = connected_players.size() <= 1
	if is_counting_down:
		var time_left_int = int(game_start_timer.time_left)
		if time_left_int >= 0:
			status.text = "เกมจะเริ่มใน " + str(time_left_int + 1) + "..."

func _unhandled_input(_event):
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()

func _on_host_button_pressed():
	main_menu.hide()
	background.hide()
	
	status.text = "Attempting to host..."

	enet_peer.create_server(PORT)
	multiplayer.multiplayer_peer = enet_peer
	
	host_id = multiplayer.get_unique_id()
	Global.player_names[host_id] = Global.my_player_name

	var external_ip = upnp_setup()
	if external_ip:
		room_code = ip_to_code(external_ip)
		status.text = "Success! Your game is ready for external players."
	else:
		var internal_ip = get_internal_ip()
		if internal_ip:
			room_code = ip_to_code(internal_ip)
			status.text = "UPNP failed. Local players can join using this ID."
		else:
			status.text = "Warning: Could not get a local IP address."
	
	# NEW: ตั้งค่าการแสดงผล ID และปุ่มเมื่อ Host สร้างห้อง
	Idroom_label.text = "ID ROOM: **********"
	Show_Hide_ID_Button.text = "Show"
	is_id_hidden = true
	
	current_room_name = Global.my_player_name.to_upper() + "'s Room"
	sync_room_name.rpc(current_room_name)
	
	add_player(host_id)
	hud.show()
	start_button.show()

func _on_join_button_pressed():
	main_menu.hide()
	background.hide()
	status.text = "Attempting to join..."

	var ip_address = code_to_ip(address_entry.text)
	enet_peer.create_client(ip_address, PORT)
	multiplayer.multiplayer_peer = enet_peer
	start_button.hide()
	
	# NEW: ตั้งค่าการแสดงผล ID และปุ่มเมื่อ Client เข้าห้อง
	Idroom_label.text = "ID ROOM: **********"
	Show_Hide_ID_Button.text = "Show"
	is_id_hidden = true

func add_player(peer_id):
	if connected_players.has(peer_id):
		return
	
	if connected_players.size() >= MAX_PLAYERS:
		print("Room is full.")
		enet_peer.disconnect_peer(peer_id, true)
		return
	
	if multiplayer.is_server():
		var available_colors = []
		for c in PLAYER_COLORS:
			if not used_colors.has(c):
				available_colors.append(c)
		
		var selected_color: Color
		if not available_colors.is_empty():
			selected_color = available_colors[randi() % available_colors.size()]
			used_colors[selected_color] = peer_id
			Global.player_colors[peer_id] = selected_color

	connected_players.append(peer_id)
	
	var spawn_position: Vector3
	if multiplayer.is_server():
		var spawn_index = peer_id % lobby_spawn_points.size()
		spawn_position = lobby_spawn_points[spawn_index].global_position
	else:
		spawn_position = Vector3.ZERO

	var player = Player.instantiate()
	player.name = str(peer_id)
	if player.has_method("set_multiplayer_authority"):
		player.set_multiplayer_authority(peer_id)
	if not player.is_in_group("players"):
		player.add_to_group("players")
	
	player.scale = Vector3(0.3, 0.3, 0.3)
	add_child(player)
	
	if multiplayer.is_server():
		sync_player_list.rpc(connected_players)
		sync_player_colors.rpc(Global.player_colors)
		sync_player_names.rpc_id(peer_id, Global.player_names)
		set_room_code.rpc_id(peer_id, room_code)
		set_host_id.rpc(host_id)
		set_all_player_positions.rpc_id(peer_id, peer_id, spawn_position)
		sync_room_name.rpc(current_room_name)

	player.global_position = spawn_position

	update_player_ui()

func remove_player(peer_id):
	connected_players.erase(peer_id)
	Global.player_colors.erase(peer_id)
	Global.player_names.erase(peer_id)
	
	var player = get_node_or_null(str(peer_id))
	if player:
		player.queue_free()

	if peer_id == host_id:
		print("Host has left, initiating host migration...")
		if connected_players.size() > 0:
			var new_host_id = connected_players.min()
			set_host_id.rpc(new_host_id)
			if multiplayer.get_unique_id() == new_host_id:
				print("I am the new host!")
				enet_peer.create_server(PORT)
				multiplayer.multiplayer_peer = enet_peer
				host_id = new_host_id
				sync_player_list.rpc(connected_players)
		else:
			print("No players left, closing server.")
			reset_game()
	else:
		update_player_ui()
		if multiplayer.is_server():
			sync_player_list.rpc(connected_players)

func server_disconnected():
	status.text = "Disconnected from server."
	reset_game()

func connection_failed():
	status.text = "Connection failed. Please check the address or try again."
	main_menu.show()
	background.show()
	hud.hide()
	
func connected_to_server():
	status.text = "Connected to server!"
	hud.show()
	if not multiplayer.is_server():
		register_player_name.rpc_id(1, multiplayer.get_unique_id(), Global.my_player_name)

func reset_game():
	get_tree().change_scene_to_file("res://world.tscn")

func update_player_ui():
	player_count_label.text = str(connected_players.size()) + "/" + str(MAX_PLAYERS)
	var names_text := ""
	for pid in connected_players:
		if Global.player_names.has(pid):
			names_text += Global.player_names[pid] + "\n"
		else:
			names_text += "Player " + str(pid) + "\n"
	playerlist_label.text = names_text

func _on_start_button_pressed():
	if not multiplayer.is_server():
		return
	if not is_counting_down:
		is_counting_down = true
		game_start_timer.wait_time = countdown_duration
		game_start_timer.start()
		_rpc_start_countdown.rpc(countdown_duration)
	else:
		is_counting_down = false
		game_start_timer.stop()
		_rpc_cancel_countdown.rpc()

@rpc("any_peer", "reliable", "call_local")
func _rpc_start_countdown(duration: float):
	is_counting_down = true
	start_button.text = "Cancel"
	game_start_timer.wait_time = duration
	game_start_timer.start()

@rpc("any_peer", "reliable", "call_local")
func _rpc_cancel_countdown():
	is_counting_down = false
	start_button.text = "Start"
	game_start_timer.stop()
	status.text = ""

func _on_countdown_timeout():
	is_counting_down = false
	start_button.text = "Start"
	if multiplayer.is_server():
		get_node("/root/GameManager").start_game.rpc()
	_rpc_cancel_countdown.rpc()

func _on_copy_button_pressed():
	# การคัดลอกยังคงใช้ room_code จริง ไม่ว่ามันจะถูกซ่อนหรือไม่
	DisplayServer.clipboard_set(str(room_code))
	status.text = "รหัสห้องถูกคัดลอกแล้ว!"

# NEW: ฟังก์ชันสำหรับแสดง/ซ่อน ID ห้อง
func _on_show_hide_id_button_pressed():
	is_id_hidden = not is_id_hidden # สลับสถานะ
	if is_id_hidden:
		Idroom_label.text = "ID ROOM: **********"
		Show_Hide_ID_Button.text = "Show"
	else:
		Idroom_label.text = "ID ROOM: " + str(room_code)
		Show_Hide_ID_Button.text = "Hide"

# NEW: ฟังก์ชันสำหรับออกจากห้อง
func _on_leave_room_button_pressed():
	multiplayer.multiplayer_peer.close()
	main_menu.show()
	hud.hide()
	background.show()
	status.text = "ออกจากห้องแล้ว"

@rpc("authority", "reliable")
func set_room_code(code: int):
	room_code = code
	# เราจะไม่อัปเดต Label ทันที แต่จะรอให้ผู้ใช้กดปุ่ม Show
	if not is_id_hidden:
		Idroom_label.text = "ID ROOM: " + str(code)

@rpc("any_peer", "reliable")
func sync_player_list(players: Array):
	connected_players = players
	for player_node in get_tree().get_nodes_in_group("players"):
		if player_node.has_method("set_multiplayer_authority"):
			player_node.set_multiplayer_authority(int(player_node.name))

@rpc("any_peer", "reliable", "call_local")
func set_host_id(new_host_id: int):
	host_id = new_host_id

@rpc("any_peer", "reliable", "call_local")
func start_game():
	if multiplayer.is_server():
		pass
	get_tree().change_scene_to_file("res://Scenes/game.tscn")
	
@rpc("any_peer", "reliable", "call_local")
func sync_player_colors(colors_dict: Dictionary):
	Global.player_colors = colors_dict
	for player_id in colors_dict:
		var player_node = get_node_or_null(str(player_id))
		if player_node and player_node.has_method("set_player_color"):
			player_node.set_player_color(colors_dict[player_id])

@rpc("any_peer", "reliable")
func set_all_player_positions(player_id: int, new_pos: Vector3):
	var player_node = get_node_or_null(str(player_id))
	if not player_node:
		var player = Player.instantiate()
		player.name = str(player_id)
		if player.has_method("set_multiplayer_authority"):
			player.set_multiplayer_authority(player_id)
		if not player.is_in_group("players"):
			player.add_to_group("players")
		player.scale = Vector3(0.3, 0.3, 0.3)
		add_child(player)
		player_node = player
	player_node.global_position = new_pos
	
@rpc("any_peer", "reliable", "call_local")
func sync_player_names(names_dict: Dictionary):
	Global.player_names = names_dict
	for player_id in names_dict:
		var player_node = get_node_or_null(str(player_id))
		if player_node:
			player_node.set_player_name(names_dict[player_id])
	update_player_ui()

@rpc("any_peer", "reliable")
func register_player_name(peer_id: int, new_name: String):
	if not multiplayer.is_server():
		return
	
	print("Received name '", new_name, "' from peer: ", peer_id)
	Global.player_names[peer_id] = new_name
	
	sync_player_names.rpc(Global.player_names)

@rpc("any_peer", "reliable", "call_local")
func sync_room_name(new_room_name: String):
	Host_room_name.text = new_room_name

func upnp_setup():
	var upnp = UPNP.new()
	var discover_result = upnp.discover()
	if discover_result != UPNP.UPNP_RESULT_SUCCESS:
		print("UPNP Discover Failed! Error %s" % discover_result)
		return null
	if not (upnp.get_gateway() and upnp.get_gateway().is_valid_gateway()):
		print("UPNP Invalid Gateway!")
		return null
	var map_result = upnp.add_port_mapping(PORT)
	if map_result != UPNP.UPNP_RESULT_SUCCESS:
		print("UPNP Port Mapping Failed! Error %s" % map_result)
		return null
	return upnp.query_external_address()

func get_internal_ip():
	var host_addresses = IP.get_local_addresses()
	for addr in host_addresses:
		if addr.find(":") != -1:
			continue
		if addr.begins_with("127."):
			continue
		if addr.begins_with("169.254."):
			continue
		return addr
	return null

func ip_to_code(ip_string):
	var parts = ip_string.split(".")
	if parts.size() != 4:
		return 0
	var ip_code := 0.0
	for i in range(4):
		ip_code += int(parts[i]) * pow(256, 3 - i)
	return int(ip_code)

func code_to_ip(ip_code_string):
	var ip_code := int(ip_code_string)
	var ip_parts: Array = []
	for i in range(4):
		var part = ip_code / pow(256, 3 - i)
		ip_parts.append(str(int(part)))
		ip_code -= int(part) * pow(256, 3 - i)
	return ".".join(ip_parts)

func _on_multiplayer_spawner_spawned(_node: Node) -> void:
	pass
