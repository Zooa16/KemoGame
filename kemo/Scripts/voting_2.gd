extends Control

#--------------------------------------------------------------------------------------------------------------#
# ตัวแปรสำหรับกำหนดค่าต่างๆ
#--------------------------------------------------------------------------------------------------------------#

@export var turn_duration := 60
@export var start_delay: float = 2.0
@export var fade_out_duration := 2.0

var time_left := 0

#--------------------------------------------------------------------------------------------------------------#
# การอ้างอิงถึง Node UI (ใช้ @onready เพื่อให้มั่นใจว่า Node ถูกโหลดแล้ว)
#--------------------------------------------------------------------------------------------------------------#

@onready var player_ui_nodes = {
    1: $Player/player1, 2: $Player/player2, 3: $Player/player3,
    4: $Player/player4, 5: $Player/player5, 6: $Player/player6,
    7: $Player/player7, 8: $Player/player8, 9: $Player/player9,
    10: $Player/player10
}
@onready var player_name_labels = {
    1: $Player/player1/player1_name, 2: $Player/player2/player2_name, 3: $Player/player3/player3_name,
    4: $Player/player4/player4_name, 5: $Player/player5/player5_name, 6: $Player/player6/player6_name,
    7: $Player/player7/player7_name, 8: $Player/player8/player8_name, 9: $Player/player9/player9_name,
    10: $Player/player10/player10_name
}
@onready var player_modulate_nodes = {
    1: $Player/player1/Modulate, 2: $Player/player2/Modulate, 3: $Player/player3/Modulate,
    4: $Player/player4/Modulate, 5: $Player/player5/Modulate, 6: $Player/player6/Modulate,
    7: $Player/player7/Modulate, 8: $Player/player8/Modulate, 9: $Player/player9/Modulate,
    10: $Player/player10/Modulate
}

@onready var Agree_icon = {
    1: $Player/player1/Agree_icon, 2: $Player/player2/Agree_icon, 3: $Player/player3/Agree_icon,
    4: $Player/player4/Agree_icon, 5: $Player/player5/Agree_icon, 6: $Player/player6/Agree_icon,
    7: $Player/player7/Agree_icon, 8: $Player/player8/Agree_icon, 9: $Player/player9/Agree_icon,
    10: $Player/player10/Agree_icon
}

@onready var Disagree_icon = {
    1: $Player/player1/Disagree_icon, 2: $Player/player2/Disagree_icon, 3: $Player/player3/Disagree_icon,
    4: $Player/player4/Disagree_icon, 5: $Player/player5/Disagree_icon, 6: $Player/player6/Disagree_icon,
    7: $Player/player7/Disagree_icon, 8: $Player/player8/Disagree_icon, 9: $Player/player9/Disagree_icon,
    10: $Player/player10/Disagree_icon
}

@onready var Leader_icon = {
    1: $Player/player1/Leader_icon, 2: $Player/player2/Leader_icon, 3: $Player/player3/Leader_icon,
    4: $Player/player4/Leader_icon, 5: $Player/player5/Leader_icon, 6: $Player/player6/Leader_icon,
    7: $Player/player7/Leader_icon, 8: $Player/player8/Leader_icon, 9: $Player/player9/Leader_icon,
    10: $Player/player10/Leader_icon
}

@onready var The_Mission_team_ui = {
    1:$"The Mission team/Player1" , 2:$"The Mission team/Player2" , 3:$"The Mission team/Player3" ,
    4:$"The Mission team/Player4" , 5:$"The Mission team/Player5"
}

@onready var playername_The_Mission_team = {
    1:$"The Mission team/Player1/player_name" , 2:$"The Mission team/Player2/player_name" , 3:$"The Mission team/Player3/player_name" ,
    4:$"The Mission team/Player4/player_name" , 5:$"The Mission team/Player5/player_name"
}

@onready var playermodulate_The_Mission_team = {
    1:$"The Mission team/Player1/Modulate" , 2:$"The Mission team/Player2/Modulate" , 3:$"The Mission team/Player3/Modulate" ,
    4:$"The Mission team/Player4/Modulate" , 5:$"The Mission team/Player5/Modulate"
}

@onready var Mission_label = $Mission_label
@onready var Voting_results = $"Vote results"
@onready var turn_timer: Timer = $Timer
@onready var timer_label: Label = $Time

