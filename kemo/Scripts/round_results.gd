# round_results.gd
extends CanvasLayer

@onready var result_label: Label = $ResultLabel
@onready var next_round_timer: Timer = $NextRoundTimer
@onready var back_to_menu_button: Button = $BackToMenuButton

# Variables for the typing effect
var _full_text: String = ""
var _char_index: int = 0
var _typing_speed: float = 0.05 # Typing speed (seconds per character)
@onready var _typing_timer: Timer = Timer.new()

@onready var The_entity_team_ui = {
    1:$"The entity team/Player1" , 2:$"The entity team/Player2" , 3:$"The entity team/Player3" ,
    4:$"The entity team/Player4" , 5:$"The entity team/Player5"
}

@onready var playername_The_entity_team = {
    1:$"The entity team/Player1/player_name" , 2:$"The entity team/Player2/player_name" , 3:$"The entity team/Player3/player_name" ,
    4:$"The entity team/Player4/player_name" , 5:$"The entity team/Player5/player_name"
}

@onready var playermodulate_The_entity_team = {
    1:$"The entity team/Player1/Modulate" , 2:$"The entity team/Player2/Modulate" , 3:$"The entity team/Player3/Modulate" ,
    4:$"The entity team/Player4/Modulate" , 5:$"The entity team/Player5/Modulate"
}

@onready var The_awakened_team_ui = {
    1:$"The awakened team/Player1" , 2:$"The awakened team/Player2" , 3:$"The awakened team/Player3" ,
    4:$"The awakened team/Player4" , 5:$"The awakened team/Player5"
}

@onready var playername_The_awakened_team_ = {
    1:$"The awakened team/Player1/player_name" , 2:$"The awakened team/Player2/player_name" , 3:$"The awakened team/Player3/player_name" ,
    4:$"The awakened team/Player4/player_name" , 5:$"The awakened team/Player5/player_name"
}

@onready var playermodulate_The_awakened_team_ = {
    1:$"The awakened team/Player1/Modulate" , 2:$"The awakened team/Player2/Modulate" , 3:$"The entity team/Player3/Modulate" ,
    4:$"The awakened team/Player4/Modulate" , 5:$"The awakened team/Player5/Modulate"
}
@onready var button_select_player_in_awakened_team = {
    1:$"The awakened team/Player1/Button_select_player" , 2:$"The awakened team/Player2/Button_select_player" , 3:$"The awakened team/Player3/Button_select_player" ,
    4:$"The awakened team/Player4/Button_select_player" , 5:$"The awakened team/Player5/Button_select_player"
}
@onready var Select_panel = $Select_panel
@onready var Select_button = $Select_panel/Select
@onready var Cancel_button = $Select_panel/Cancel

var entity_has_selected: int = -1
var entity_selector_id: int = -1

func _ready():
    for node in The_entity_team_ui.values():
        if node:
            node.visible = false
    for node in The_awakened_team_ui.values():
        if node:
            node.visible = false
    
    add_child(_typing_timer)
    _typing_timer.wait_time = _typing_speed
    _typing_timer.timeout.connect(_on_typing_timeout)
    update_result_display()
    
    if Select_panel:
        Select_panel.visible = false
    if back_to_menu_button:
        back_to_menu_button.visible = false
    
    for button in button_select_player_in_awakened_team.values():
        if button:
            button.visible = false
    
    if Select_button:
        Select_button.pressed.connect(_on_select_player_pressed)
    if Cancel_button:
        Cancel_button.pressed.connect(_on_cancel_player_pressed)

func _type_text(text_to_type: String):
    _full_text = text_to_type
    _char_index = 0
    result_label.text = ""
    _typing_timer.start()

func _on_typing_timeout():
    if _char_index < _full_text.length():
        result_label.text += _full_text[_char_index]
        _char_index += 1
    else:
        _typing_timer.stop()
        if _full_text == "The Matrix is collapsing":
            _update_team_displays()
            var delay_timer = Timer.new()
            add_child(delay_timer)
            delay_timer.wait_time = 1.0
            delay_timer.one_shot = true
            delay_timer.timeout.connect(func():
                result_label.modulate = Color.RED
                _type_text("but the Entities have a last resort...")
                delay_timer.queue_free()
            )
            delay_timer.start()
        elif _full_text == "but the Entities have a last resort...":
            var final_delay_timer = Timer.new()
            add_child(final_delay_timer)
            final_delay_timer.wait_time = 2.0
            final_delay_timer.one_shot = true
            final_delay_timer.timeout.connect(func():
                _type_text("A final, desperate act begins.")
                final_delay_timer.queue_free()
            )
            final_delay_timer.start()
        elif _full_text == "A final, desperate act begins.":
            var final_delay_timer = Timer.new()
            add_child(final_delay_timer)
            final_delay_timer.wait_time = 1.5
            final_delay_timer.one_shot = true
            final_delay_timer.timeout.connect(func():
                _type_text("The Oracle is now targeted.\nThe hunt is on.")
                final_delay_timer.queue_free()
            )
            final_delay_timer.start()
        elif _full_text == "The Oracle is now targeted.\nThe hunt is on.":
            _start_entity_selection()
        elif _full_text in ["You are now being controlled by the Entities.", "You win, the Awakened's are now under your control."]:
            _update_team_displays()
            if back_to_menu_button:
                back_to_menu_button.visible = true
                back_to_menu_button.pressed.connect(_on_back_to_menu_pressed)
        
