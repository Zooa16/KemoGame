extends Node

@onready var timer_label: Label = $UI/MarginContainer/TimerLabel
@onready var turn_timer: Timer = $TurnTimer
@onready var cards_label: Label = $UI/CardsCollectedLabel

# Player spawn point
@onready var player_spawn_points_parent = $SpawnPoints
var player_spawn_points: Array = []

# Card spawn point
@onready var card_spawn_points_parent = $CardSpawnPoints
var card_spawn_points: Array = []
var max_cards_to_collect := 4

# 3 minutes per turn
var turn_duration := 2
var time_left := 0

# Create an array to hold the numbers of the spawned cards
var spawned_cards_numbers = []

# เปลี่ยน spawned_cards_positions จาก Dictionary เป็น Array
var spawned_cards_positions = []

# Load your single card scene
var card_scene = preload("res://Scenes/Cards.tscn")

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

    spawn_player(multiplayer.get_unique_id())

    if multiplayer.is_server():
        for player_id in multiplayer.get_peers():
            if player_id != multiplayer.get_unique_id():
                spawn_player(player_id)
        generate_random_number_cards()
# ฟังก์ชันใหม่สำหรับแสดงฉากเปิดเผยบทบาท
func show_role_reveal():
    var role_reveal_scene = preload("res://Scenes/role_reveal.tscn").instantiate()
    get_tree().root.add_child(role_reveal_scene)
    
    # ⭐ ตั้งค่าสถานะเพื่อไม่ให้แสดงซ้ำ
    Global.revealed_role = true
    
    var my_id = multiplayer.get_unique_id()
    var my_role = Global.player_roles.get(my_id, {}).get("base", "Unknown")
    var is_leader = Global.player_roles.get(my_id, {}).get("leader", false)
    
    role_reveal_scene.show_role(my_role, is_leader)
    
    # ⭐ เชื่อมต่อสัญญาณเพื่อเริ่มเกมเมื่อแอนิเมชันจบ
    role_reveal_scene.role_reveal_finished.connect(on_role_reveal_finished)

# ฟังก์ชันที่จะถูกเรียกเมื่อฉากเปิดเผยบทบาทเสร็จสิ้น
func on_role_reveal_finished():
    print("Role reveal animation finished. Starting game timer.")
    start_turn_timer()

func _on_peer_connected(id: int):
    spawn_player(id)
    update_all_player_properties()
    
    # ถ้าเป็นโฮสต์และมีไคลเอนต์ใหม่เข้ามา
    if multiplayer.is_server():
        # ส่งข้อมูลการ์ดที่ถูกสร้างไปให้ไคลเอนต์คนใหม่
        if not spawned_cards_numbers.is_empty():
            rpc_id(id, "spawn_cards_with_numbers", spawned_cards_numbers, spawned_cards_positions)

    # Server tells the new player the remaining time
    if multiplayer.is_server():
        rpc_id(id, "update_timer_label", time_left)

func _on_peer_disconnected(id: int):
    # This line looks for the player node and assigns it to a local variable.
    var player = get_node_or_null("Player_" + str(id))
    # This check ensures the code only runs if the player node was found.
    if player:
        # The 'player' variable is now correctly defined and can be used here.
        player.queue_free()
        print("Despawned player with ID: " + str(id))

func get_player_spawn_point_transform(player_id: int) -> Transform3D:
    if player_spawn_points.is_empty():
        return Transform3D.IDENTITY
    
    var index = player_id % player_spawn_points.size()
    return player_spawn_points[index].transform