@onready var Select_panel = $Select_panel
@onready var Select_button = $Select_panel/Select
@onready var Cancel_button = $Select_panel/Cancel

@onready var Choose_team_panel =$"Choose a team panel"
@onready var Agree_button = $"Choose a team panel/Agree_button"
@onready var Disagree_button = $"Choose a team panel/Disagree_button"

@onready var proceeding_timer: Timer = $ProceedingTimer
var start_delay_timer: Timer = Timer.new()

#--------------------------------------------------------------------------------------------------------------#
# ตัวแปรสถานะเกม
#--------------------------------------------------------------------------------------------------------------#

var team_votes: Dictionary = {}
var has_voted_on_team := false
var is_leader: bool = false
var mission_size: int = 0
var selected_team_ids: Array = []
var active_players: Array = []
var voting_player_count: int = 0
var player_id_to_ui_index: Dictionary = {}
var selected_player_id_to_add: int = 0
var last_vote_result: int = -1

#--------------------------------------------------------------------------------------------------------------#
# ฟังก์ชันเริ่มต้นและหลัก
#--------------------------------------------------------------------------------------------------------------#

func _ready():
    turn_timer.timeout.connect(_on_Timer_timeout)
    
    is_leader = (Global.leader_id == multiplayer.get_unique_id())
    
    for ui_node in player_ui_nodes.values():
        ui_node.gui_input.connect(func(event):
            if event is InputEventMouseButton and event.pressed:
                if event.button_index == MOUSE_BUTTON_LEFT:
                    var player_id = ui_node.get_meta("player_id")
                    _on_player_ui_pressed(player_id)
        )

    Select_button.pressed.connect(_on_select_button_pressed)
    Cancel_button.pressed.connect(_on_cancel_button_pressed)
    
    Agree_button.pressed.connect(_on_agree_button_pressed)
    Disagree_button.pressed.connect(_on_disagree_button_pressed)
    
    initialize_player_ui()
    Select_panel.visible = false
    Choose_team_panel.visible = false
    Voting_results.visible = false
    for ui in The_Mission_team_ui.values():
        ui.visible = false
    hide_all_vote_icons()
    
    add_child(start_delay_timer)
    start_delay_timer.wait_time = start_delay
    start_delay_timer.one_shot = true
    start_delay_timer.timeout.connect(_on_start_delay_timeout)
    
    proceeding_timer.timeout.connect(_on_proceeding_timer_timeout)

    Mission_label.text = "Loading mission..."
    start_delay_timer.start()

func _process(delta):
    if not proceeding_timer.is_stopped():
        var time_left_seconds = int(proceeding_timer.time_left) + 1
        timer_label.text = "Next scene in %d seconds..." % time_left_seconds
        if time_left_seconds <= 0:
            timer_label.text = "Proceeding..."
    
func _on_start_delay_timeout():
    if multiplayer.is_server():
        start_voting_timer()
        set_mission_size_and_label()
    else:
        rpc_id(1, "request_mission_size")

#--------------------------------------------------------------------------------------------------------------#
# ฟังก์ชันจัดการ UI และสถานะผู้เล่น
#--------------------------------------------------------------------------------------------------------------#

func hide_all_vote_icons():
    for icon in Agree_icon.values():
        icon.visible = false
    for icon in Disagree_icon.values():
        icon.visible = false

func initialize_player_ui():
    # 🌟 แก้ไข: ปรับการคำนวณ voting_player_count ให้ถูกต้อง
    voting_player_count = Global.player_names.size()
    
    # ลบผู้เล่นที่ถูกคัดออกจากการนับจำนวนผู้โหวต
    if Global.eliminated_player_id != -1:
        voting_player_count -= 1
        
    # ลบ Leader ออกจากการนับจำนวนผู้โหวต
    if Global.leader_id != -1:
        # ตรวจสอบว่า Leader ไม่ใช่คนเดียวกับผู้เล่นที่ถูกคัดออก
        if Global.leader_id != Global.eliminated_player_id:
            voting_player_count -= 1
            
    # โค้ดที่เหลือเหมือนเดิม
    for i in range(1, Global.MAX_PLAYERS + 1):
        player_ui_nodes[i].visible = false
        Leader_icon[i].visible = false
        player_ui_nodes[i].disabled = not is_leader
        player_ui_nodes[i].set_meta("player_id", -1)

    var ui_index = 1
    for player_id in Global.player_names:
        player_id_to_ui_index[player_id] = ui_index
        
        player_ui_nodes[ui_index].visible = true
        player_ui_nodes[ui_index].set_meta("player_id", player_id)
        
        player_name_labels[ui_index].text = Global.player_names[player_id]
        
        if player_modulate_nodes.has(ui_index):
            player_modulate_nodes[ui_index].modulate = Global.player_colors[player_id]
        
        if player_id == Global.leader_id:
            Leader_icon[ui_index].visible = true
            
        ui_index += 1
        
