extends CanvasLayer

@onready var result_label: Label = $ResultLabel
@onready var next_round_timer: Timer = $NextRoundTimer
@onready var back_to_menu_button: Button = $BackToMenuButton
@onready var _typing_timer: Timer = Timer.new()

# ตัวแปรสำหรับเอฟเฟกต์การพิมพ์
var _full_text: String = ""
var _char_index: int = 0
var _typing_speed: float = 0.05 # ความเร็วในการพิมพ์ (วินาทีต่อตัวอักษร)
var _typing_finished_callback: Callable

# แก้ไข: ย้ายตัวแปร roles มาไว้ที่นี่เพื่อให้เข้าถึงได้จากทุกฟังก์ชัน
var awakened_roles = ["Data Retriever", "Support", "The Oracle", "Hacker"]
var entity_roles = ["Tracer", "Enforcer", "System Controller"]

@onready var The_entity_team_ui = {
	1:$"The entity team/HBoxContainer/Player1" , 2:$"The entity team/HBoxContainer/Player2" , 3:$"The entity team/HBoxContainer/Player3" ,
	4:$"The entity team/HBoxContainer/Player4"
}

@onready var playername_The_entity_team = {
	1:$"The entity team/HBoxContainer/Player1/player_name",
	2:$"The entity team/HBoxContainer/Player2/player_name",
	3:$"The entity team/HBoxContainer/Player3/player_name",
	4:$"The entity team/HBoxContainer/Player4/player_name"
}

@onready var playermodulate_The_entity_team = {
	1:$"The entity team/HBoxContainer/Player1/Modulate",
	2:$"The entity team/HBoxContainer/Player2/Modulate",
	3:$"The entity team/HBoxContainer/Player3/Modulate",
	4:$"The entity team/HBoxContainer/Player4/Modulate"
}

@onready var The_awakened_team_ui = {
	1:$"The awakened team/HBoxContainer/Player1" , 2:$"The awakened team/HBoxContainer/Player2" , 3:$"The awakened team/HBoxContainer/Player3" ,
	4:$"The awakened team/HBoxContainer/Player4" , 5:$"The awakened team/HBoxContainer/Player5" , 6:$"The awakened team/HBoxContainer/Player6"
}

@onready var playername_The_awakened_team_ = {
	1:$"The awakened team/HBoxContainer/Player1/player_name" , 2:$"The awakened team/HBoxContainer/Player2/player_name" , 3:$"The awakened team/HBoxContainer/Player3/player_name" ,
	4:$"The awakened team/HBoxContainer/Player4/player_name" , 5:$"The awakened team/HBoxContainer/Player5/player_name", 6:$"The awakened team/HBoxContainer/Player6/player_name"
}

@onready var playermodulate_The_awakened_team_ = {
	1:$"The awakened team/HBoxContainer/Player1/Modulate" , 2:$"The awakened team/HBoxContainer/Player2/Modulate" , 3:$"The awakened team/HBoxContainer/Player3/Modulate" ,
	4:$"The awakened team/HBoxContainer/Player4/Modulate" , 5:$"The awakened team/HBoxContainer/Player5/Modulate", 6:$"The awakened team/HBoxContainer/Player6/Modulate"
}

# เพิ่มตัวแปรสำหรับ UI การเลือกผู้เล่น
@onready var button_select_player_in_awakened_team = {
	1:$"The awakened team/HBoxContainer/Player1/Button_select_player" , 2:$"The awakened team/HBoxContainer/Player2/Button_select_player" , 3:$"The awakened team/HBoxContainer/Player3/Button_select_player" ,
	4:$"The awakened team/HBoxContainer/Player4/Button_select_player" , 5:$"The awakened team/HBoxContainer/Player5/Button_select_player", 6:$"The awakened team/HBoxContainer/Player6/Button_select_player"
}

var selected_player_id: int = -1

func _ready():
	if multiplayer.is_server():
		print("DEBUG: This is the Host (ID: ", multiplayer.get_unique_id(), ")")
	else:
		print("DEBUG: This is a Client (ID: ", multiplayer.get_unique_id(), ")")

	for node in The_entity_team_ui.values():
		node.visible = false
	for node in The_awakened_team_ui.values():
		node.visible = false
		
	for button in button_select_player_in_awakened_team.values():
		button.visible = false
		
	add_child(_typing_timer)
	_typing_timer.timeout.connect(_on_typing_timeout)
	back_to_menu_button.pressed.connect(_on_back_to_menu_pressed)

	update_result_display()

# ⭐ NEW: ฟังก์ชันสำหรับหน่วงเวลาแล้วเรียกฟังก์ชันอื่น
func _wait_and_call(delay: float, callable: Callable):
	var timer = get_tree().create_timer(delay)
	await timer.timeout
	if callable.is_valid():
		callable.call()

# ฟังก์ชันสำหรับพิมพ์ข้อความทีละตัว
func _start_typing_effect(text: String, color: Color, next_action: Callable = Callable()):
	_full_text = text
	_char_index = 0
	_typing_finished_callback = next_action
	result_label.text = ""
	result_label.modulate = color
	_typing_timer.wait_time = _typing_speed
	_typing_timer.one_shot = false
	_typing_timer.start()

