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
            else:
                # ⭐ NEW: ส่งสัญญาณให้ client ทุกคนรู้ว่าเริ่มรอบใหม่แล้ว
                sync_game_start()
            
            # ⭐ NEW: ส่งหมายเลขรอบเกมไปให้ผู้เล่นทุกคน
            rpc("sync_round_number", Global.round_number)

@rpc("any_peer", "reliable", "call_local")
func sync_round_number(number: int):
    Global.round_number = number
    
    var game_node = get_tree().get_current_scene()
    if game_node and game_node.has_method("update_round_label"):
        game_node.update_round_label()

# ⭐ NEW: RPC เพื่อซิงค์การเริ่มต้นเกม
@rpc("any_peer", "reliable", "call_local")
func sync_game_start():
    # ใช้ฟังก์ชันนี้เพื่อซิงค์การ์ดและ UI ที่จำเป็นเมื่อเริ่มรอบใหม่
    var game_node = get_tree().get_current_scene()
    if is_instance_valid(game_node) and game_node.is_in_group("game_scene"):
        game_node.spawn_cards()
        game_node.start_turn_timer()

func on_role_reveal_finished():
    if multiplayer.is_server():
        print("Role reveal finished. Starting game timer...")
        var game_node = get_tree().get_current_scene()
        if game_node.has_method("start_turn_timer"):
            game_node.start_turn_timer()

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

@rpc("any_peer", "reliable", "call_local")
func check_game_end_condition(is_success: bool):
    if not multiplayer.is_server():
        return
        
    var final_message: String = ""
    var local_player_id = multiplayer.get_unique_id()
    
    # กำหนดกลุ่มบทบาท
    var awakened_roles = ["Data Retriever", "Support", "The Oracle", "Hacker"]
    var entity_roles = ["Tracer", "Enforcer", "System Controller"]
    
    # ตรวจสอบบทบาทของผู้เล่นที่เรียกใช้
    var player_role = Global.player_roles.get(local_player_id).get("base")
    
    # ⭐ NEW: ตรวจสอบเงื่อนไขการจบเกม
    if Global.mission_wins >= 3:
        if player_role in awakened_roles:
            final_message = "The matrix is broken, you guys have won."
        elif player_role in entity_roles:
            final_message = "The matrix is broken, you are dead."
        
        rpc("end_game_with_message", final_message)
        
    elif Global.mission_losses >= 3:
        if player_role in awakened_roles:
            final_message = "Mission failed, you are now being controlled by the Entities."
        elif player_role in entity_roles:
            final_message = "You win, the Awakened's are now under your control."
            
        rpc("end_game_with_message", final_message)
    
    else:
        # ถ้าเกมยังไม่จบ ให้ดำเนินการต่อ
        start_game()

@rpc("any_peer", "reliable", "call_local")
func end_game_with_message(message: String):
    # เปลี่ยนฉากไปที่ฉากแสดงผลลัพธ์สุดท้าย
    var game_scene = get_tree().get_current_scene()
    if is_instance_valid(game_scene) and game_scene.has_method("end_game_final"):
        game_scene.end_game_final(message)
    else:
        # ถ้าอยู่ในฉากอื่น ให้เปลี่ยนฉากและส่งข้อมูล
        var final_scene = load("res://Scenes/round results.tscn").instantiate()
        get_tree().get_root().add_child(final_scene)
        
        # ค้นหาและตั้งค่า Label
        var label_node = final_scene.get_node_or_null("Label")
        if label_node:
            label_node.text = message
            
        get_tree().current_scene.queue_free()
