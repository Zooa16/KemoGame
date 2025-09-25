# GameManager.gd
extends Node

# This dictionary is now for temporary use only
var special_roles := {
	"Leader": null
}

@rpc("any_peer", "reliable", "call_local")
func start_game():
	print("Changing scene to game...")
	if get_tree():
		# ⭐ IMPORTANT: รีเซ็ตค่า Global ต่างๆ เมื่อเริ่มเกมใหม่
		Global.collected_cards_by_player.clear() # ล้างข้อมูลการ์ดที่เก็บได้
		Global.the_mission_team.clear() # ล้างข้อมูลทีม
		Global.no_mission_team.clear() # ล้างข้อมูลทีมที่ไม่เข้าร่วมภารกิจ
		Global.eliminated_player_id = -1 # รีเซ็ตผู้เล่นที่ถูกคัดออก
		
		
		# ⭐ NEW: จัดการหมายเลขรอบเกม
		# ถ้าไม่มี Global.round_number (เกมเพิ่งเริ่ม) ให้ตั้งเป็น 1
		if Global.round_number == 0:
			Global.round_number = 1
		else:
			# ถ้าเกมวนลูป ให้เพิ่มหมายเลขรอบ
			Global.round_number += 1
		
		get_tree().change_scene_to_file("res://Scenes/game.tscn")

		if multiplayer.is_server():
			await get_tree().create_timer(0.2).timeout
			# ⭐ NEW: ตรวจสอบว่าได้มีการสุ่มบทบาทไปแล้วหรือไม่
			if Global.player_roles.is_empty():
				assign_roles()
			
			# ⭐ NEW: ส่งหมายเลขรอบเกมไปให้ผู้เล่นทุกคน
			rpc("sync_round_number", Global.round_number)

@rpc("any_peer", "reliable", "call_local")
func sync_round_number(number: int):
	Global.round_number = number
	
	var game_node = get_tree().get_current_scene()
	if game_node and game_node.has_method("update_round_label"):
		game_node.update_round_label()


func _ready():
	if multiplayer.is_server():
		print("GameManager ready on server.")
		Global.round_number = 0 # ⭐ ตั้งค่าเริ่มต้นของรอบเกม
		
func assign_roles():
	if not multiplayer.is_server():
		return

	var connected_players_list = multiplayer.get_peers()
	connected_players_list.append(multiplayer.get_unique_id())
	
	# 1. Build the role pool for all players.
	var role_pool: Array = []
	for role in Global.role_counts.keys():
		for i in range(Global.role_counts[role]):
			role_pool.append(role)
	
	role_pool.shuffle()
	Global.player_roles.clear()
	
	# 2. Assign a random base role to each player first.
	var assigned_count = 0
	for player_id in connected_players_list:
		var role_to_assign = role_pool.pop_front()
		Global.player_roles[player_id] = {"base": role_to_assign, "leader": false}
		assigned_count += 1
	
	# 3. Choose a random leader.
	var leader_peer_id = Array(connected_players_list).pick_random()
	Global.leader_id = leader_peer_id
	
	# Also include the "leader" status.
	if Global.player_roles.has(leader_peer_id):
		Global.player_roles[leader_peer_id]["leader"] = true
	
	# Store the Leader's ID in the special roles dictionary.
	special_roles["Leader"] = leader_peer_id
	
	print("Leader chosen:", leader_peer_id)
	print("Assigned roles:", Global.player_roles)

	# 4. Propagate roles to all players.
	rpc("sync_player_roles", Global.player_roles, Global.leader_id)
	
	# ⭐ NEW: ส่งหมายเลขรอบเกมหลังการสุ่มบทบาท
	rpc("sync_round_number", Global.round_number)
	
	# ⭐ NEW: ส่งสัญญาณให้ client ทุกคนรู้ว่าเริ่มรอบใหม่แล้ว
	rpc("sync_game_start")

@rpc("any_peer", "reliable", "call_local")
func sync_player_roles(roles_dict: Dictionary, leader_id: int):
	Global.player_roles = roles_dict
	Global.leader_id = leader_id
	
	if Global.player_roles.has(multiplayer.get_unique_id()):
		Global.player_role = Global.player_roles[multiplayer.get_unique_id()]["base"]
	
	var player_node = get_player_by_id(multiplayer.get_unique_id())
	if player_node:
		player_node.set_role(Global.player_roles[multiplayer.get_unique_id()]["base"], Global.player_roles[multiplayer.get_unique_id()]["leader"])
	if not multiplayer.is_server() and not Global.revealed_role:
		var game_node = get_tree().get_root().get_node("game")
		if game_node:
			game_node.show_role_reveal()
	for node in get_tree().get_nodes_in_group("players"):
		node.update_role_visibility()

func get_player_by_id(id: int) -> Node:
	for player in get_tree().get_nodes_in_group("players"):
		if player.get_multiplayer_authority() == id:
			return player
	return null