func spawn_player(player_id: int):
    if get_node_or_null("Player_" + str(player_id)):
        return

    var spawn_transform = get_player_spawn_point_transform(player_id)
    var player_scene = preload("res://multiplayerอย่าย้ายไฟล์/player.tscn")
    var player_instance = player_scene.instantiate()

    player_instance.name = "Player_" + str(player_id)
    
    player_instance.transform = spawn_transform
    player_instance.set_multiplayer_authority(player_id)
    player_instance.scale = Vector3(0.3, 0.3, 0.3)

    add_child(player_instance, true)

    # ⭐ NEW: Connect the signal from the newly spawned player to handle UI updates
    if multiplayer.is_server():
        player_instance.card_collected_updated.connect(Callable(self, "_on_player_card_collected_updated").bind(player_id))

    if Global.player_colors.has(player_id):
        player_instance.set_player_color.rpc(Global.player_colors[player_id])
    if Global.player_names.has(player_id):
        player_instance.set_player_name.rpc(Global.player_names[player_id])

    # ตรวจสอบว่าผู้เล่นคนนี้เป็นผู้เล่นในเครื่องและบทบาทของเขาถูกกำหนดไว้แล้ว
    if Global.player_roles.has(player_id):
        var role = Global.player_roles[player_id]
        player_instance.set_role(role["base"], role["leader"])
        
        # ⭐ ลบโค้ดแสดงบทบาทที่ซ้ำซ้อนออกไป
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

# -------------------------
# TURN SYSTEM
# -------------------------
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
            rpc("go_to_voting_phase")
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
func go_to_voting_phase():
    turn_timer.stop()
    get_tree().change_scene_to_file("res://Scenes/voting.tscn")

 #New and corrected function to allow duplicate cards but at unique locations.
# This function generates unique card numbers and positions.
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

    # ⭐ NEW: Assign the generated numbers to the Global singleton
    Global.spawned_card_numbers = numbers_to_spawn

    # ⭐ NEW: Combine the four numbers into a single 4-digit code and store it in Global
    var four_digit_code = ""
    for num in numbers_to_spawn:
        four_digit_code += str(num)
    Global.four_digit_code = four_digit_code
    print("Combined 4-digit code: ", Global.four_digit_code)

    rpc("spawn_cards_with_numbers", numbers_to_spawn, positions_to_spawn)


# The corrected spawning function
@rpc("any_peer", "call_local")
func spawn_cards_with_numbers(numbers: Array, positions: Array):
    # ⭐ CORRECTED: Clean up any cards from the previous round
    var existing_cards = get_node_or_null("Cards")
    if existing_cards:
        existing_cards.queue_free()
        
    # ⭐ CORRECTED: Instantiate the main parent scene for all cards
    var cards_instance = card_scene.instantiate()
    cards_instance.name = "Cards"
    add_child(cards_instance)
    
    var card_nodes = cards_instance.get_children()
    
    for i in range(numbers.size()):
        var card_number = numbers[i]
        
        # Find the specific card node from our hidden templates
        var card_node = cards_instance.find_child(str(card_number))
        
        if is_instance_valid(card_node):
            card_node.global_transform.origin = positions[i]
            card_node.visible = true


# This function handles the full card collection process on the server.
# This function handles the full card collection process on the server.
@rpc("any_peer")
func process_card_collection(card_path: String, peer_id: int):
    # This function should only run on the server.
    if not multiplayer.is_server():
        return
        
    var player_node = get_node_or_null("Player_" + str(peer_id))
    if not player_node or player_node.collected_cards.size() >= player_node.max_cards_to_collect:
        print("Player has reached card limit or player node not found.")
        return
        
    var card_node = get_node_or_null(card_path)
    if not is_instance_valid(card_node) or card_node.is_collected:
        print("Server: Card not found or already collected.")
        return
    
    # ⭐ CORRECTED: Directly call the hide_card RPC on the card.
    # The card itself will handle hiding from all peers.
    card_node.rpc("hide_card")
    
    # Add the card to the player's inventory on the server.
    player_node.collected_cards.append(card_node.name)
    print("Server: Player ", peer_id, " collected card ", card_node.name)
    
    # Now, tell the specific player's machine to update their UI.
    rpc_id(peer_id, "update_cards_ui_for_peer", player_node.collected_cards.size())


