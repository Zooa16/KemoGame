# GameManager.gd
extends Node

# This dictionary is redundant since we'll use Global.player_roles
# var player_roles = {} 
# The roles array is also in Global.gd, so this is redundant
# var roles := ["Data Retriever", "Support", "The Oracle", "Tracer", "Enforcer", "Hacker", "System Controller"]

# NEW: store special roles
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
			assign_roles()

func on_role_reveal_finished():
	if multiplayer.is_server():
		print("Role reveal finished. Starting game timer...")
		var game_node = get_tree().get_current_scene()
		if game_node.has_method("start_turn_timer"):
			game_node.start_turn_timer()


# Predefined roles

func _ready():
	if multiplayer.is_server():
		print("GameManager ready on server.")


func assign_roles():
	if not multiplayer.is_server():
		return

	var connected_players_list = multiplayer.get_peers()
	connected_players_list.append(multiplayer.get_unique_id())

	# Convert PackedInt32Array to a regular Array to use .shuffle()
	var connected_players_shuffled: Array = Array(connected_players_list)
	
	# 1. Choose a random player to be the Leader.
	connected_players_shuffled.shuffle()
	var leader_peer_id = connected_players_shuffled.pop_front()
	
	# Store the Leader's ID in the special roles dictionary.
	special_roles["Leader"] = leader_peer_id
	Global.leader_id = leader_peer_id
	
	print("Leader chosen:", leader_peer_id)
	
	# 2. Build the role pool for the remaining players.
	var role_pool: Array = []
	for role in Global.role_counts.keys():
		for i in range(Global.role_counts[role]):
			role_pool.append(role)
	
	role_pool.shuffle()
	
	# Assign the Leader role.
	Global.player_roles.clear()
	Global.player_roles[leader_peer_id] = "Leader"
	
	# Assign other roles to the remaining players.
	for id in connected_players_shuffled:
		var role = role_pool.pop_front() if role_pool.size() > 0 else "Crewmate"
		Global.player_roles[id] = role
	
	# 3. Propagate roles to all players.
	# We now send a single RPC call with the entire roles dictionary.
	rpc("sync_player_roles", Global.player_roles)

# RPC to sync roles to all clients.
@rpc("any_peer", "reliable", "call_local")
func sync_player_roles(roles_dict: Dictionary):
	Global.player_roles = roles_dict
	
	# The `player_role` variable should be set for the local player.
	if Global.player_roles.has(multiplayer.get_unique_id()):
		Global.player_role = Global.player_roles[multiplayer.get_unique_id()]
	
	# Update the local player's scene with the new role.
	var player_node = get_player_by_id(multiplayer.get_unique_id())
	if player_node:
		player_node.set_role(Global.player_role)
	
	# Propagate Leader ID to all players.
	# We can get this from the `roles_dict` now
	for id in roles_dict:
		if roles_dict[id] == "Leader":
			Global.leader_id = id
			break
			
	# Update all player nodes' role visibility
	for node in get_tree().get_nodes_in_group("players"):
		node.update_role_visibility()


func get_player_by_id(id: int) -> Node:
	for player in get_tree().get_nodes_in_group("players"):
		if player.get_multiplayer_authority() == id:
			return player
	return null

# The following functions are no longer needed because their logic has been
# integrated into the main `assign_roles` and `sync_player_roles` functions.
# They are commented out to avoid errors.

# func assign_leader():
#     if not multiplayer.is_server():
#         return

#     var all_players = player_roles.keys()
#     if all_players.size() == 0:
#         return

#     var random_player = all_players[randi() % all_players.size()]

#     player_roles[random_player] = "Leader"
#     special_roles["Leader"] = random_player

#     print("Leader chosen:", random_player)

#     var player_node = get_player_by_id(random_player)
#     if player_node:
#         player_node.rpc_id(random_player, "set_role", "Leader")

# @rpc("authority", "call_local", "reliable")
# func set_leader(peer_id: int):
#     special_roles["Leader"] = peer_id
#     var player_node = get_player_by_id(peer_id)
#     if player_node:
#         player_node.set_leader_local()
