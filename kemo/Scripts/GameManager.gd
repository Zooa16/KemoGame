# GameManager.gd
extends Node

var player_roles = {}
var roles := ["Data Retriever", "Support", "The Oracle", "Tracer", "Enforcer", "Hacker", "System Controller"]
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


# ✅ NEW: assign Leader role when voting starts
func assign_leader():
    if not multiplayer.is_server():
        return

    var all_players = player_roles.keys()
    if all_players.size() == 0:
        return

    var random_player = all_players[randi() % all_players.size()]

    # Replace old role with Leader
    player_roles[random_player] = "Leader"
    special_roles["Leader"] = random_player

    print("Leader chosen:", random_player)

    # Tell only that peer that their role changed
    var player_node = get_player_by_id(random_player)
    if player_node:
        player_node.rpc_id(random_player, "set_role", "Leader")

    # (Optional) notify others that this player’s role changed silently
    # e.g., for debugging/logging


@rpc("authority", "call_local", "reliable")
func set_leader(peer_id: int):
    special_roles["Leader"] = peer_id
    var player_node = get_player_by_id(peer_id)
    if player_node:
        player_node.set_leader_local()
