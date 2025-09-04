extends Node

@onready var main_menu = $CanvasLayer/MainMenu
@onready var address_entry = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/AddressEntry
@onready var hud = $CanvasLayer/HUD
@onready var Idroom_label = $CanvasLayer/HUD/IDROOM/Idroom_label
@onready var status = $CanvasLayer/HUD/Status
@onready var player_count_label = $CanvasLayer/HUD/player_count_label
@onready var playerlist_label = $"CanvasLayer/HUD/Playerlist/player id"
@onready var start_button = $CanvasLayer/HUD/StartButton # Add start button reference

const Player = preload("res://multiplayerอย่าย้ายไฟล์/player.tscn")
const PORT = 9999
var enet_peer = ENetMultiplayerPeer.new()
const MAX_PLAYERS = 10 
var room_code: int = 0   # Store the room code to broadcast
var connected_players: Array = []
var host_id: int = 0  # To track the current host

func _ready():
    multiplayer.peer_connected.connect(add_player)
    multiplayer.peer_disconnected.connect(remove_player)
    multiplayer.server_disconnected.connect(server_disconnected)
    multiplayer.connection_failed.connect(connection_failed)
    multiplayer.connected_to_server.connect(connected_to_server)

func _process(delta):
    # Hide the button for clients
    start_button.visible = multiplayer.is_server()
    if multiplayer.is_server():
        # Only enable the button if there is more than 1 player
        start_button.disabled = connected_players.size() <= 1

func _unhandled_input(event):
    if Input.is_action_just_pressed("quit"):
        get_tree().quit()

func _on_host_button_pressed():
    main_menu.hide()
    status.text = "Attempting to host..."
    
    enet_peer.create_server(PORT)
    multiplayer.multiplayer_peer = enet_peer
    
    var upnp_result = upnp_setup()
    if upnp_result:
        room_code = ip_to_code(upnp_result)
        Idroom_label.text = "ID ROOM : " + str(room_code)
        print("IP : " + upnp_result)
        print("ID ROOM : " + str(room_code))
        status.text = "Success! Your game is ready to host!"
    else:
        Idroom_label.text = "ID ROOM : Failed to get external IP"
        status.text = "Warning: Failed to set up UPNP. Players can only join from the same network."
    
    host_id = multiplayer.get_unique_id()
    add_player(host_id)
    hud.show()
    start_button.show() # Show the button when a host is created

func _on_join_button_pressed():
    main_menu.hide()
    status.text = "Attempting to join..."
    
    var ip_address = code_to_ip(address_entry.text)
    enet_peer.create_client(ip_address, PORT)
    multiplayer.multiplayer_peer = enet_peer
    start_button.hide() # Hide the button for clients

func add_player(peer_id):
    if connected_players.has(peer_id):
        return
    
    if connected_players.size() >= MAX_PLAYERS:
        print("Room is full.")
        # If the room is full, you might want to disconnect the new peer.
        enet_peer.disconnect_peer(peer_id, true)
        return

    connected_players.append(peer_id)

    var player = Player.instantiate()
    player.name = str(peer_id)
    add_child(player)

    update_player_ui()

    if multiplayer.is_server():
        sync_player_list.rpc(connected_players)
        set_room_code.rpc_id(peer_id, room_code)
        set_host_id.rpc(host_id)


func remove_player(peer_id):
    connected_players.erase(peer_id)
    var player = get_node_or_null(str(peer_id))
    if player:
        player.queue_free()

    # Check if the disconnected peer was the host
    if peer_id == host_id:
        print("Host has left, initiating host migration...")
        
        if connected_players.size() > 0:
            var new_host_id = connected_players.min() # Select the new host (e.g., the one with the lowest ID)
            set_host_id.rpc(new_host_id) # Announce the new host to all players

            # If this player is the new host, take over the server role
            if multiplayer.get_unique_id() == new_host_id:
                print("I am the new host!")
                multiplayer.multiplayer_peer = enet_peer
                multiplayer.multiplayer_peer.create_server(PORT)
                host_id = new_host_id
                
                # Re-sync all players
                sync_player_list.rpc(connected_players)

        else:
            print("No players left, closing server.")
            reset_game()
    else:
        update_player_ui()
        if multiplayer.is_server():
            sync_player_list.rpc(connected_players)

# Handles the server's disconnection.
func server_disconnected():
    status.text = "Disconnected from server."
    reset_game()

# Handles client's connection failure.
func connection_failed():
    status.text = "Connection failed. Please check the address or try again."
    main_menu.show() 
    hud.hide() 

# Handles a successful client connection.
func connected_to_server():
    status.text = "Connected to server!"
    hud.show()

func reset_game():
    get_tree().change_scene_to_file("res://world.tscn")

func update_player_ui():
    player_count_label.text = str(connected_players.size()) + "/" + str(MAX_PLAYERS)

    var names_text = ""
    for pid in connected_players:
        names_text += "Player " + str(pid) + "\n"
    playerlist_label.text = names_text
    
# Called when the start button is pressed
func _on_start_button_pressed():
    print("Host is starting the game.")
    start_game.rpc() # Calls the RPC function on all peers

# ----------------- RPC -----------------
@rpc("authority", "reliable")
func set_room_code(code: int):
    room_code = code
    Idroom_label.text = "ID ROOM : " + str(code)

@rpc("any_peer", "reliable")
func sync_player_list(players: Array):
    connected_players = players
    update_player_ui()
    # Also update player authority based on the new host
    for player_node in get_tree().get_nodes_in_group("players"):
        player_node.set_multiplayer_authority(player_node.name.to_int())

@rpc("any_peer", "reliable")
func set_host_id(new_host_id: int):
    host_id = new_host_id

@rpc("any_peer", "reliable")
func start_game():
    get_tree().change_scene_to_file("res://game.tscn")


# ----------------- UPNP -----------------
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

# ----------------- IP ↔ Code -----------------
func ip_to_code(ip_string):
    var parts = ip_string.split(".")
    if parts.size() != 4:
        return 0
    var ip_code = 0.0
    for i in range(4):
        ip_code += int(parts[i]) * pow(256, 3 - i)
    return int(ip_code)

func code_to_ip(ip_code_string):
    var ip_code = int(ip_code_string)
    var ip_parts = []
    for i in range(4):
        var part = ip_code / pow(256, 3 - i)
        ip_parts.append(str(int(part)))
        ip_code -= int(part) * pow(256, 3 - i)
    return ".".join(ip_parts)


func _on_multiplayer_spawner_spawned(node: Node) -> void:
    pass # Replace with function body.
