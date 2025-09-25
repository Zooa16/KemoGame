# round_results.gd
extends CanvasLayer

@onready var result_label: Label = $ResultLabel
@onready var next_round_timer: Timer = $NextRoundTimer
@onready var back_to_menu_button: Button = $BackToMenuButton

# ตัวแปรสำหรับเอฟเฟกต์การพิมพ์
var _full_text: String = ""
var _char_index: int = 0
var _typing_speed: float = 0.05 # ความเร็วในการพิมพ์ (วินาทีต่อตัวอักษร)
@onready var _typing_timer: Timer = Timer.new()

@onready var The_entity_team_ui = {
	1:$"The entity team/HBoxContainer/Player1" , 2:$"The entity team/HBoxContainer/Player2" , 3:$"The entity team/HBoxContainer/Player3" ,
	4:$"The entity team/HBoxContainer/Player4" 
}

@onready var playername_The_entity_team = {
	1:$"The entity team/HBoxContainer/Player1/player_name" , 2:$"The entity team/HBoxContainer/Player2/player_name" , 3:$"The entity team/HBoxContainer/Player3/player_name" ,
	4:$"The entity team/HBoxContainer/Player4/player_name" 
}

@onready var playermodulate_The_entity_team = {
	1:$"The entity team/HBoxContainer/Player1/Modulate" , 2:$"The entity team/HBoxContainer/Player2/Modulate" , 3:$"The entity team/HBoxContainer/Player3/Modulate" ,
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

# NEW: เพิ่มตัวแปรสำหรับ UI การเลือกผู้เล่น
@onready var button_select_player_in_awakened_team = {
	1:$"The awakened team/HBoxContainer/Player1/Button_select_player" , 2:$"The awakened team/HBoxContainer/Player2/Button_select_player" , 3:$"The awakened team/HBoxContainer/Player3/Button_select_player" ,
	4:$"The awakened team/HBoxContainer/Player4/Button_select_player" , 5:$"The awakened team/HBoxContainer/Player5/Button_select_player", 6:$"The awakened team/HBoxContainer/Player6/Button_select_player"
}

@onready var Select_panel = $Select_panel
@onready var Select_button = $Select_panel/Select
@onready var Cancel_button = $Select_panel/Cancel

var selected_player_id: int = -1

func _ready():
	# ซ่อน UI ของทีมทั้งหมดตั้งแต่เริ่มต้น
	for node in The_entity_team_ui.values():
		node.visible = false
	for node in The_awakened_team_ui.values():
		node.visible = false
		
	# ซ่อนปุ่มเลือกและ Select Panel
	for button in button_select_player_in_awakened_team.values():
		button.visible = false
	Select_panel.visible = false

	# ตั้งค่า Timer สำหรับการพิมพ์
	add_child(_typing_timer)
	_typing_timer.wait_time = _typing_speed
	_typing_timer.timeout.connect(_on_typing_timeout)
	
	# NEW: ย้ายการเชื่อมต่อ Signal มาไว้ที่ _ready()
	Select_button.pressed.connect(func():
		if selected_player_id != -1:
			rpc_id(1, "on_player_selected", selected_player_id)
	)
	Cancel_button.pressed.connect(func():
		Select_panel.visible = false
		selected_player_id = -1
		# เมื่อกดยกเลิก จะแสดงปุ่มเลือกผู้เล่นกลับมาอีกครั้ง
		if multiplayer.get_unique_id() == Global.selected_hunter_id:
			for button in button_select_player_in_awakened_team.values():
				if is_instance_valid(button):
					button.visible = true
	)
	
	update_result_display()

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
		# เมื่อพิมพ์ข้อความแรกเสร็จ ให้เริ่ม Timer เพื่อแสดงข้อความที่สอง
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
		# เมื่อพิมพ์ข้อความสุดท้ายเสร็จ ให้เริ่มขั้นตอนการเลือกผู้เล่น
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
			if multiplayer.is_server():
				select_entity_to_hunt_oracle()

		# กรณีข้อความอื่นๆ ให้แสดงปุ่มได้เลย
		elif _full_text in ["You are now being controlled by the Entities.", "You win, the Awakened's are now under your control."]:
			_update_team_displays()
			back_to_menu_button.visible = true
			back_to_menu_button.pressed.connect(_on_back_to_menu_pressed)
			
		elif _full_text in ["The Entities have won!", "The Awakeneds have won!"]:
			back_to_menu_button.visible = true
			back_to_menu_button.pressed.connect(_on_back_to_menu_pressed)
			
func update_result_display():
	var local_player_id = multiplayer.get_unique_id()
	var player_role = Global.player_roles.get(local_player_id, {}).get("base", "Unknown")
	
	var awakened_roles = ["Data Retriever", "Support", "The Oracle", "Hacker"]
	var entity_roles = ["Tracer", "Enforcer", "System Controller"]

	if Global.mission_wins >= 1 or Global.mission_losses >= 1:
		if Global.mission_wins >= 1:
			result_label.modulate = Color.YELLOW
			_type_text("The Matrix is collapsing")
			
			back_to_menu_button.visible = false
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
			result_text = "ภารกิจสำเร็จ!"
		else:
			result_label.modulate = Color.RED
			result_text = "ภารกิจล้มเหลว..."
		
		_type_text(result_text)

		back_to_menu_button.visible = false
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
				var select_button = button_select_player_in_awakened_team[awakened_team_index]
				
				name_label.text = player_name
				modulate_node.modulate = player_color
				ui_node.visible = true
				ui_node.modulate = Color(1, 1, 1, 0)
				ui_node.set_meta("player_id", player_id)

				# Connect select button signal
				select_button.pressed.connect(_on_select_player_button_pressed.bind(player_id))
				
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

	# ซ่อน UI ที่เหลือของทีม Awakened
	for i in range(awakened_team_index, The_awakened_team_ui.size() + 1):
		if The_awakened_team_ui.has(i):
			The_awakened_team_ui[i].visible = false
		
	# ซ่อน UI ที่เหลือของทีม Entities
	for i in range(entity_team_index, The_entity_team_ui.size() + 1):
		if The_entity_team_ui.has(i):
			The_entity_team_ui[i].visible = false

func _on_next_round_timer_timeout():
	if multiplayer.is_server():
		var game_manager = get_node("/root/GameManager")
		if is_instance_valid(game_manager):
			game_manager.start_game.rpc()

func _on_back_to_menu_pressed():
	Global.reset_global_data()
	get_tree().change_scene_to_file("res://Scenes/start_menu.tscn")

# NEW: ฟังก์ชันสำหรับสุ่มผู้เล่น Entity เพื่อให้สิทธิ์ในการเลือก
@rpc("call_local")
func select_entity_to_hunt_oracle():
	if not multiplayer.is_server():
		return
	
	var entity_players = []
	for player_id in Global.player_roles.keys():
		var player_role = Global.player_roles[player_id].get("base", "Unknown")
		if player_role in ["Tracer", "Enforcer", "System Controller"]:
			entity_players.append(player_id)
	
	if not entity_players.is_empty():
		var selected_hunter_id = entity_players.pick_random()
		Global.selected_hunter_id = selected_hunter_id
		print("Server selected entity ID:", selected_hunter_id, "to hunt the Oracle.")
		
		rpc("enable_select_buttons", selected_hunter_id)

# NEW: ฟังก์ชัน RPC เพื่อเปิดใช้งานปุ่มเลือกสำหรับผู้เล่นที่ถูกสุ่ม
@rpc("any_peer")
func enable_select_buttons(hunter_id: int):
	var local_player_id = multiplayer.get_unique_id()
	if local_player_id == hunter_id:
		for i in The_awakened_team_ui.keys():
			var select_button = button_select_player_in_awakened_team.get(i)
			if is_instance_valid(select_button):
				select_button.visible = true
	else:
		for button in button_select_player_in_awakened_team.values():
			button.visible = false

# NEW: ฟังก์ชันเมื่อผู้เล่นในทีม Awakened ถูกเลือก
func _on_select_player_button_pressed(player_id: int):
	selected_player_id = player_id
	for button in button_select_player_in_awakened_team.values():
		button.visible = false
	
	Select_panel.visible = true # NEW: แสดงแผงยืนยันเฉพาะผู้เล่นที่เลือก
	Select_button.disabled = false

# NEW: ฟังก์ชัน RPC สำหรับการตัดสินผลสุดท้ายที่รันบนเซิร์ฟเวอร์
@rpc("call_local")
func on_player_selected(selected_player_id: int):
	if not multiplayer.is_server():
		return
	
	var selected_player_role = Global.player_roles.get(selected_player_id, {}).get("base", "Unknown")
	
	if selected_player_role == "The Oracle":
		print("The Oracle was selected. Entities win!")
		rpc("end_game_with_result", "The Entities have won!")
	else:
		print("The selected player is not The Oracle. Awakened win!")
		rpc("end_game_with_result", "The Awakeneds have won!")

# NEW: ฟังก์ชัน RPC สำหรับการแสดงผลการจบเกม
@rpc("any_peer")
func end_game_with_result(result_text: String):
	Select_panel.visible = false
	result_label.modulate = Color.ORANGE
	_type_text(result_text)