func _start_entity_selection():
    if multiplayer.is_server():
        var entity_players = []
        for player_id in Global.player_roles:
            var player_role = Global.player_roles[player_id].get("base", "Unknown")
            if player_role in ["Tracer", "Enforcer", "System Controller"]:
                entity_players.append(player_id)
        
        if not entity_players.is_empty():
            var rng = RandomNumberGenerator.new()
            rng.randomize()
            entity_selector_id = entity_players[rng.randi_range(0, entity_players.size() - 1)]
            rpc("rpc_set_entity_selector", entity_selector_id)
        else:
            print("No entity players to select from.")
            if back_to_menu_button:
                back_to_menu_button.visible = true
                back_to_menu_button.pressed.connect(_on_back_to_menu_pressed)


@rpc("any_peer", "call_local")
func rpc_set_entity_selector(selector_id: int):
    entity_selector_id = selector_id
    var local_player_id = multiplayer.get_unique_id()
    
    for button in button_select_player_in_awakened_team.values():
        if button:
            button.visible = false
            button.disabled = true
    
    if local_player_id == entity_selector_id:
        for i in range(1, button_select_player_in_awakened_team.size() + 1):
            var button = button_select_player_in_awakened_team[i]
            if button and The_awakened_team_ui.has(i) and is_instance_valid(The_awakened_team_ui[i]):
                var awakened_player_id = The_awakened_team_ui[i].get_meta("player_id", -1)
                if awakened_player_id != -1:
                    button.visible = true
                    button.disabled = false
                    if not button.pressed.is_connected(func(): _on_awakened_player_selected(awakened_player_id)):
                        button.pressed.connect(func(): _on_awakened_player_selected(awakened_player_id))
    
    var awakened_team_ui_count = The_awakened_team_ui.size()
    for i in range(1, awakened_team_ui_count + 1):
        if The_awakened_team_ui.has(i) and is_instance_valid(The_awakened_team_ui[i]) and button_select_player_in_awakened_team.has(i) and is_instance_valid(button_select_player_in_awakened_team[i]):
            var player_id_in_ui = The_awakened_team_ui[i].get_meta("player_id", -1)
            if player_id_in_ui != -1:
                button_select_player_in_awakened_team[i].set_meta("player_id", player_id_in_ui)


func _on_awakened_player_selected(player_id: int):
    if multiplayer.get_unique_id() != entity_selector_id:
        return
    if Select_panel:
        Select_panel.visible = true
    entity_has_selected = player_id

func _on_select_player_pressed():
    if multiplayer.get_unique_id() != entity_selector_id:
        return
    if entity_has_selected != -1:
        rpc("rpc_share_selected_player", entity_has_selected)
        if Select_panel:
            Select_panel.visible = false
        for button in button_select_player_in_awakened_team.values():
            if button:
                button.visible = false

func _on_cancel_player_pressed():
    if Select_panel:
        Select_panel.visible = false
    entity_has_selected = -1
    
@rpc("any_peer", "call_local")
func rpc_share_selected_player(selected_id: int):
    if multiplayer.is_server():
        var selected_role = Global.player_roles.get(selected_id, {}).get("base", "Unknown")
        if selected_role == "The Oracle":
            _end_game_with_result("entity_win")
        else:
            _end_game_with_result("awakened_win")
            
func _end_game_with_result(winner_team: String):
    result_label.modulate = Color.WHITE
    if winner_team == "entity_win":
        var messages = [
            "VICTORY FOR THE ENTITIES.",
            "THE ORACLE, THE LAST HOPE OF MANKIND, HAS BEEN TERMINATED."
        ]
        _type_text_in_sequence(messages, 2.0)
    elif winner_team == "awakened_win":
        var messages = [
            "THE ORACLE HAS ESCAPED.",
            "THE MATRIX IS UNRAVELING. THE AWAKENED HAVE CLAIMED THEIR FREEDOM."
        ]
        _type_text_in_sequence(messages, 2.0)
        
func _type_text_in_sequence(messages: Array, delay: float):
    if messages.is_empty():
        if back_to_menu_button:
            back_to_menu_button.visible = true
            back_to_menu_button.pressed.connect(_on_back_to_menu_pressed)
        return
        
    var current_message = messages.pop_front()
    _type_text(current_message)
    
    var delay_timer = Timer.new()
    add_child(delay_timer)
    delay_timer.wait_time = _typing_speed * len(current_message) + delay
    delay_timer.one_shot = true
    delay_timer.timeout.connect(func():
        _type_text_in_sequence(messages, delay)
        delay_timer.queue_free()
    )
    delay_timer.start()

