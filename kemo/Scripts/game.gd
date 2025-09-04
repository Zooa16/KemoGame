# game.gd
extends Node

# Player spawn point
@onready var spawn_points_parent = $SpawnPoints
var spawn_points: Array = []

func _ready():
    for child in spawn_points_parent.get_children():
        if child is Marker3D:
            spawn_points.append(child)

    if multiplayer.is_server():
        multiplayer.peer_connected.connect(_on_peer_connected)
        multiplayer.peer_disconnected.connect(_on_peer_disconnected)

        # spawn ให้ peer ที่เชื่อมต่อแล้ว
        for player_id in multiplayer.get_peers():
            spawn_player(player_id)
        # spawn ของ server เอง
        spawn_player(multiplayer.get_unique_id())

func _on_peer_connected(id: int):
    spawn_player(id)
    # อัปเดตสีและชื่อของผู้เล่นทั้งหมดเมื่อมีคนใหม่เข้ามา
    update_all_player_properties()
    
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
    if not multiplayer.is_server():
        return
    
    var spawn_transform = get_spawn_point_transform(player_id)
    var player_scene = preload("res://multiplayerอย่าย้ายไฟล์/player.tscn")
    var player_instance = player_scene.instantiate()
    
    player_instance.name = "Player_" + str(player_id)
    player_instance.transform = spawn_transform
    player_instance.set_multiplayer_authority(player_id)
    player_instance.scale = Vector3(0.2, 0.2, 0.2)
    
    add_child(player_instance, true)
    
    # ดึงข้อมูลจาก Global มาใช้ทันทีที่สร้าง Player Node
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
