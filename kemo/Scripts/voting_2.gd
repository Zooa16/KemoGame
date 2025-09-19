extends Control

var turn_duration := 150
var time_left := 0

# Player UI Nodes (ซึ่งตอนนี้เป็น Button)
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

# Dictionary for the Agree icon
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

#--------------------------------------------------------------------------------------------------------------#
# เพิ่ม dictionary สำหรับ UI ของทีมภารกิจ
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

#--------------------------------------------------------------------------------------------------------------#

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

var votes: Dictionary = {}
var has_voted := false
var is_leader: bool = false
var mission_size: int = 0
var selected_team_ids: Array = []
var active_players: Array = []

var player_id_to_ui_index: Dictionary = {}
var selected_player_id_to_add: int = 0

var countdown_duration := 10
var voting_in_progress := false
var fade_out_duration := 2.0


func _ready():
	turn_timer.timeout.connect(_on_Timer_timeout)
	
	# กำหนด is_leader จาก Global.leader_id
	is_leader = (Global.leader_id == multiplayer.get_unique_id())
	
	# เชื่อมต่อสัญญาณของปุ่มผู้เล่นทั้งหมดกับฟังก์ชันจัดการการกด
	for ui_node in player_ui_nodes.values():
		# เปลี่ยนการเชื่อมต่อเป็น gui_input เพื่อให้รองรับได้หลายประเภทโหนด
		ui_node.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed:
				if event.button_index == MOUSE_BUTTON_LEFT:
					var player_id = ui_node.get_meta("player_id")
					_on_player_ui_pressed(player_id)
		)

	
	# เชื่อมต่อปุ่ม Select และ Cancel
	Select_button.pressed.connect(_on_select_button_pressed)
	Cancel_button.pressed.connect(_on_cancel_button_pressed)
	
	initialize_player_ui()
	
	# ซ่อน Select panel ไว้ก่อน
	Select_panel.visible = false
	
	# ตั้งค่าและซิงโครไนซ์ขนาดภารกิจเมื่อเริ่มรอบ (เฉพาะบน Server)
	if multiplayer.is_server():
		start_voting_timer()
		set_mission_size_and_label()
	
	

func initialize_player_ui():
	# ซ่อน UI ของผู้เล่นทุกคนไว้ก่อน
	for i in range(1, Global.MAX_PLAYERS + 1):
		player_ui_nodes[i].visible = false
		Leader_icon[i].visible = false
		# ปิดการโต้ตอบของปุ่มหากไม่ใช่ Leader
		player_ui_nodes[i].disabled = not is_leader
		# ตั้งค่า meta data เพื่อใช้ในการอ้างอิง
		player_ui_nodes[i].set_meta("player_id", -1)

	var ui_index = 1
	for player_id in Global.player_names:
		# ถ้าผู้เล่นถูกคัดออก ให้ข้ามไป
		if player_id == Global.eliminated_player_id:
			continue
		
		# สร้าง Dictionary สำหรับการค้นหา UI อย่างรวดเร็ว
		player_id_to_ui_index[player_id] = ui_index
		
		# แสดง UI ของผู้เล่น
		player_ui_nodes[ui_index].visible = true
		player_ui_nodes[ui_index].set_meta("player_id", player_id)
		
		# อัปเดตชื่อผู้เล่น
		player_name_labels[ui_index].text = Global.player_names[player_id]
		
		# อัปเดตสีผู้เล่น
		if player_modulate_nodes.has(ui_index):
			player_modulate_nodes[ui_index].modulate = Global.player_colors[player_id]
		
		# แสดง Leader icon ถ้าผู้เล่นคนนั้นเป็น Leader
		if player_id == Global.leader_id:
			Leader_icon[ui_index].visible = true
			
		ui_index += 1


# ฟังก์ชันสำหรับเริ่มจับเวลาการโหวต (Server เท่านั้น)
func start_voting_timer():
	if not multiplayer.is_server():
		return
	
	time_left = turn_duration
	turn_timer.wait_time = 1.0
	turn_timer.one_shot = false
	turn_timer.start()
	
	rpc("update_timer_label", time_left)


# ฟังก์ชันที่ถูกเรียกทุกครั้งที่ Timer หมดเวลา (Server เท่านั้น)
func _on_Timer_timeout():
	if not multiplayer.is_server():
		return
	
	time_left -= 1
	rpc("update_timer_label", time_left)
	
	if time_left <= 0:
		turn_timer.stop()
		# โค้ดสำหรับเปลี่ยนฉากหรือสิ้นสุดการโหวตควรจะถูกเพิ่มที่นี่


# ฟังก์ชัน RPC สำหรับซิงค์เวลาไปยังผู้เล่นทุกคน
@rpc("any_peer", "call_local")
func update_timer_label(new_time: int):
	time_left = new_time
	var minutes = int(time_left / 60)
	var seconds = int(time_left % 60)
	timer_label.text = "%02d:%02d" % [minutes, seconds]
	
	if time_left <= 0:
		timer_label.text = "Time's up!"
		# ซ่อน UI ที่ไม่จำเป็นเมื่อหมดเวลา
		Agree_button.visible = false
		Disagree_button.visible = false
		Select_panel.visible = false


