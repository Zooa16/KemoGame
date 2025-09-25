extends Control

var turn_duration := 60
var time_left := 0

@onready var Voting_topic = $status
@onready var Voting_results = $"Vote results"

@onready var turn_timer: Timer = $Timer
@onready var timer_label: Label = $Time

# Player UI Nodes
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

# Dictionary for the vote status icon
@onready var Selected = {
	1: $Player/player1/Selected, 2: $Player/player2/Selected, 3: $Player/player3/Selected,
	4: $Player/player4/Selected, 5: $Player/player5/Selected, 6: $Player/player6/Selected,
	7: $Player/player7/Selected, 8: $Player/player8/Selected, 9: $Player/player9/Selected,
	10: $Player/player10/Selected
}

@onready var Select_panel = $Select_panel
@onready var Select_button = $Select_panel/Select
@onready var Cancel_button = $Select_panel/Cancel
@onready var skip_button = $Skip_button

@onready var Eliminated_player_ui = $"Eliminated players"
@onready var Eliminated_player_Modulate = $"Eliminated players/Modulate"
@onready var Eliminated_player_name = $"Eliminated players/Modulate/Label"

# New: Add these three new nodes from your scene
@onready var Tie = $Tie
@onready var Skip_vote = $"Skip vote"
@onready var Number_of_votes = $"Vote results/Number of votes"

@onready var proceeding_timer: Timer = $ProceedingTimer

var votes: Dictionary = {}
var has_voted := false
var selected_player_id: int = 0
var eliminated_player_id: int = 0
var current_highlighted_node: Node = null

var player_id_to_ui_index: Dictionary = {}

var countdown_duration := 1
var voting_in_progress := false
var fade_out_duration := 4.0


func _ready():
	for ui in player_ui_nodes.values():
		ui.visible = false
	
	Eliminated_player_ui.visible = false
	# Hide the new UI elements at the start
	Tie.visible = false
	Skip_vote.visible = false
	Number_of_votes.visible = false
	
	hide_all_selected()
	
	Select_button.pressed.connect(_on_select_button_pressed)
	Cancel_button.pressed.connect(_on_cancel_button_pressed)
	skip_button.pressed.connect(_on_skip_button_pressed)
	
	Select_panel.visible = false
	setup_player_ui()

	if multiplayer.is_server():
		start_voting_timer()


func hide_all_selected():
	for icon in Selected.values():
		icon.visible = false
	
func highlight_selection(player_id: int):
	if current_highlighted_node:
		current_highlighted_node.modulate = Color.WHITE
		
	var ui_index = player_id_to_ui_index.get(player_id)
	if ui_index != null:
		var name_label = player_name_labels.get(ui_index)
		if name_label:
			name_label.modulate = Color.YELLOW
			current_highlighted_node = name_label

func _on_player_ui_pressed(player_id: int):
	if not has_voted and voting_in_progress:
		selected_player_id = player_id
		highlight_selection(player_id)
		Select_panel.visible = true

func _on_select_button_pressed():
	if selected_player_id != 0:
		var my_id = multiplayer.get_unique_id()
		print("PLAYER(", my_id, "): Voting for player ", selected_player_id)
		
		if multiplayer.is_server():
			receive_vote(my_id, selected_player_id)
		else:
			rpc_id(1, "receive_vote", my_id, selected_player_id)

		Select_panel.visible = false
		has_voted = true
		Voting_topic.text = "You have voted!"

func _on_cancel_button_pressed():
	Select_panel.visible = false
	if current_highlighted_node:
		current_highlighted_node.modulate = Color.WHITE
	selected_player_id = 0

func _on_skip_button_pressed():
	if not has_voted:
		var my_id = multiplayer.get_unique_id()
		print("PLAYER(", my_id, "): Skipping vote")
		
		if multiplayer.is_server():
			receive_vote(my_id, 0)
		else:
			rpc_id(1, "receive_vote", my_id, 0)

		has_voted = true
		Voting_topic.text = "You have skipped your vote."
		skip_button.disabled = true
		Select_panel.visible = false
		if current_highlighted_node:
			current_highlighted_node.modulate = Color.WHITE
		selected_player_id = 0