func _update_player_ui_visibility():
    for i in range(1, Global.player_names.size() + 1):
        if player_ui_nodes.has(i):
            player_ui_nodes[i].visible = true

#--------------------------------------------------------------------------------------------------------------#
# ฟังก์ชันจัดการการจับเวลาและการโหวตทีม
#--------------------------------------------------------------------------------------------------------------#

func start_voting_timer():
    if not multiplayer.is_server():
        return
    
    time_left = turn_duration
    turn_timer.wait_time = 1.0
    turn_timer.one_shot = false
    turn_timer.start()
    
    rpc("update_timer_label", time_left)

func _on_Timer_timeout():
    if not multiplayer.is_server():
        return
    
    time_left -= 1
    rpc("update_timer_label", time_left)
    
    if time_left <= 0:
        turn_timer.stop()
        if team_votes.size() < voting_player_count:
            rpc("show_final_team_vote_result", 2)
        else:
            calculate_team_vote_result()

@rpc("any_peer", "call_local")
func update_timer_label(new_time: int):
    time_left = new_time
    timer_label.text = str(time_left)
    
    if new_time <= 10:
        timer_label.add_theme_color_override("font_color", Color.RED)
    else:
        timer_label.add_theme_color_override("font_color", Color.WHITE)
    
    if new_time <= 0:
        timer_label.text = "Time's up!"
        Agree_button.visible = false
        Disagree_button.visible = false
        Select_panel.visible = false

func set_mission_size_and_label():
    if not multiplayer.is_server():
        return
    
    var weighted_sizes = [2, 2, 2, 3, 3, 4, 5]
    var chosen_size = weighted_sizes[randi() % weighted_sizes.size()]
    
    Global.mission_size = chosen_size
    print("SERVER: Global.mission_size is set to: ", Global.mission_size)
    rpc("update_mission_label", chosen_size)

@rpc("any_peer", "call_local")
func update_mission_label(size: int):
    print("CLIENT/HOST: update_mission_label called with size: ", size)
    mission_size = size
    if size > 0:
        Mission_label.text = "Need %d people to complete the mission" % size
        _update_team_ui_visibility(size)
    else:
        Mission_label.text = "Mission size not available."
    
@rpc("authority", "call_local")
func request_mission_size():
    if not multiplayer.is_server():
        return
    
    rpc_id(multiplayer.get_rpc_sender_id(), "update_mission_label", Global.mission_size)

func _update_team_ui_visibility(size: int):
    print("CLIENT/HOST: _update_team_ui_visibility called with size: ", size)
    for i in range(1, size + 1):
        if The_Mission_team_ui.has(i):
            The_Mission_team_ui[i].visible = true
            print("CLIENT/HOST: The_Mission_team_ui[", i, "] is set to visible: ", The_Mission_team_ui[i].visible)
    for i in range(size + 1, The_Mission_team_ui.size() + 1):
        if The_Mission_team_ui.has(i):
            The_Mission_team_ui[i].visible = false
            print("CLIENT/HOST: The_Mission_team_ui[", i, "] is set to visible: ", The_Mission_team_ui[i].visible)

func _on_player_ui_pressed(player_id: int):
    # เปลี่ยนฟังก์ชันนี้ให้เป็น async
    _on_player_ui_pressed_async(player_id)
    
func _on_player_ui_pressed_async(player_id: int):
    if not is_leader:
        return
    
    if player_id == Global.eliminated_player_id:
        Select_panel.visible = false
        return

    if selected_team_ids.size() >= mission_size:
        return
    
    Select_panel.visible = false
    
    # 🌟 ใช้ await กับ create_timer()
    await get_tree().create_timer(0.2).timeout
    
    Select_panel.visible = true
    selected_player_id_to_add = player_id