# This function is now the central point for updating UI on all clients.
# It receives a signal from the local Player script.
func _on_player_card_collected_updated(collected_count: int, player_id: int):
    # This function is ONLY called on the server to relay the update.
    # The server will now tell the specific player to update their UI.
    rpc_id(player_id, "update_cards_ui_for_peer", collected_count)

# This is the function that is called on each client to update their own UI.
# This function is now correctly called by the server to update the UI
# for the specific client who needs to see the change.
@rpc("any_peer", "call_local")
func update_cards_ui_for_peer(count: int):
    var cards_label = get_node_or_null("UI/CardsCollectedLabel")
    if not is_instance_valid(cards_label):
        return
    
    if count == 0:
        cards_label.hide()
    else:
        cards_label.show()
    cards_label.text = "%d/%d Cards collected!" % [count, 3]
    
    # ⭐ CORRECTED: The Drop Card button visibility is now handled correctly.
    # We call the function on the local player's node to update the UI.
    var local_player = get_node_or_null("Player_" + str(multiplayer.get_unique_id()))
    if local_player:
        local_player.update_drop_button_visibility()


# Handles the button press on the local client.
# Handles the button press on the local client.


#This function only runs on the server.
# ⭐ NEW: This function handles dropping a single card on the server.
@rpc("any_peer", "reliable")
func drop_single_card_request(player_id: int):
    # This function only runs on the server.
    if not multiplayer.is_server():
        return
        
    var player_node = get_node_or_null("Player_" + str(player_id))
    if not player_node:
        print("Server: Player node not found for ID: ", player_id)
        return
    
    # Check if the player has any cards to drop.
    if player_node.collected_cards.is_empty():
        print("Server: Player has no cards to drop.")
        # Update the UI to reflect an empty inventory
        rpc_id(player_id, "update_cards_ui_for_peer", 0)
        return
        
    # ⭐ CORRECTED: Get the last card from the collected_cards array (LIFO).
    var dropped_card_name = player_node.collected_cards.pop_back()
    
    var player_position = player_node.global_transform.origin
    var player_forward_dir = -player_node.global_transform.basis.z.normalized()
    
    # Determine the spawn point in front of the player.
    var spawn_position = player_position + player_forward_dir * 2.0
    
    # ⭐ CORRECTED: Tell all clients to show this specific card.
    var card_node = get_node_or_null("Cards/" + dropped_card_name)
    if is_instance_valid(card_node):
        card_node.rpc("show_card", spawn_position)
    
    # Update UI for all players to sync the card count.
    var all_peers = multiplayer.get_peers()
    all_peers.append(multiplayer.get_unique_id())
    
    for peer_id in all_peers:
        var p_node = get_node_or_null("Player_" + str(peer_id))
        if p_node:
            rpc_id(peer_id, "update_cards_ui_for_peer", p_node.collected_cards.size())

# This RPC is called on all clients to show the dropped cards.
@rpc("any_peer", "call_local")
func show_dropped_cards_rpc(card_names: Array, positions: Array):
    var cards_parent = get_node("Cards")
    if not is_instance_valid(cards_parent):
        return
        
    for i in range(card_names.size()):
        var card_name = card_names[i]
        var new_position = positions[i]
        var card_node = cards_parent.find_child(card_name)
        
        if is_instance_valid(card_node):
            # The card node handles its own visibility and position via RPC.
            card_node.rpc("show_card", new_position)




func _on_drop_cards_pressed() -> void:
    var local_player_id = multiplayer.get_unique_id() # Get the local player's ID.

    # Check if the local player is the host (peer ID 1).
    if multiplayer.is_server():
        # If the player is the host, call the function directly.
        drop_single_card_request(local_player_id)
    else:
        # If the player is a client, send an RPC to the host (peer ID 1).
        rpc_id(1, "drop_single_card_request", local_player_id)