func setup_player_ui():
	var active_players = Global.player_names.keys()
	
	for i in range(active_players.size()):
		var peer_id = active_players[i]
		var ui_index = i + 1
		
		player_id_to_ui_index[peer_id] = ui_index
		
		var ui_node = player_ui_nodes.get(ui_index)
		var name_label = player_name_labels.get(ui_index)
		var modulate_node = player_modulate_nodes.get(ui_index)
		
		if ui_node and name_label and modulate_node:
			ui_node.visible = true
			name_label.text = Global.player_names[peer_id]
			modulate_node.modulate = Global.player_colors[peer_id]
			
			ui_node.gui_input.connect(func(event):
				if event is InputEventMouseButton and event.pressed:
					if event.button_index == MOUSE_BUTTON_LEFT:
						_on_player_ui_pressed(peer_id)
			)

# ----------------------------------------------------
# Multiplayer RPC functions (Server Logic)
# ----------------------------------------------------
func send_vote(target_id: int):
	var peer_id = multiplayer.get_unique_id()
	print("PLAYER(", peer_id, "): Sending vote for player ", target_id)

	if multiplayer.is_server():
		receive_vote(peer_id, target_id)
	else:
		rpc_id(1, "receive_vote", peer_id, target_id)

@rpc("any_peer")
func receive_vote(voter_id: int, voted_id: int):
	show_selected_rpc(voter_id)
	if not multiplayer.is_server():
		return
		
	if not votes.has(voter_id):
		votes[voter_id] = voted_id
		print("SERVER: Received vote from player ", voter_id, " for player ", voted_id)
		rpc("show_selected_rpc", voter_id)

	print("SERVER: Current votes dictionary: ", votes)
	
	if votes.size() >= Global.player_names.size() and voting_in_progress:
		print("SERVER: All players have voted. Calculating results...")
		turn_timer.stop()
		calculate_and_show_results()

func start_voting_timer():
	if not multiplayer.is_server():
		return
		
	time_left = countdown_duration + turn_duration
	turn_timer.wait_time = 1.0
	turn_timer.one_shot = false
	turn_timer.timeout.connect(_on_timer_timeout)
	turn_timer.start()
	
	rpc("update_timer_label", time_left)
	
func _on_timer_timeout():
	if multiplayer.is_server():
		time_left -= 1
		if time_left < 0:
			turn_timer.stop()
			calculate_and_show_results()
		else:
			rpc("update_timer_label", time_left)

func calculate_and_show_results():
	var vote_counts: Dictionary = {}
	var skip_count = 0
	
	for voter_id in votes.keys():
		var voted_id = votes[voter_id]
		if voted_id == 0:
			skip_count += 1
			continue
			
		if vote_counts.has(voted_id):
			vote_counts[voted_id] += 1
		else:
			vote_counts[voted_id] = 1

	var max_votes = 0
	var winning_voted_id: int = 0
	var tied_players: Array = []

	for voted_id in vote_counts.keys():
		var current_votes = vote_counts[voted_id]
		if current_votes > max_votes:
			max_votes = current_votes
			winning_voted_id = voted_id
			tied_players.clear()
			tied_players.append(voted_id)
		elif current_votes == max_votes:
			tied_players.append(voted_id)
	
	var result_text = ""
	var result_type = "eliminated"
	
	# NEW: ตรวจสอบและกำหนดค่า Global.eliminated_player_id ก่อนส่ง
	if tied_players.size() > 1:
		result_text = "Tied vote"
		result_type = "tie"
		Global.eliminated_player_id = -1
	elif max_votes == 0 or max_votes <= skip_count:
		result_text = "No one was voted out."
		result_type = "skip"
		Global.eliminated_player_id = -1
	else:
		var eliminated_player_name = Global.player_names.get(winning_voted_id, "Unknown Player")
		result_text = "\"%s\" was eliminated from the mission." % eliminated_player_name
		result_type = "eliminated"
		Global.eliminated_player_id = winning_voted_id
		
	# ส่งข้อมูลไปยังไคลเอนต์ผ่าน RPC
	rpc("show_final_result", result_text, Global.eliminated_player_id, result_type, max_votes, skip_count)
	
	# ลบโค้ดส่วนนี้ออก เพราะเราจะไปเปลี่ยนฉากในฟังก์ชันใหม่ที่เหมาะสมกว่า
	# if multiplayer.is_server():
	#     rpc("fade_out_and_change_scene", "res://Scenes/Voting2.tscn")
	
	# 🌟 NEW: เรียกฟังก์ชันสำหรับจัดการการเปลี่ยนฉาก
	start_proceeding_timer()
	
	return result_type

# ----------------------------------------------------
# Multiplayer RPC functions (Client & Server Logic)
# ----------------------------------------------------
@rpc("any_peer", "call_local")
func show_selected_rpc(voter_id: int):
	var ui_index = player_id_to_ui_index.get(voter_id)
	if ui_index != null:
		var selected_icon = Selected.get(ui_index)
		if selected_icon:
			selected_icon.visible = true

