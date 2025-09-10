# GameManager.gd
extends Node

var player_roles = {}
var roles := ["Data Retriever", "Support", "The Oracle", "Tracer", "Enforcer", "Hacker", "System Controller"]


@rpc("any_peer", "reliable", "call_local")
func start_game():
	print("Changing scene to game...")
	if get_tree():
		get_tree().change_scene_to_file("res://Scenes/game.tscn")

		if multiplayer.is_server():
			await get_tree().create_timer(1.0).timeout
			assign_roles()

			# 👇 Start the game timer after everyone spawns
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

	var connected_players = multiplayer.get_peers()
	connected_players.append(multiplayer.get_unique_id())

	player_roles.clear()

	# Build role pool based on counts
	var role_pool: Array = []
	for role in Global.role_counts.keys():
		for i in range(Global.role_counts[role]):
			role_pool.append(role)

	role_pool.shuffle()

	for id in connected_players:
		var role = role_pool.pop_front() if role_pool.size() > 0 else "Crewmate"
		player_roles[id] = role

		var player_node = get_player_by_id(id)
		if player_node:
			# 👇 Tell only that peer what their role is
			player_node.rpc_id(id, "set_role", role)

		print("Assigning role", role, "to peer", id)




func get_player_by_id(id: int) -> Node:
	for player in get_tree().get_nodes_in_group("players"):
		if player.get_multiplayer_authority() == id:
			return player
	return null
