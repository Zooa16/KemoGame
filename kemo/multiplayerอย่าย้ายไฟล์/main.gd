extends Node

@onready var main_menu = $CanvasLayer/MainMenu
@onready var address_entry = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/AddressEntry
@onready var hud = $CanvasLayer/HUD
@onready var Idroom_label = $CanvasLayer/HUD/IDROOM/Idroom_label
@onready var status = $CanvasLayer/HUD/Status
@onready var player_count_label = $CanvasLayer/HUD/player_count_label
@onready var playerlist_label = $"CanvasLayer/HUD/Playerlist/player id"
@onready var start_button = $CanvasLayer/HUD/StartButton
@onready var lobby_spawn_points_parent = $SpawnPoints
@onready var copy_button = $CanvasLayer/HUD/CopyButton
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
var player_colors: Dictionary = {} # เพิ่มตัวแปรนี้
var player_names: Dictionary = {} 
const Player = preload("res://multiplayerอย่าย้ายไฟล์/player.tscn")
const PORT := 9999
const MAX_PLAYERS := 10

var enet_peer := ENetMultiplayerPeer.new()
var room_code: int = 0
var connected_players: Array = []
var host_id: int = 0

func _ready():
    multiplayer.peer_connected.connect(add_player)
    multiplayer.peer_disconnected.connect(remove_player)
    multiplayer.server_disconnected.connect(server_disconnected)
    multiplayer.connection_failed.connect(connection_failed)
    multiplayer.connected_to_server.connect(connected_to_server)
    copy_button.pressed.connect(_on_copy_button_pressed)
    
    for child in lobby_spawn_points_parent.get_children():
        if child is Marker3D:
            lobby_spawn_points.append(child)
    # เริ่มต้นซ่อนไว้ก่อน เผื่อเปิดซีนมาถูกฝั่ง client
    start_button.visible = false

func _process(_delta):
    # ปุ่มให้เห็นเฉพาะ host และกดได้เมื่อมีคนมากกว่า 1 คน
    start_button.visible = multiplayer.is_server()
    if multiplayer.is_server():
        start_button.disabled = connected_players.size() <= 1

func _unhandled_input(_event):
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
    start_button.show()

func _on_join_button_pressed():
    main_menu.hide()
    status.text = "Attempting to join..."

    var ip_address = code_to_ip(address_entry.text)
    enet_peer.create_client(ip_address, PORT)
    multiplayer.multiplayer_peer = enet_peer
    start_button.hide()

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
            player_colors[peer_id] = selected_color # เก็บสีของผู้เล่นใหม่
        player_names[peer_id] = "Player " + str(peer_id) # เก็บชื่อของผู้เล่นใหม่
        
        if multiplayer.is_server():
            player_names[peer_id] = "Player " + str(peer_id) # กำหนดชื่อตาม ID ก่อน
    connected_players.append(peer_id)
    var spawn_position = Vector3.ZERO
    

    var player = Player.instantiate()
    player.name = str(peer_id)
    if player.has_method("set_multiplayer_authority"):
        player.set_multiplayer_authority(peer_id)
    if not player.is_in_group("players"):
        player.add_to_group("players")

    # กำหนดตำแหน่งการเกิดใน Lobby
    if lobby_spawn_points.size() > 0:
        var spawn_index = peer_id % lobby_spawn_points.size()
        spawn_position = lobby_spawn_points[spawn_index].global_position
        
    player.scale = Vector3(0.2, 0.2, 0.2)
    add_child(player)
    
    if multiplayer.is_server():
        sync_player_names.rpc(player_names)
    # สุ่มสีให้ผู้เล่น (เฉพาะ Host) และเก็บข้อมูล
    if multiplayer.is_server():
        var available_colors = []
        for c in PLAYER_COLORS:
            if not used_colors.has(c):
                available_colors.append(c)
        
        var selected_color: Color
        if not available_colors.is_empty():
            selected_color = available_colors[randi() % available_colors.size()]
            used_colors[selected_color] = peer_id
            player_colors[peer_id] = selected_color # เก็บสีของผู้เล่นใหม่
            
    # ลบบรรทัดนี้ออก
    # player.rpc_id(peer_id, "set_player_color", selected_color) 

    # เรียกใช้ RPC เพื่อซิงค์ตำแหน่งกับทุกเครื่อง
    set_all_player_positions.rpc(peer_id, spawn_position)

    update_player_ui()

    if multiplayer.is_server():
        sync_player_list.rpc(connected_players)
        # ส่งข้อมูลสีทั้งหมดไปยัง Client ทุกคน
        sync_player_colors.rpc(player_colors) 
        set_room_code.rpc_id(peer_id, room_code)
        set_host_id.rpc(host_id)

func remove_player(peer_id):
    connected_players.erase(peer_id)
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
    hud.hide()

func connected_to_server():
    status.text = "Connected to server!"
    hud.show()

func reset_game():
    get_tree().change_scene_to_file("res://world.tscn")

func update_player_ui():
    player_count_label.text = str(connected_players.size()) + "/" + str(MAX_PLAYERS)
    var names_text := ""
    for pid in connected_players:
        names_text += "Player " + str(pid) + "\n"
    playerlist_label.text = names_text

func _on_start_button_pressed():
    if multiplayer.is_server():
        GameManager.start_game.rpc()  # เรียกผ่าน autoload แทน

func _on_copy_button_pressed():
    DisplayServer.clipboard_set(str(room_code))
    status.text = "รหัสห้องถูกคัดลอกแล้ว!"
# ----------------- RPC -----------------
@rpc("authority", "reliable")
func set_room_code(code: int):
    room_code = code
    Idroom_label.text = "ID ROOM : " + str(code)

@rpc("any_peer", "reliable")
func sync_player_list(players: Array):
    connected_players = players
    update_player_ui()
    for player_node in get_tree().get_nodes_in_group("players"):
        if player_node.has_method("set_multiplayer_authority"):
            player_node.set_multiplayer_authority(int(player_node.name))

@rpc("any_peer", "reliable", "call_local")
func set_host_id(new_host_id: int):
    host_id = new_host_id

@rpc("any_peer", "reliable", "call_local")
func start_game():
    if multiplayer.is_server():
        # บันทึกข้อมูลสีและชื่อลงใน Singleton ก่อนเปลี่ยนฉาก
        Global.player_colors = player_colors
        Global.player_names = player_names
    
    # ให้ทุก peer รวมทั้งผู้เรียกเอง เปลี่ยนฉากไปพร้อมกัน
    get_tree().change_scene_to_file("res://Scenes/game.tscn")
    
@rpc("any_peer", "reliable", "call_local")
func sync_player_colors(colors_dict: Dictionary):
    for player_id in colors_dict:
        var player_node = get_node_or_null(str(player_id))
        if player_node and player_node.has_method("set_player_color"):
            player_node.set_player_color(colors_dict[player_id])

@rpc("any_peer", "reliable")
func set_all_player_positions(player_id: int, new_pos: Vector3):
    var player_node = get_node_or_null(str(player_id))
    if player_node:
        player_node.set_initial_position(new_pos)
        
@rpc("any_peer", "reliable", "call_local")
func sync_player_names(names_dict: Dictionary):
    player_names = names_dict
    for player_id in names_dict:
        var player_node = get_node_or_null(str(player_id))
        if player_node:
            player_node.set_player_name(names_dict[player_id])
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