@rpc("any_peer", "call_local")
func update_timer_label(new_time: int):
	time_left = new_time
	if time_left > turn_duration:
		timer_label.text = "Voting Begins in " + str(time_left - turn_duration)
		timer_label.modulate = Color.WHITE
		voting_in_progress = false
		skip_button.disabled = true
	else:
		if not voting_in_progress:
			Voting_topic.text = "Please cast your vote."
			voting_in_progress = true
			skip_button.disabled = false
			
		timer_label.text = "Voting Ends in " + str(time_left)
		
		if time_left <= 10:
			timer_label.modulate = Color.RED
		else:
			timer_label.modulate = Color.WHITE

# Updated function to handle all vote result scenarios
@rpc("any_peer", "call_local")
func show_final_result(result_text: String, eliminated_id: int, result_type: String, max_votes: int, skip_count: int):
	# 🌟 NEW: อัปเดต Global.eliminated_player_id บนไคลเอนต์
	Global.eliminated_player_id = eliminated_id
	
	Voting_results.text = result_text
	Voting_topic.text = ""
	timer_label.text = ""
	
	if current_highlighted_node:
		current_highlighted_node.modulate = Color.WHITE
		
	hide_all_selected()
	
	skip_button.visible = false
	for ui in player_ui_nodes.values():
		ui.visible = false
	
	Eliminated_player_ui.visible = false
	Tie.visible = false
	Skip_vote.visible = false
	Number_of_votes.visible = true # Number_of_votes will always be shown
	
	if result_type == "eliminated":
		if eliminated_id != -1: # เช็คว่ามีคนถูกคัดออกจริง ๆ
			Eliminated_player_ui.visible = true
			var name_to_display = Global.player_names.get(eliminated_id, "Unknown Player")
			Eliminated_player_name.text = name_to_display
			Eliminated_player_Modulate.modulate = Global.player_colors.get(eliminated_id, Color.WHITE)
		Number_of_votes.text = "Votes: " + str(max_votes)
	elif result_type == "tie":
		Tie.visible = true
		# โค้ดส่วนนี้จะทำงานบนไคลเอนต์ แต่ไม่มีข้อมูล votes dictionary
		# ดังนั้นจะไม่มีการแสดงผลที่ถูกต้อง
		var tied_players = []
		# for player_id in Global.player_names.keys():
		#     if votes.get(player_id) == max_votes:
		#         tied_players.append(Global.player_names.get(player_id))
		
		# The Number_of_votes label will show something like "3:3"
		Number_of_votes.text = str(max_votes) + ":" + str(max_votes)
	elif result_type == "skip":
		Skip_vote.visible = true
		Number_of_votes.text = "Skip Votes: " + str(skip_count)

@rpc("any_peer", "call_local")
func update_proceeding_label(new_time: int):
	timer_label.text = "Proceeding in: " + str(new_time)
	
@rpc("any_peer", "call_local")
func fade_out_and_change_scene(scene_path: String):
	timer_label.text = "Proceeding..."
	var tween = get_tree().create_tween()
	if tween:
		tween.tween_property(self, "modulate", Color(0, 0, 0, 1), fade_out_duration)
		await tween.finished
		get_tree().change_scene_to_file(scene_path)

# ----------------------------------------------------
# New Functions for Proceeding Timer (Server Only)
# ----------------------------------------------------
func start_proceeding_timer():
	if not multiplayer.is_server():
		return
		
	var time_to_proceed = 5
	
	proceeding_timer.wait_time = 1.0
	proceeding_timer.one_shot = false
	
	if not proceeding_timer.timeout.is_connected(self._on_proceeding_timer_timeout):
		proceeding_timer.timeout.connect(self._on_proceeding_timer_timeout)
		
	proceeding_timer.start()
	
	rpc("update_proceeding_label", time_to_proceed)

func _on_proceeding_timer_timeout():
	if not multiplayer.is_server():
		return
		
	var current_time = 0
	var time_text = timer_label.text.replace("Proceeding in: ", "")
	if time_text.is_valid_int():
		current_time = int(time_text)
		
	var new_time = current_time - 1
	
	if new_time > 0:
		rpc("update_proceeding_label", new_time)
	else:
		proceeding_timer.stop()
		
		var next_scene_path = "res://Scenes/Voting2.tscn"
		rpc("fade_out_and_change_scene", next_scene_path)