func _on_select_button_pressed():
    if not is_leader:
        return
    if selected_team_ids.size() >= mission_size:
        return

    if selected_team_ids.is_empty():
        Global.the_mission_team.clear()

    if not selected_team_ids.has(selected_player_id_to_add):
        selected_team_ids.append(selected_player_id_to_add)
    
    Select_panel.visible = false
    
    rpc("update_mission_team_ui", selected_team_ids)
    
    if selected_team_ids.size() == mission_size:
        print("HOST: Team selection complete. Team size: %d" % mission_size)
        _disable_all_player_buttons()
        rpc("start_voting_phase")

func _disable_all_player_buttons():
    if not is_leader:
        return
    
    for ui_node in player_ui_nodes.values():
        ui_node.disabled = true

@rpc("any_peer", "call_local")
func start_voting_phase():
    print("CLIENT/HOST: Voting phase started!")
    Select_panel.visible = false
    
    if not is_leader and multiplayer.get_unique_id() != Global.eliminated_player_id:
        Choose_team_panel.visible = true
        Agree_button.visible = true
        Disagree_button.visible = true
        Agree_button.disabled = false
        Disagree_button.disabled = false
    
func _on_cancel_button_pressed():
    if not is_leader:
        return
    
    Select_panel.visible = false
    selected_player_id_to_add = 0

@rpc("any_peer", "call_local")
func update_mission_team_ui(team_ids: Array):
    print("CLIENT/HOST: update_mission_team_ui called with team_ids: ", team_ids)
    var team_ui_index = 1
    for i in The_Mission_team_ui.keys():
        playername_The_Mission_team[i].text = "Empty"
        playermodulate_The_Mission_team[i].modulate = Color.WHITE
    
    for player_id in team_ids:
        if team_ui_index > The_Mission_team_ui.size():
            break
        
        playername_The_Mission_team[team_ui_index].text = Global.player_names.get(player_id, "Unknown")
        
        if playermodulate_The_Mission_team.has(team_ui_index):
            playermodulate_The_Mission_team[team_ui_index].modulate = Global.player_colors.get(player_id, Color.WHITE)
            
        team_ui_index += 1
    
    Global.the_mission_team = team_ids

func _on_agree_button_pressed():
    if multiplayer.get_unique_id() == Global.eliminated_player_id:
        return

    if not has_voted_on_team:
        var my_id = multiplayer.get_unique_id()
        if multiplayer.is_server():
            receive_team_vote(my_id, "agree")
        else:
            rpc_id(1, "receive_team_vote", my_id, "agree")
        has_voted_on_team = true
        _hide_vote_buttons()
        _show_my_vote_icon(my_id, "agree")

func _on_disagree_button_pressed():
    if multiplayer.get_unique_id() == Global.eliminated_player_id:
        return

    if not has_voted_on_team:
        var my_id = multiplayer.get_unique_id()
        if multiplayer.is_server():
            receive_team_vote(my_id, "disagree")
        else:
            rpc_id(1, "receive_team_vote", my_id, "disagree")
        has_voted_on_team = true
        _hide_vote_buttons()
        _show_my_vote_icon(my_id, "disagree")

func _hide_vote_buttons():
    Choose_team_panel.visible = false
    Agree_button.disabled = true
    Disagree_button.disabled = true

func _show_my_vote_icon(player_id: int, vote: String):
    var ui_index = player_id_to_ui_index.get(player_id)
    if ui_index != null:
        rpc("show_vote_icon_rpc", ui_index, vote)

@rpc("any_peer", "call_local")
func show_vote_icon_rpc(ui_index: int, vote: String):
    if Agree_icon.has(ui_index):
        Agree_icon[ui_index].visible = (vote == "agree")
    if Disagree_icon.has(ui_index):
        Disagree_icon[ui_index].visible = (vote == "disagree")

@rpc("any_peer")
func receive_team_vote(voter_id: int, vote: String):
    if not multiplayer.is_server():
        return
    
    if not team_votes.has(voter_id):
        team_votes[voter_id] = vote
        print("SERVER: Received vote from player %d, vote: %s" % [voter_id, vote])
        rpc("show_vote_icon_rpc", player_id_to_ui_index.get(voter_id), vote)

    if team_votes.size() == voting_player_count:
        turn_timer.stop()
        calculate_team_vote_result()

