# game.gd
extends Node

@onready var timer_label: Label = $UI/MarginContainer/TimerLabel
@onready var turn_timer: Timer = $TurnTimer
# Player spawn point
@onready var spawn_points_parent = $SpawnPoints
var spawn_points: Array = []
# 3 minutes per turn
var turn_duration := 180
var time_left := 0

func _ready():
	turn_timer.timeout.connect(_on_TurnTimer_timeout)
	for child in spawn_points_parent.get_children():
		if child is Marker3D:
			spawn_points.append(child)

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	# spawn player ของตัวเองเสมอ
	spawn_player(multiplayer.get_unique_id())

	# ถ้าเป็น host → spawn ให้คนอื่นที่มีอยู่แล้ว
	if multiplayer.is_server():
		for player_id in multiplayer.get_peers():
			if player_id != multiplayer.get_unique_id():
				spawn_player(player_id)

func _on_peer_connected(id: int):
	spawn_player(id)
	update_all_player_properties()

	# Server tells the new player the remaining time
	if multiplayer.is_server():
		rpc_id(id, "update_timer_label", time_left)
	
# despawn เมื่อ peer หลุด
func _on_peer_disconnected(id: int):
	var player = get_node_or_null("Player_" + str(id))
	if player:
		player.queue_free()
		print("Despawned player with ID: " + str(id))
		
# เลือกตำแหน่ง spawn ตาม player_id
func get_spawn_point_transform(player_id: int) -> Transform3D:
	if spawn_points.is_empty():
		return Transform3D.IDENTITY
	
	var index = player_id % spawn_points.size()
	return spawn_points[index].transform

# server สั่ง spawn player
func spawn_player(player_id: int):
	if get_node_or_null("Player_" + str(player_id)):
		return # กัน spawn ซ้ำ

	var spawn_transform = get_spawn_point_transform(player_id)
	var player_scene = preload("res://multiplayerอย่าย้ายไฟล์/player.tscn")
	var player_instance = player_scene.instantiate()

	player_instance.name = "Player_" + str(player_id)
	player_instance.transform = spawn_transform
	player_instance.set_multiplayer_authority(player_id)
	player_instance.scale = Vector3(0.3, 0.3, 0.3)

	add_child(player_instance, true)

	if Global.player_colors.has(player_id):
		player_instance.set_player_color.rpc(Global.player_colors[player_id])
	if Global.player_names.has(player_id):
		player_instance.set_player_name.rpc(Global.player_names[player_id])

		
func update_all_player_properties():
	# ตรวจสอบให้แน่ใจว่า Global มีข้อมูล
	if Global.player_colors.is_empty() and Global.player_names.is_empty():
		return

	# วนลูปผ่านทุก Player Node ที่มีอยู่และอัปเดตคุณสมบัติ
	for node in get_tree().get_nodes_in_group("players"):
		var player_id = str(node.name).split("_")[1].to_int()
		
		# อัปเดตสี
		if Global.player_colors.has(player_id):
			node.set_player_color.rpc(Global.player_colors[player_id])
			
		# อัปเดตชื่อ
		if Global.player_names.has(player_id):
			node.set_player_name.rpc(Global.player_names[player_id])


# -------------------------
# TURN SYSTEM
# -------------------------
func start_turn_timer():
	if not multiplayer.is_server():
		return

	time_left = turn_duration
	timer_label.visible = true
	update_timer_label(time_left)

	# Use 1-second ticks for updates
	turn_timer.wait_time = 1.0
	turn_timer.one_shot = false
	turn_timer.start()

func _on_TurnTimer_timeout():
	if multiplayer.is_server():
		time_left -= 1
		if time_left < 0:
			turn_timer.stop()
			rpc("go_to_voting_phase")
		else:
			# 👇 tell everyone (including self) to update UI
			rpc("update_timer_label", time_left)

@rpc("any_peer", "call_local")
func update_timer_label(new_time: int):
	time_left = new_time
	timer_label.visible = true
	var minutes = int(time_left / 60)
	var seconds = int(time_left % 60)
	timer_label.text = "%02d:%02d" % [minutes, seconds]
	
@rpc("any_peer", "call_local")
func go_to_voting_phase():
	var voting_scene = preload("res://scenes/Voting.tscn")
	get_tree().change_scene_to_packed(voting_scene)