# ฟังก์ชันใหม่: สุ่มขนาดภารกิจด้วยน้ำหนัก
func set_mission_size_and_label():
	if not multiplayer.is_server():
		return
	
	# กำหนดลิสต์ของขนาดภารกิจที่มีการถ่วงน้ำหนักตามที่คุณเสนอ
	var weighted_sizes = [2, 2, 2, 3, 3, 4, 5]
	
	# สุ่มเลือกค่าจากในลิสต์
	var chosen_size = weighted_sizes[randi() % weighted_sizes.size()]
	
	# อัปเดตค่า global และส่งไปยัง client ผ่าน RPC
	Global.mission_size = chosen_size
	rpc("update_mission_label", chosen_size)


# ฟังก์ชัน RPC ใหม่: รับค่าขนาดภารกิจและอัปเดต UI
@rpc("any_peer", "call_local")
func update_mission_label(size: int):
	mission_size = size
	if size > 0:
		Mission_label.text = "Need %d people to complete the mission" % size
		_update_team_ui_visibility(size) # เพิ่มการเรียกใช้ฟังก์ชันนี้
	else:
		Mission_label.text = "Mission size not available."

# ฟังก์ชันใหม่: จัดการการแสดง/ซ่อน UI ของทีมภารกิจ
func _update_team_ui_visibility(size: int):
	# แสดง UI ตามจำนวนที่ต้องการ
	for i in range(1, size + 1):
		if The_Mission_team_ui.has(i):
			The_Mission_team_ui[i].visible = true
	# ซ่อน UI ที่เกินจำนวน
	for i in range(size + 1, The_Mission_team_ui.size() + 1):
		if The_Mission_team_ui.has(i):
			The_Mission_team_ui[i].visible = false


# ฟังก์ชันใหม่: จัดการการกดปุ่มผู้เล่น (เฉพาะ Leader)
func _on_player_ui_pressed(player_id: int):
	if not is_leader:
		return

	# ถ้าผู้เล่นถูกเลือกไปแล้ว ไม่ต้องทำอะไร
	if selected_team_ids.has(player_id):
		return
		
	# แสดง Select Panel
	Select_panel.visible = true
	# เก็บ ID ของผู้เล่นที่เลือกไว้ชั่วคราว
	selected_player_id_to_add = player_id


# ฟังก์ชันใหม่: จัดการการกดปุ่ม Select (เฉพาะ Leader)
func _on_select_button_pressed():
	if not is_leader:
		return
		
	# เพิ่มผู้เล่นเข้าทีม
	if not selected_team_ids.has(selected_player_id_to_add):
		selected_team_ids.append(selected_player_id_to_add)
	
	# ซ่อน Select Panel
	Select_panel.visible = false
	
	# เรียก RPC เพื่ออัปเดต UI ของทีมภารกิจบนเครื่องทุกคน
	rpc("update_mission_team_ui", selected_team_ids)
	
	# ถ้าเลือกครบจำนวนที่กำหนด
	if selected_team_ids.size() == mission_size:
		print("Team selection complete. Team size: %d" % mission_size)
		# โค้ดสำหรับดำเนินการขั้นตอนต่อไปของเกม (เช่น การโหวตยอมรับทีม) ควรจะถูกเพิ่มที่นี่
		# อาจจะปิดปุ่มโหวตของผู้เล่นทุกคนที่นี่ก็ได้

	
# ฟังก์ชันใหม่: จัดการการกดปุ่ม Cancel (เฉพาะ Leader)
func _on_cancel_button_pressed():
	if not is_leader:
		return
		
	# ซ่อน Select Panel
	Select_panel.visible = false
	# ล้าง ID ผู้เล่นที่เลือกไว้ชั่วคราว
	selected_player_id_to_add = 0


# ฟังก์ชัน RPC ใหม่: อัปเดต UI ทีมภารกิจบนเครื่องของผู้เล่นทุกคน
@rpc("any_peer", "call_local")
func update_mission_team_ui(team_ids: Array):
	# อัปเดต UI เฉพาะผู้เล่นที่อยู่ในทีม
	var team_ui_index = 1
	for player_id in team_ids:
		if team_ui_index > The_Mission_team_ui.size():
			break
		
		# อัปเดตชื่อ
		playername_The_Mission_team[team_ui_index].text = Global.player_names.get(player_id, "Unknown")
		
		# อัปเดตสี
		if playermodulate_The_Mission_team.has(team_ui_index):
			playermodulate_The_Mission_team[team_ui_index].modulate = Global.player_colors.get(player_id, Color.WHITE)
			
		team_ui_index += 1