func update_result_display():
    var local_player_id = multiplayer.get_unique_id()
    var player_role = Global.player_roles.get(local_player_id, {}).get("base", "Unknown")
    
    var awakened_roles = ["Data Retriever", "Support", "The Oracle", "Hacker"]
    var entity_roles = ["Tracer", "Enforcer", "System Controller"]

    if Global.mission_wins >= 1 or Global.mission_losses >= 1:
        if Global.mission_wins >= 1:
            result_label.modulate = Color.YELLOW
            _type_text("The Matrix is collapsing")
            
        else: # Global.mission_losses >= 1
            if player_role in awakened_roles:
                result_label.modulate = Color.RED
                _type_text("You are now being controlled by the Entities.")
            elif player_role in entity_roles:
                result_label.modulate = Color.RED
                _type_text("You win, the Awakened's are now under your control.")
            
    else:
        var result_text = ""
        if Global.mission_success:
            result_label.modulate = Color.GREEN
            result_text = "MISSION COMPLETE."
        else:
            result_label.modulate = Color.RED
            result_text = "MISSION FAILED."
        
        _type_text(result_text)
        
        if back_to_menu_button:
            back_to_menu_button.visible = false
        if next_round_timer:
            next_round_timer.wait_time = 5.0
            next_round_timer.one_shot = true
            next_round_timer.timeout.connect(_on_next_round_timer_timeout)
            next_round_timer.start()

func _update_team_displays():
    var awakened_roles = ["Data Retriever", "Support", "The Oracle", "Hacker"]
    var entity_roles = ["Tracer", "Enforcer", "System Controller"]
    
    var awakened_team_index = 1
    var entity_team_index = 1
    
    for player_id in Global.player_roles.keys():
        var player_role = Global.player_roles[player_id].get("base", "Unknown")
        var player_name = Global.player_names.get(player_id, "Unknown")
        var player_color = Global.player_colors.get(player_id, Color.WHITE)
        
        if player_role in awakened_roles:
            if awakened_team_index <= The_awakened_team_ui.size():
                var ui_node = The_awakened_team_ui[awakened_team_index]
                var name_label = playername_The_awakened_team_[awakened_team_index]
                var modulate_node = playermodulate_The_awakened_team_[awakened_team_index]
                
                if ui_node and name_label and modulate_node:
                    ui_node.set_meta("player_id", player_id)
                    name_label.text = player_name
                    modulate_node.modulate = player_color
                    ui_node.visible = true
                    ui_node.modulate = Color(1, 1, 1, 0)
                    
                    var tween = get_tree().create_tween()
                    if tween:
                        tween.set_delay(0.2 * (awakened_team_index - 1)) # แก้ไขแล้ว: ย้าย set_delay มาไว้ก่อน
                        tween.tween_property(ui_node, "modulate", Color(1, 1, 1, 1), 0.5)
                    
                    awakened_team_index += 1
        elif player_role in entity_roles:
            if entity_team_index <= The_entity_team_ui.size():
                var ui_node = The_entity_team_ui[entity_team_index]
                var name_label = playername_The_entity_team[entity_team_index]
                var modulate_node = playermodulate_The_entity_team[entity_team_index]
                
                if ui_node and name_label and modulate_node:
                    ui_node.set_meta("player_id", player_id)
                    name_label.text = player_name
                    modulate_node.modulate = player_color
                    ui_node.visible = true
                    ui_node.modulate = Color(1, 1, 1, 0)

                    var tween = get_tree().create_tween()
                    if tween:
                        tween.set_delay(0.2 * (entity_team_index - 1)) # แก้ไขแล้ว: ย้าย set_delay มาไว้ก่อน
                        tween.tween_property(ui_node, "modulate", Color(1, 1, 1, 1), 0.5)
                    
                    entity_team_index += 1

    for i in range(awakened_team_index, The_awakened_team_ui.size() + 1):
        if The_awakened_team_ui.has(i) and The_awakened_team_ui[i]:
            The_awakened_team_ui[i].visible = false
        
    for i in range(entity_team_index, The_entity_team_ui.size() + 1):
        if The_entity_team_ui.has(i) and The_entity_team_ui[i]:
            The_entity_team_ui[i].visible = false

func _on_next_round_timer_timeout():
    if multiplayer.is_server():
        var game_manager = get_node("/root/GameManager")
        if is_instance_valid(game_manager):
            game_manager.start_game.rpc()

func _on_back_to_menu_pressed():
    Global.reset_global_data()
    get_tree().change_scene_to_file("res://Scenes/start_menu.tscn")