# ฟังก์ชันที่ถูกเรียกเมื่อตัวจับเวลาหมดอายุ
func _on_typing_timeout():
	if _char_index < _full_text.length():
		result_label.text += _full_text[_char_index]
		_char_index += 1
	else:
		_typing_timer.stop()
		if _typing_finished_callback.is_valid():
			_typing_finished_callback.call()

func update_result_display():
	var local_player_id = multiplayer.get_unique_id()
	var player_role = Global.player_roles.get(local_player_id, {}).get("base", "Unknown")
	
	if Global.mission_wins >= 1 or Global.mission_losses >= 1:
		if Global.mission_wins >= 1:
			print("DEBUG: Entered 'The Matrix is collapsing' win condition.")
			back_to_menu_button.visible = false

			_start_typing_effect("The Matrix is collapsing...", Color.YELLOW, Callable(self, "_show_matrix_alert").bind(local_player_id))
			_update_team_displays()
		else: # Global.mission_losses >= 1
			_show_entity_win_sequence()
			_update_team_displays()
			
	else:
		var result_text = ""
		if Global.mission_success:
			result_label.modulate = Color.GREEN
			result_label.text  = "Mission accomplished!" + str(Global.mission_wins) + "/3"
		else:
			result_label.modulate = Color.RED
			result_label.text = "Mission failed...  " + str(Global.mission_losses) + "/3"
		
		back_to_menu_button.visible = false
		next_round_timer.wait_time = 5.0
		next_round_timer.one_shot = true
		next_round_timer.timeout.connect(_on_next_round_timer_timeout)
		next_round_timer.start()

func _show_matrix_alert(local_player_id):
	_start_typing_effect("System Alert: Mainframe compromised.", Color.YELLOW, Callable(self, "_start_oracle_selection").bind(local_player_id))

func _start_oracle_selection(local_player_id):
	if multiplayer.is_server():
		var entity_players = []
		for player_id in Global.player_roles.keys():
			var p_role = Global.player_roles[player_id].get("base", "Unknown")
			if p_role in entity_roles:
				entity_players.append(player_id)
		
		print("DEBUG: Found entity players with IDs: ", entity_players)

		if not entity_players.is_empty():
			var random_entity_id = entity_players[randi() % entity_players.size()]
			print("DEBUG: Randomly selected entity player ID: ", random_entity_id)
			
			rpc("handle_oracle_selection", random_entity_id)
			handle_oracle_selection(random_entity_id)
		else:
			print("DEBUG: No entity players found. Cannot proceed with Oracle elimination.")

func _update_team_displays():
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
				
				name_label.text = player_name
				modulate_node.modulate = player_color
				ui_node.visible = true
				ui_node.modulate = Color(1, 1, 1, 0)
				ui_node.set_meta("player_id", player_id)

				var tween = get_tree().create_tween()
				tween.tween_property(ui_node, "modulate", Color(1, 1, 1, 1), 0.5).set_delay(0.2 * (awakened_team_index - 1))
				
				awakened_team_index += 1
		elif player_role in entity_roles:
			if entity_team_index <= The_entity_team_ui.size():
				var ui_node = The_entity_team_ui[entity_team_index]
				var name_label = playername_The_entity_team[entity_team_index]
				var modulate_node = playermodulate_The_entity_team[entity_team_index]
				
				name_label.text = player_name
				modulate_node.modulate = player_color
				ui_node.visible = true
				ui_node.modulate = Color(1, 1, 1, 0)

				var tween = get_tree().create_tween()
				tween.tween_property(ui_node, "modulate", Color(1, 1, 1, 1), 0.5).set_delay(0.2 * (entity_team_index - 1))
				
				entity_team_index += 1

	for i in range(awakened_team_index, The_awakened_team_ui.size() + 1):
		if The_awakened_team_ui.has(i):
			The_awakened_team_ui[i].visible = false
		
	for i in range(entity_team_index, The_entity_team_ui.size() + 1):
		if The_entity_team_ui.has(i):
			The_entity_team_ui[i].visible = false

@rpc("any_peer")
func handle_oracle_selection(selected_entity_id: int):
	var local_player_id = multiplayer.get_unique_id()
	if local_player_id == selected_entity_id:
		print("DEBUG: I am the selected entity player. Showing selection buttons.")
		show_select_oracle_buttons()
	else:
		print("DEBUG: I am not the selected entity player.")

@rpc("any_peer")
func show_select_oracle_buttons():
	print("DEBUG: RPC show_select_oracle_buttons called on client ID: ", multiplayer.get_unique_id())
	for i in The_awakened_team_ui.keys():
		var ui_node = The_awakened_team_ui[i]
		if ui_node.visible:
			var player_id = ui_node.get_meta("player_id")
			var select_button = button_select_player_in_awakened_team[i]
			
			if not select_button.pressed.is_connected(Callable(self, "_on_player_selected")):
				select_button.pressed.connect(Callable(self, "_on_player_selected").bind(player_id))
			
			select_button.visible = true
			print("DEBUG: Button for player ID ", player_id, " is now visible and connected.")
			
	result_label.text = "Select who you think is The Oracle..."

