extends Node

@onready var timer_label: Label = $UI/MarginContainer/TimerLabel
@onready var cards_label: Label = $UI/UI_Player/CardsCollectedLabel
@onready var turn_timer: Timer = $TurnTimer

# Player spawn point
@onready var player_spawn_points_parent = $SpawnPoints
var player_spawn_points: Array = []

# Card spawn point
@onready var card_spawn_points_parent = $CardSpawnPoints
var card_spawn_points: Array = []
var max_cards_to_collect := 0

# spectator
var spectator_delay := 1.2
var spectator_target_id: int = -1
var retry_timer := 0.0
var spectator_ready := false

# 3 minutes per turn
var turn_duration := 60
var time_left := 0

# Load card scene
var card_scene = preload("res://Scenes/Cards.tscn")

# track readiness
var ready_clients: Array = []

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
    
    print("--- Debug: the_core.gd _ready() ---")
    print("Global.the_mission_team: ", Global.the_mission_team)
    print("Global.no_mission_team: ", Global.no_mission_team)
    print("Local Player ID: ", my_id)
    print("-----------------------------------")

    # ให้ client แจ้ง server ว่าพร้อมแล้ว
    if not multiplayer.is_server():
        rpc_id(1, "notify_ready", my_id)

    # UI setup
    if Global.the_mission_team.has(my_id):
        get_node("UI/UI_Spectator").visible = false
        get_node("UI/UI_Player").visible = true
    else:
        get_node("UI/UI_Player").visible = false
        get_node("UI/UI_Spectator").visible = true
        become_spectator()
    

# --------------------- Multiplayer readiness ------------------------

@rpc("any_peer")
func notify_ready(peer_id: int):
    if not ready_clients.has(peer_id):
        ready_clients.append(peer_id)
    print("Client ready:", peer_id, " total:", ready_clients.size())

    # ถ้า client ทุกคนใน mission team พร้อมแล้ว -> spawn
    if multiplayer.is_server():
        var all_ready := true
        for player_id in Global.the_mission_team:
            if not ready_clients.has(player_id):
                all_ready = false
                break
        
        if all_ready:
            print("All clients ready, spawning mission players")
            for player_id in Global.the_mission_team:
                spawn_player(player_id)
            

# --------------------- Spectator ------------------------

func become_spectator():
    print("--- Debug: become_spectator() ---")
    if Global.the_mission_team.is_empty():
        return

    spectator_target_id = Global.the_mission_team.pick_random()
    spectator_ready = false
    var spectator_cam = $SpectatorCamera
    spectator_cam.current = true

    spectator_cam.position = Vector3(0, 15, -15)
    spectator_cam.look_at(Vector3.ZERO, Vector3.UP)
    print("Spectator will follow player:", spectator_target_id, " after delay")

    var delay_timer = get_tree().create_timer(spectator_delay)
    delay_timer.timeout.connect(func():
        spectator_ready = true
        retry_timer = 3.0
        print("Spectator is now following player:", spectator_target_id)
    )

func _process(delta):
    if spectator_target_id == -1 or not spectator_ready:
        return

    var spectator_cam = $SpectatorCamera
    var target_node = get_node_or_null("Player_" + str(spectator_target_id))

    if target_node:
        var target_pos = target_node.global_position
        spectator_cam.position = target_pos + Vector3(0, 3, -5)
        spectator_cam.look_at(target_pos, Vector3.UP)
    else:
        retry_timer -= delta
        if retry_timer <= 0:
            if not Global.the_mission_team.is_empty():
                spectator_target_id = Global.the_mission_team.pick_random()
                spectator_ready = false
                print("Retry: Switching spectator to player", spectator_target_id)

                var delay_timer = get_tree().create_timer(spectator_delay)
                delay_timer.timeout.connect(func():
                    spectator_ready = true
                    retry_timer = 3.0
                    print("Spectator is now following player:", spectator_target_id)
                )

# --------------------- Multiplayer ------------------------

func _on_peer_connected(id: int):
    if Global.the_mission_team.has(id):
        # ไม่ spawn ทันที -> รอ notify_ready
        pass
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
        return Transform3D(Basis(), Vector3(0,2,0)) # fallback บนพื้น
    var index = player_id % player_spawn_points.size()
    return player_spawn_points[index].transform

func spawn_player(player_id: int):
    if get_node_or_null("Player_" + str(player_id)):
        return
    
    if not Global.the_mission_team.has(player_id):
        print("Player ID ", player_id, " is not on the mission team. Not spawning.")
        return

    var spawn_transform = get_player_spawn_point_transform(player_id)
    var player_scene = preload("res://multiplayerอย่าย้ายไฟล์/player.tscn")
    var player_instance = player_scene.instantiate()

    player_instance.name = "Player_" + str(player_id)
    player_instance.transform = spawn_transform
    player_instance.set_multiplayer_authority(player_id)
    player_instance.scale = Vector3(0.3, 0.3, 0.3)

    add_child(player_instance, true)

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

func update_all_player_properties():
    if Global.player_colors.is_empty() and Global.player_names.is_empty():
        return

    for node in get_tree().get_nodes_in_group("players"):
        var player_id = str(node.name).split("_")[1].to_int()
        
        if Global.player_colors.has(player_id):
            node.set_player_color.rpc(Global.player_colors[player_id])
        if Global.player_names.has(player_id):
            node.set_player_name.rpc(Global.player_names[player_id])


# --------------------- Timer ------------------------

func start_turn_timer():
    if not multiplayer.is_server():
        return

    time_left = turn_duration
    timer_label.visible = true
    update_timer_label(time_left)

    turn_timer.wait_time = 1.0
    turn_timer.one_shot = false
    turn_timer.start()

func _on_TurnTimer_timeout():
    if multiplayer.is_server():
        time_left -= 1
        if time_left < 0:
            turn_timer.stop()
            rpc("go_to_Round_results")
        else:
            rpc("update_timer_label", time_left)

@rpc("any_peer", "call_local")
func update_timer_label(new_time: int):
    time_left = new_time
    timer_label.visible = true
    var minutes = int(time_left / 60)
    var seconds = int(time_left % 60)
    timer_label.text = "%02d:%02d" % [minutes, seconds]

@rpc("any_peer", "reliable", "call_local")
func go_to_Round_results():
    turn_timer.stop()
    get_tree().change_scene_to_file("res://Scenes/Round_results.tscn")
