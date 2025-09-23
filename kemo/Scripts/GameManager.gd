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
		get_tree().change_scene_to_file("res://Scenes/game.tscn")

		if multiplayer.is_server():
			await get_tree().create_timer(0.2).timeout
			# ⭐ เพิ่มเงื่อนไขเพื่อตรวจสอบว่าได้มีการสุ่มบทบาทไปแล้วหรือไม่
			if Global.player_roles.is_empty():
				assign_roles()

func on_role_reveal_finished():
	if multiplayer.is_server():
		print("Role reveal finished. Starting game timer...")
		var game_node = get_tree().get_current_scene()
		if game_node.has_method("start_turn_timer"):
			game_node.start_turn_timer()

func _ready():
	if multiplayer.is_server():
		print("GameManager ready on server.")

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
	# 👇 แก้ไขข้อผิดพลาด pick_random ด้วยการแปลงเป็น Array ก่อน
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
	# 👇 แก้ไขให้ส่ง leader_id ไปด้วย
	rpc("sync_player_roles", Global.player_roles, Global.leader_id)

@rpc("any_peer", "reliable", "call_local")
# 👇 แก้ไขให้รับ leader_id เข้ามาด้วย
func sync_player_roles(roles_dict: Dictionary, leader_id: int):
	Global.player_roles = roles_dict
	Global.leader_id = leader_id # <-- ตั้งค่า leader_id ที่นี่
	
	# The `player_role` variable should be set for the local player.
	if Global.player_roles.has(multiplayer.get_unique_id()):
		Global.player_role = Global.player_roles[multiplayer.get_unique_id()]["base"]
	
	# Update the local player's scene with the new role.
	var player_node = get_player_by_id(multiplayer.get_unique_id())
	if player_node:
		# Pass both the base role and leader status to the Player node.
		player_node.set_role(Global.player_roles[multiplayer.get_unique_id()]["base"], Global.player_roles[multiplayer.get_unique_id()]["leader"])
	if not multiplayer.is_server() and not Global.revealed_role:
		var game_node = get_tree().get_root().get_node("game")
		if game_node:
			game_node.show_role_reveal()
	# Update all player nodes' role visibility
	for node in get_tree().get_nodes_in_group("players"):
		node.update_role_visibility()

func get_player_by_id(id: int) -> Node:
	for player in get_tree().get_nodes_in_group("players"):
		if player.get_multiplayer_authority() == id:
			return player
	return null