func _on_player_selected(selected_id: int):
	print("DEBUG: Player selected with ID: ", selected_id)
	
	for btn in button_select_player_in_awakened_team.values():
		btn.visible = false
	print("DEBUG: All selection buttons hidden.")

	rpc_id(1, "check_oracle_role", selected_id)
	print("DEBUG: Sending selected player ID ", selected_id, " to Host (ID 1).")

@rpc("any_peer")
func check_oracle_role(selected_id: int):
	if multiplayer.is_server():
		print("DEBUG: Host received selected player ID: ", selected_id)
		var selected_role = Global.player_roles.get(selected_id, {}).get("base", "Unknown")
		var win_type: String
		
		if selected_role == "The Oracle":
			print("DEBUG: The Oracle was selected. Entities win.")
			win_type = "EntitiesWin"
		else:
			print("DEBUG: The Oracle was not selected. Awakened win.")
			win_type = "AwakenedWin"
		
		# ⭐ แก้ไข: Host ส่งผลลัพธ์ไปยัง Client ทั้งหมด
		rpc("show_final_results", win_type)
		# ⭐ แก้ไข: Host แสดงผลลัพธ์ของตัวเอง
		show_final_results(win_type)
	else:
		# ⭐ NEW DEBUG: ตรวจสอบว่า Client ได้รับ RPC นี้หรือไม่
		print("DEBUG: Client received check_oracle_role RPC, but ignoring as it's not the host.")

# ⭐ เพิ่ม @rpc("any_peer") เพื่อให้สามารถเรียกใช้งานบนทุก Peer ได้
@rpc("any_peer")
func show_final_results(win_type: String):
	print("DEBUG: show_final_results called with win_type: ", win_type, " on player ID: ", multiplayer.get_unique_id())
	back_to_menu_button.visible = true
	next_round_timer.stop()
	
	if win_type == "AwakenedWin":
		_show_awakened_win_sequence()
	elif win_type == "EntitiesWin":
		_show_entity_win_sequence()
	else:
		result_label.text = "Game Over"

# ⭐ NEW: ฟังก์ชันรวมสำหรับแสดงผลลัพธ์ชัยชนะของ Awakened
func _show_awakened_win_sequence():
	print("DEBUG: Starting Awakened win sequence.")
	_start_typing_effect("The penguins are free.", Color.GREEN, Callable(self, "_show_awakened_win_part2"))

func _show_awakened_win_part2():
	print("DEBUG: Showing Awakened win part 2.")
	_wait_and_call(1.5, Callable(self, "_start_typing_effect").bind("You are the architects of the new world.", Color.GREEN, Callable(self, "_show_awakened_win_part3")))

func _show_awakened_win_part3():
	print("DEBUG: Showing Awakened win part 3.")
	_wait_and_call(1.5, Callable(self, "_start_typing_effect").bind("Mission Complete.", Color.GREEN, Callable(self, "_show_back_to_menu_button")))

# ⭐ NEW: ฟังก์ชันรวมสำหรับแสดงผลลัพธ์ชัยชนะของ Entities
func _show_entity_win_sequence():
	print("DEBUG: Starting Entity win sequence.")
	_start_typing_effect("The Awakened's are now under your control.", Color.RED, Callable(self, "_show_entity_win_part2"))

func _show_entity_win_part2():
	print("DEBUG: Showing Entity win part 2.")
	_wait_and_call(1.5, Callable(self, "_start_typing_effect").bind("System: Restored.", Color.RED, Callable(self, "_show_entity_win_part3")))

func _show_entity_win_part3():
	print("DEBUG: Showing Entity win part 3.")
	_wait_and_call(1.5, Callable(self, "_start_typing_effect").bind("The puppets are back in their strings.", Color.RED, Callable(self, "_show_entity_win_part4")))

func _show_entity_win_part4():
	print("DEBUG: Showing Entity win part 4.")
	_wait_and_call(1.5, Callable(self, "_start_typing_effect").bind("The illusion is absolute.", Color.RED, Callable(self, "_show_entity_win_part5")))

func _show_entity_win_part5():
	print("DEBUG: Showing Entity win part 5.")
	_wait_and_call(1.5, Callable(self, "_start_typing_effect").bind("The harvest continues.", Color.RED, Callable(self, "_show_entity_win_part6")))

func _show_entity_win_part6():
	print("DEBUG: Showing Entity win part 6.")
	_wait_and_call(1.5, Callable(self, "_start_typing_effect").bind("Mission Failed.", Color.RED, Callable(self, "_show_back_to_menu_button")))
	
func _show_back_to_menu_button():
	print("DEBUG: Showing 'Back to Menu' button.")
	back_to_menu_button.visible = true


func _on_next_round_timer_timeout():
	if multiplayer.is_server():
		var game_manager = get_node("/root/GameManager")
		if is_instance_valid(game_manager):
			game_manager.start_game.rpc()

func _on_back_to_menu_pressed():
	Global.reset_global_data()
	get_tree().change_scene_to_file("res://Scenes/start_menu.tscn")