func calculate_team_vote_result():
    if not multiplayer.is_server():
        return
    
    var agree_count = 0
    var disagree_count = 0
    
    for vote in team_votes.values():
        if vote == "agree":
            agree_count += 1
        else:
            disagree_count += 1

    var is_team_accepted = agree_count > disagree_count
    
    if is_team_accepted:
        rpc("show_final_team_vote_result", 1)
    else:
        rpc("show_final_team_vote_result", 0)
    
@rpc("any_peer", "call_local")
func show_final_team_vote_result(result: int):
    last_vote_result = result
    
    Choose_team_panel.visible = false
    Mission_label.visible = false
    
    _update_player_ui_visibility()
    
    hide_all_vote_icons()

    Voting_results.visible = true
    if result == 1:
        Voting_results.modulate = Color.SEA_GREEN
        Voting_results.text = "This team was chosen 
to go on a mission!"
    elif result == 0:
        Voting_results.modulate = Color.RED
        Voting_results.text = "The team was rejected.
 Try again."
    elif result == 2:
        Voting_results.modulate = Color.ORANGE
        Voting_results.text = "Time's up! 
A team has been
 randomly selected!"
    
    proceeding_timer.wait_time = 5.0
    proceeding_timer.one_shot = true
    proceeding_timer.start()

#--------------------------------------------------------------------------------------------------------------#
# ฟังก์ชันจัดการการเปลี่ยนฉากและการรีเซ็ตเกม
#--------------------------------------------------------------------------------------------------------------#

func _on_proceeding_timer_timeout():
    if not multiplayer.is_server():
        return
    
    if last_vote_result == 1:
        rpc("change_scene_based_on_role", true)
    elif last_vote_result == 0:
        rpc("change_scene_based_on_role", false)
    elif last_vote_result == 2:
        random_select_mission_team()

func random_select_mission_team():
    if not multiplayer.is_server():
        return
    
    var available_players = []
    for player_id in Global.player_names:
        if player_id != Global.eliminated_player_id:
            available_players.append(player_id)
        
    available_players.shuffle()
    
    var selected_random_team = available_players.slice(0, Global.mission_size)
    
    Global.the_mission_team = selected_random_team
    rpc("update_mission_team_ui", selected_random_team)
    
    rpc("change_scene_based_on_role", true)
    
@rpc("any_peer", "reliable", "call_local")
func change_scene_based_on_role(is_team_accepted: bool):
    print("CLIENT/HOST: change_scene_based_on_role called. is_team_accepted: ", is_team_accepted)
    var tree = get_tree()
    if tree:
        var tween = tree.create_tween()
        if tween:
            tween.tween_property(self, "modulate", Color(0, 0, 0, 1), fade_out_duration)
            await tween.finished
    
    if is_team_accepted:
        if Global.the_mission_team.has(multiplayer.get_unique_id()):
            print("CLIENT/HOST: เป็นสมาชิกทีมภารกิจ: เปลี่ยนไป the_core.tscn")
            get_tree().change_scene_to_file("res://Scenes/the_core.tscn")
        else:
            print("CLIENT/HOST: ไม่ได้เป็นสมาชิกทีมภารกิจ: เปลี่ยนไป game.tscn")
            get_tree().change_scene_to_file("res://Scenes/game.tscn")
    else:
        print("CLIENT/HOST: ทีมถูกโหวตไม่ผ่าน: รีเซ็ตขั้นตอนการเลือกทีม")
        var tree_reset = get_tree()
        if tree_reset:
            var tween_reset = tree_reset.create_tween()
            if tween_reset:
                tween_reset.tween_property(self, "modulate", Color(1, 1, 1, 1), fade_out_duration)
        rpc("reset_team_selection")

@rpc("any_peer", "reliable", "call_local")
func reset_team_selection():
    print("CLIENT/HOST: reset_team_selection called.")
    selected_team_ids.clear()
    team_votes.clear()
    Global.the_mission_team.clear()
    has_voted_on_team = false
    
    Voting_results.visible = false
    Mission_label.visible = true
    timer_label.text = ""
    
    for i in The_Mission_team_ui.keys():
        playername_The_Mission_team[i].text = "Empty"
        playermodulate_The_Mission_team[i].modulate = Color.WHITE
    
    _update_team_ui_visibility(mission_size)
    
    _update_player_ui_visibility()
    
    for ui_node in player_ui_nodes.values():
        if is_leader:
            ui_node.disabled = false
    
    hide_all_vote_icons()
    
    if multiplayer.is_server():
        start_voting_timer()
